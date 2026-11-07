#!/usr/bin/env python3
"""Inventory the quest-to-world data ecosystem in the exact Conquer Mobile APK.

This is a discovery/audit tool, not a runtime importer. It inventories quest,
NPC, map, item, reward and dialogue candidates, probes only documented TQ
cipher seeds, and preserves source bytes and hashes. Candidate decodes are
never promoted to game data without mobile-build/schema validation.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import tempfile
import zipfile
from collections import Counter
from pathlib import Path

VERSION = "ConquerOnline-1.1.2.3"
ROOT = "assets/ConquerRes/"
SEEDS = (9527, 1234)
TOKENS = (
    "quest", "task", "mission", "npc", "map", "item", "reward",
    "dialog", "talk", "clienttask", "realm_task", "juqing",
)
ID_FIELDS = (
    "TaskID", "NpcID", "ReachNpcID", "MapID", "ReachMapID",
    "ItemID", "ItemType", "RewardID", "Goal", "GoalPos",
    "IntentionCount", "itemcd",
)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def digest_file(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            hasher.update(block)
    return hasher.hexdigest()


def tq_key(seed: int) -> bytes:
    state = seed & 0xFFFFFFFF
    result = bytearray()
    for _ in range(128):
        state = (state * 0x343FD + 0x269EC3) & 0xFFFFFFFF
        result.append(((state >> 16) & 0x7FFF) & 0xFF)
    return bytes(result)


def decrypt_tq(data: bytes, seed: int) -> bytes:
    key = tq_key(seed)
    out = bytearray(len(data))
    for i, byte in enumerate(data):
        value = byte ^ key[i & 127]
        shift = i & 7
        out[i] = value if shift == 0 else ((value >> shift) | (value << (8 - shift))) & 0xFF
    return bytes(out)


def text_probe(data: bytes) -> dict:
    sample = data[:min(len(data), 512 * 1024)]
    if not sample:
        return {"ascii_ratio": 0.0, "lua_markers": [], "text_candidate": False}
    ascii_ratio = sum(b in (9, 10, 13) or 32 <= b <= 126 for b in sample) / len(sample)
    ascii_text = sample.decode("ascii", errors="ignore")
    markers = [marker for marker in (
        "local MainTask", "local ret", "ret.data", "ret.iteminfo",
        '["TaskID"]', '["NpcID"]', '["MapID"]', "function ",
    ) if marker in ascii_text]
    # High bytes are deliberately not counted as printable: this avoids
    # classifying arbitrary binary blobs as text just because bytes >= C0 exist.
    return {
        "ascii_ratio": round(ascii_ratio, 4),
        "lua_markers": markers,
        "text_candidate": ascii_ratio >= 0.72 and bool(markers),
    }


def category(path: str) -> list[str]:
    low = path.lower()
    found = []
    for token in TOKENS:
        if token in low:
            found.append(token)
    return found


def parse_ascii_ids(data: bytes) -> dict:
    text = data.decode("ascii", errors="ignore")
    fields = {}
    for field in ID_FIELDS:
        values = re.findall(r'\["' + re.escape(field) + r'\"]\s*=\s*(-?\d+)', text)
        if values:
            fields[field] = [int(value) for value in values]
    task_ids = fields.get("TaskID", [])
    return {
        "field_values": fields,
        "task_id_count": len(task_ids),
        "duplicate_task_ids": sorted(value for value, count in Counter(task_ids).items() if count > 1),
    }


def is_interesting(path: str) -> bool:
    low = path.lower()
    if not low.startswith(ROOT.lower()):
        return False
    base = low.rsplit("/", 1)[-1]
    if any(token in low for token in TOKENS):
        return True
    # Known Lua quest data conventions, even when the parent folder is generic.
    return bool(re.fullmatch(r"(clienttask\d+|juqing\d+)\.dat", base))


def inspect_apk(apk_bytes_path: Path, apk_member: str, out_dir: Path) -> list[dict]:
    rows = []
    with zipfile.ZipFile(apk_bytes_path) as apk:
        for info in apk.infolist():
            if info.is_dir():
                continue
            raw = apk.read(info)
            if not is_interesting(info.filename, raw):
                continue
            rel = info.filename[len(ROOT):] if info.filename.startswith(ROOT) else info.filename
            low_path = info.filename.lower()
            discovery_reason = (
                "PATH_KEYWORD" if any(token in low_path for token in TOKENS)
                else "CONTENT_SIGNATURE_IN_MOBILE_SCRIPT_CONFIG_DIRECTORY"
            )
            row = {
                "discovery_reason": discovery_reason,
                "apk_member": apk_member + "!" + info.filename,
                "relative_path": rel,
                "categories": category(rel),
                "extension": Path(rel).suffix.lower(),
                "size_bytes": len(raw),
                "source_sha256": digest(raw),
                "raw_probe": text_probe(raw),
                "decode_candidates": [],
            }
            if row["extension"] in (".dat", ".lua", ".txt", ".ini"):
                # Plain Lua/text is retained as a source candidate too.
                if text_probe(raw)["text_candidate"]:
                    row["raw_structure"] = parse_ascii_ids(raw)
                if row["extension"] == ".dat":
                    for seed in SEEDS:
                        decoded = decrypt_tq(raw, seed)
                        probe = text_probe(decoded)
                        candidate = {
                            "cipher": "TQ_FILE_CIPHER_RESEARCH_CANDIDATE",
                            "seed": seed,
                            "probe": probe,
                            "structure": parse_ascii_ids(decoded) if probe["text_candidate"] else {},
                            "accepted_for_runtime": False,
                        }
                        if probe["text_candidate"]:
                            locale = "ar" if "ini_ar" in rel.lower() else (
                                "sp" if "ini_sp" in rel.lower() else "default"
                            )
                            safe_name = re.sub(r"[^A-Za-z0-9_.-]+", "_", rel)
                            target = out_dir / "decoded_candidates" / locale / f"{safe_name}.seed-{seed}.candidate"
                            target.parent.mkdir(parents=True, exist_ok=True)
                            target.write_bytes(decoded)
                            candidate["candidate_file"] = str(target)
                            candidate["candidate_sha256"] = digest(decoded)
                        row["decode_candidates"].append(candidate)
            rows.append(row)
    return rows


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, default=Path("build/quest-ecosystem"))
    args = parser.parse_args()
    if not args.archive.is_file():
        raise SystemExit(f"Source archive not found: {args.archive}")

    records = []
    apk_members = []
    with zipfile.ZipFile(args.archive) as outer, tempfile.TemporaryDirectory(prefix="mobile-quest-apk-") as temp:
        for member in outer.namelist():
            if VERSION not in member or not member.lower().endswith(".apk"):
                continue
            apk_path = Path(temp) / f"apk-{len(apk_members)}.apk"
            with outer.open(member) as source, apk_path.open("wb") as target:
                while True:
                    block = source.read(1024 * 1024)
                    if not block:
                        break
                    target.write(block)
            apk_members.append(member)
            records.extend(inspect_apk(apk_path, member, args.output_dir))

    by_category = Counter(token for row in records for token in row["categories"])
    candidate_count = sum(
        1 for row in records for candidate in row["decode_candidates"]
        if candidate["probe"]["text_candidate"]
    )
    task_ids = sorted({
        value
        for row in records
        for candidate in row["decode_candidates"]
        for value in candidate.get("structure", {}).get("field_values", {}).get("TaskID", [])
    })
    report = {
        "schema_version": "1.0.0",
        "source_version": VERSION,
        "archive_name": args.archive.name,
        "archive_size_bytes": args.archive.stat().st_size,
        "archive_sha256": digest_file(args.archive),
        "apk_members": apk_members,
        "files_found": len(records),
        "category_file_counts": dict(sorted(by_category.items())),
        "plausible_cipher_decode_candidates": candidate_count,
        "unique_task_ids_in_candidates": task_ids,
        "records": records,
        "acceptance_policy": (
            "Discovery only. Cipher probes are based on documented desktop TQ cipher behavior. "
            "No mobile file is accepted until the exact APK reader, schema, locale and cross-file "
            "NPC/map/item/reward references are independently validated."
        ),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({
        "apk_count": len(apk_members),
        "files_found": len(records),
        "category_file_counts": dict(sorted(by_category.items())),
        "plausible_cipher_decode_candidates": candidate_count,
        "unique_task_ids_in_candidates": len(task_ids),
        "report": str(args.output),
    }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
