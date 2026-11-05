#!/usr/bin/env python3
"""Probe original Conquer gameplay data files without guessing undocumented schemas."""
from __future__ import annotations
import hashlib, json, re, zlib
from pathlib import Path

ROOT = Path("resource_stage")
TARGETS = {
    "itemcfg.dat": "item_definitions",
    "copydrop.dat": "monster_drop_rules",
    "questinfo.dat": "quest_definitions",
    "taskitem_info.dat": "quest_item_requirements",
    "item_refine_effect.dat": "refinement_visual_effects",
    "item_refine_effect_ex.dat": "extended_refinement_visual_effects",
    "monster.dat": "monster_definitions",
    "monstertype.ini": "monster_type_definitions",
    "gemtip.ini": "gem_definitions",
}
OUT = Path("reports/gameplay-data-source-probe.json")

def printable_runs(data: bytes, pattern: bytes, min_len: int = 4, limit: int = 80):
    found = []
    for match in re.finditer(pattern, data):
        raw = match.group(0)
        if len(raw) >= min_len:
            try:
                value = raw.decode("utf-8").strip()
            except UnicodeDecodeError:
                continue
            if value and value not in found:
                found.append(value)
                if len(found) >= limit:
                    break
    return found

def tq_decrypt_candidate(data: bytes, seed: int) -> bytes:
    """Research-only candidate decoder; seed is not assumed valid for the mobile APK."""
    state = seed & 0xFFFFFFFF
    key = []
    for _ in range(128):
        state = (state * 0x343FD + 0x269EC3) & 0xFFFFFFFF
        key.append(((state >> 16) & 0x7FFF) & 0xFF)
    out = bytearray(len(data))
    for i, value in enumerate(data):
        x = value ^ key[i % 128]
        shift = i % 8
        out[i] = x if shift == 0 else ((x >> shift) | (x << (8 - shift))) & 0xFF
    return bytes(out)


def candidate_text_signals(data: bytes) -> dict:
    if not data:
        return {"printable_ratio": 0.0, "at_at_lines": 0, "ini_sections": 0, "key_value_lines": 0, "looks_like_known_text": False}
    sample = data[:min(len(data), 2 * 1024 * 1024)]
    printable = sum(1 for b in sample if b in (9, 10, 13) or 32 <= b <= 126 or b >= 0xC0)
    ratio = printable / len(sample)
    text = sample.decode("utf-8", errors="ignore")
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    at_at = sum(1 for line in lines if "@@" in line and line.split("@@", 1)[0].isdigit())
    sections = sum(1 for line in lines if line.startswith("[") and "]" in line)
    kv = sum(1 for line in lines if "=" in line and not line.startswith(("#", ";")))
    plausible = ratio >= 0.90 and (at_at >= 3 or (sections >= 2 and kv >= 5))
    return {"printable_ratio": round(ratio, 4), "at_at_lines": at_at, "ini_sections": sections, "key_value_lines": kv, "looks_like_known_text": plausible}


def inspect_tq_cipher_candidates(path: Path, role: str, data: bytes) -> list:
    # Seeds 9527 and 1234 are documented for specific older desktop-client files only.
    # Trying them here is a falsifiable diagnostic, not a claim about the mobile APK.
    results = []
    for seed in (9527, 1234):
        decoded = tq_decrypt_candidate(data, seed)
        signals = candidate_text_signals(decoded)
        entry = {"cipher_candidate": "TQ_FILE_CIPHER_RESEARCH_ONLY", "seed": seed, **signals, "accepted_as_mobile_format": False}
        if signals["looks_like_known_text"]:
            out = Path("build/gameplay_decode_candidates") / f"{role}_{path.stem}_seed_{seed}.txt"
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_bytes(decoded)
            entry["candidate_output"] = str(out)
            entry["review_status"] = "PLAUSIBLE_TEXT_NEEDS_MOBILE_VERSION_VALIDATION"
        else:
            entry["review_status"] = "NO_KNOWN_TEXT_SIGNATURE"
        results.append(entry)
    return results


def inspect(path: Path, role: str) -> dict:
    data = path.read_bytes()
    head = data[:32]
    decoded = None
    compression = []
    if head.startswith((b"\x1f\x8b",)):
        compression.append("gzip")
    if head.startswith(b"PK\x03\x04"):
        compression.append("zip")
    if len(data) > 6 and data[4:6] in (b"x\x01", b"x\x9c", b"x\xda"):
        compression.append("possible-zlib-after-4-byte-header")
        try:
            decoded = zlib.decompress(data[4:])
        except zlib.error:
            pass
    ascii_strings = printable_runs(data, rb"[ -~]{4,}", limit=60)
    utf16_strings = []
    try:
        text = data.decode("utf-16le", errors="ignore")
        utf16_strings = list(dict.fromkeys(x.strip() for x in re.findall(r"[\u0020-\u007e\u0600-\u06ff]{4,}", text) if x.strip()))[:60]
    except Exception:
        pass
    return {
        "role": role,
        "candidate_tq_cipher_diagnostics": inspect_tq_cipher_candidates(path, role, data),
        "path": str(path),
        "size_bytes": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
        "header_hex": head.hex(" "),
        "compression_hints": compression,
        "zlib_payload_decoded_bytes": len(decoded) if decoded is not None else 0,
        "ascii_string_samples": ascii_strings,
        "utf16_string_samples": utf16_strings,
        "schema_status": "PROBE_ONLY_NOT_PARSED",
    }

def main():
    records = []
    missing = []
    for filename, role in TARGETS.items():
        candidates = list(ROOT.rglob(filename)) if ROOT.exists() else []
        if not candidates:
            missing.append(filename)
            continue
        # Prefer the primary English APK resource tree; keep all language/source variants in report.
        for path in sorted(candidates, key=lambda p: ("/ini_ar/" in p.as_posix(), "/ini_sp/" in p.as_posix(), len(p.as_posix()))):
            try:
                records.append(inspect(path, role))
            except OSError as exc:
                records.append({"role": role, "path": str(path), "error": str(exc)})
    OUT.parent.mkdir(parents=True, exist_ok=True)
    report = {
        "report_version": "1.0.0",
        "purpose": "Identify source encodings and field candidates before implementing parsers; no item/drop/quest values are inferred.",
        "source_root": str(ROOT),
        "files_found": len(records),
        "missing_filenames": missing,
        "records": records,
    }
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"GAMEPLAY DATA PROBE: {len(records)} file variants inspected; {len(missing)} filenames missing")
    print("Schema status is PROBE_ONLY_NOT_PARSED; do not use probe strings as live game data.")

if __name__ == "__main__":
    main()
