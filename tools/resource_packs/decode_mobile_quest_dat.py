#!/usr/bin/env python3
"""Decode original Conquer Mobile quest DAT candidates with the documented TQ file cipher.

This tool is intentionally narrow: it only processes questinfo.dat and
 taskitem_info.dat. It never edits source files and never promotes output into
runtime data. The seed is configurable because desktop-client documentation
must not be treated as proof of a mobile build's exact cipher configuration.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def make_key(seed: int, size: int = 128) -> bytes:
    state = seed & 0xFFFFFFFF
    key = bytearray()
    for _ in range(size):
        state = (state * 0x343FD + 0x269EC3) & 0xFFFFFFFF
        key.append(((state >> 16) & 0x7FFF) & 0xFF)
    return bytes(key)


def ror8(value: int, shift: int) -> int:
    shift &= 7
    if shift == 0:
        return value & 0xFF
    return ((value >> shift) | (value << (8 - shift))) & 0xFF


def rol8(value: int, shift: int) -> int:
    shift &= 7
    if shift == 0:
        return value & 0xFF
    return ((value << shift) | (value >> (8 - shift))) & 0xFF


def decrypt_tq(data: bytes, seed: int = 9527) -> bytes:
    key = make_key(seed)
    return bytes(ror8(byte ^ key[i % 128], i % 8) for i, byte in enumerate(data))


def encrypt_tq(data: bytes, seed: int = 9527) -> bytes:
    """Inverse used only for deterministic round-trip self-tests."""
    key = make_key(seed)
    return bytes(rol8(byte, i % 8) ^ key[i % 128] for i, byte in enumerate(data))


def locale_for(path: Path) -> str:
    parts = {part.lower() for part in path.parts}
    if "ini_ar" in parts:
        return "ar"
    if "ini_sp" in parts:
        return "sp"
    return "default"


def inspect_lua(data: bytes, role: str) -> dict:
    # Keep the source bytes intact. Encoding is a presentation concern and can
    # differ by locale; cp1256 is only selected for the Arabic locale.
    text_ascii = data.decode("latin-1")
    if role == "quest_definitions":
        signatures = {
            "local_main_task": "local MainTask" in text_ascii,
            "task_id_fields": bool(re.search(r'\["TaskID"\]\s*=\s*\d+', text_ascii)),
            "goal_fields": bool(re.search(r'\["Goal"\]\s*=\s*\d+', text_ascii)),
        }
        task_ids = re.findall(r'\["TaskID"\]\s*=\s*(\d+)', text_ascii)
        return {
            "format": "lua_table_candidate",
            "structural_signatures": signatures,
            "structure_valid": all(signatures.values()),
            "task_id_count": len(task_ids),
            "task_ids": [int(value) for value in task_ids],
            "objective_count": len(re.findall(r'\["Goal"\]\s*=', text_ascii)),
        }

    signatures = {
        "local_ret": text_ascii.lstrip().startswith("local ret"),
        "ret_data": "ret.data" in text_ascii,
        "ret_iteminfo": "ret.iteminfo" in text_ascii,
    }
    item_ids = re.findall(r"itemtype\d+\s*=\s*(\d+)", text_ascii)
    return {
        "format": "lua_table_candidate",
        "structural_signatures": signatures,
        "structure_valid": all(signatures.values()),
        "item_type_count": len(item_ids),
        "item_type_ids": [int(value) for value in item_ids],
        "item_cd_count": len(re.findall(r"itemcd\s*=", text_ascii)),
    }


def self_test() -> None:
    sample = b'local MainTask = { [0] = { ["TaskID"] = 10017, ["Goal"] = 30 } }'
    for seed in (9527, 1234):
        assert decrypt_tq(encrypt_tq(sample, seed), seed) == sample
    print("TQ cipher round-trip self-test: PASS (seeds 9527, 1234)")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-root", type=Path, default=Path("resource_stage"))
    parser.add_argument("--output-root", type=Path, default=Path("build/mobile_quest_decode"))
    parser.add_argument("--seed", type=lambda value: int(value, 0), default=9527)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        self_test()
        return 0

    targets = {
        "questinfo.dat": "quest_definitions",
        "taskitem_info.dat": "quest_item_requirements",
    }
    records = []
    for filename, role in targets.items():
        candidates = sorted(args.input_root.rglob(filename)) if args.input_root.exists() else []
        for source in candidates:
            original = source.read_bytes()
            decoded = decrypt_tq(original, args.seed)
            locale = locale_for(source)
            destination = args.output_root / role / locale / (source.stem + ".lua")
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(decoded)
            structural = inspect_lua(decoded, role)
            presentation_encoding = "cp1256" if locale == "ar" else "utf-8"
            try:
                decoded.decode(presentation_encoding)
                encoding_check = "decodable"
            except UnicodeDecodeError:
                encoding_check = "contains_bytes_outside_selected_encoding"

            records.append({
                "role": role,
                "source": str(source),
                "source_size": len(original),
                "source_sha256": sha256(original),
                "seed": args.seed,
                "cipher": "TQ_FILE_CIPHER_CANDIDATE",
                "decoded": str(destination),
                "decoded_size": len(decoded),
                "decoded_sha256": sha256(decoded),
                "presentation_encoding_candidate": presentation_encoding,
                "encoding_check": encoding_check,
                **structural,
                "acceptance": (
                    "STRUCTURE_VALIDATED_CANDIDATE_NOT_YET_MOBILE_BINARY_PROVEN"
                    if structural["structure_valid"]
                    else "REJECTED_NO_EXPECTED_LUA_STRUCTURE"
                ),
            })

    report = {
        "report_version": "1.0.0",
        "purpose": "Reproducible, non-destructive quest DAT decoding and structural validation.",
        "input_root": str(args.input_root),
        "output_root": str(args.output_root),
        "seed": args.seed,
        "files_found": len(records),
        "records": records,
        "policy": (
            "Never import a candidate into runtime data solely because it decrypts. "
            "Confirm the mobile build, locale, schema and linked NPC/map/item IDs first."
        ),
    }
    args.output_root.mkdir(parents=True, exist_ok=True)
    report_path = args.output_root / "quest-decode-report.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Quest DAT candidates inspected: {len(records)}")
    print(f"Report: {report_path}")
    for item in records:
        print(item["role"], item["source"], "=>", item["acceptance"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
