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
