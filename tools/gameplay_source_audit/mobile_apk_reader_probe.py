#!/usr/bin/env python3
"""Probe the exact Mobile APK's DEX/native binaries for resource-reader evidence.

This is static triage only. String hits identify code locations to inspect; they
do not prove the runtime cipher or schema. Source data remains untrusted until
the exact reader behavior is confirmed.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
import zipfile
from pathlib import Path

VERSION = "ConquerOnline-1.1.2.3"
TOKENS = (
    "questinfo.dat", "taskitem_info.dat", "clienttask", "juqing",
    "maintask", "taskid", "npcid", "mapid", "taskreward",
    "decrypt", "encrypt", "cipher", "rsa", "gzip", "inflater",
    "zipinputstream", "343fd", "269ec3", "TaskAssemblyGfit_Find", "ClientTaskTemplate_QuestinfoFunc", "PlotEditorOnTaskPanelClick", "GuildPreheating_QuestinfoFunc", "NpcDialogueText_AR", "Dialog_Dialogue", "LuaSceneScript", "luascriptmgr", "npcdialogueinfo.dat", "npcdialoguetext_ar.dat", "questinfo.ini", "slotnpc.ini", "mapdestination.ini",
)
ASCII_RUN = re.compile(rb"[\x20-\x7e]{5,}")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def read_uleb128(data: bytes, offset: int) -> tuple[int, int]:
    value = 0
    shift = 0
    while True:
        if offset >= len(data) or shift > 28:
            raise ValueError("invalid or truncated ULEB128")
        byte = data[offset]
        offset += 1
        value |= (byte & 0x7F) << shift
        if not byte & 0x80:
            return value, offset
        shift += 7


def decode_dex_strings(data: bytes) -> list[str]:
    if len(data) < 0x70 or not data.startswith(b"dex\n"):
        raise ValueError("not a supported DEX file")
    string_count = struct.unpack_from("<I", data, 0x38)[0]
    string_offset = struct.unpack_from("<I", data, 0x3C)[0]
    if string_count > 2_000_000 or string_offset + string_count * 4 > len(data):
        raise ValueError("DEX string table is out of bounds")
    result = []
    for index in range(string_count):
        item_offset = struct.unpack_from("<I", data, string_offset + index * 4)[0]
        _, cursor = read_uleb128(data, item_offset)  # UTF-16 length, not byte length
        end = data.find(b"\x00", cursor)
        if end < 0:
            raise ValueError("unterminated DEX string")
        raw = data[cursor:end].replace(b"\xc0\x80", b"\x00")
        result.append(raw.decode("utf-8", errors="replace"))
    return result


def matching_strings(strings: list[str]) -> list[dict]:
    matches = []
    for value in strings:
        lower = value.lower()
        hits = [token for token in TOKENS if token in lower]
        if hits:
            matches.append({"value": value[:500], "matched_tokens": hits})
    return matches


def inspect_apk(apk_path: Path, archive_member: str) -> dict:
    binaries = []
    with zipfile.ZipFile(apk_path) as apk:
        for info in apk.infolist():
            low = info.filename.lower()
            if info.is_dir():
                continue
            if not (re.fullmatch(r"classes\d*\.dex", low.rsplit("/", 1)[-1])
                    or (low.startswith("lib/") and low.endswith(".so"))):
                continue
            raw = apk.read(info)
            if low.endswith(".dex"):
                try:
                    strings = decode_dex_strings(raw)
                    matches = matching_strings(strings)
                    parse_status = "DEX_STRING_TABLE_PARSED"
                except (ValueError, struct.error) as exc:
                    strings, matches = [], []
                    parse_status = "DEX_PARSE_ERROR: " + str(exc)
            else:
                strings = [item.decode("ascii", errors="ignore") for item in ASCII_RUN.findall(raw)]
                matches = matching_strings(strings)
                parse_status = "NATIVE_ASCII_STRING_SCAN"
            binaries.append({
                "path": info.filename,
                "size_bytes": len(raw),
                "sha256": sha256(raw),
                "parse_status": parse_status,
                "matching_string_count": len(matches),
                "matching_strings": matches,
            })
    return {
        "archive_member": archive_member,
        "apk_size_bytes": apk_path.stat().st_size,
        "apk_sha256": sha256_file(apk_path),
        "binary_count": len(binaries),
        "binaries_with_reader_hints": sum(bool(item["matching_strings"]) for item in binaries),
        "binaries": binaries,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if not args.archive.is_file():
        raise SystemExit(f"Source archive not found: {args.archive}")

    results = []
    with zipfile.ZipFile(args.archive) as outer:
        members = [name for name in outer.namelist()
                   if VERSION in name and name.lower().endswith(".apk")]
        if not members:
            raise SystemExit("Exact-version Android APK not found in source archive")
        for index, member in enumerate(members):
            target = args.output.parent / f".reader-probe-{index}.apk"
            target.parent.mkdir(parents=True, exist_ok=True)
            with outer.open(member) as src, target.open("wb") as dst:
                while True:
                    block = src.read(1024 * 1024)
                    if not block:
                        break
                    dst.write(block)
            try:
                results.append(inspect_apk(target, member))
            finally:
                target.unlink(missing_ok=True)

    report = {
        "schema_version": "1.0.0",
        "target_client": VERSION,
        "purpose": "Static reader triage only; string matches do not validate cipher or schema.",
        "apk_count": len(results),
        "reader_hint_count": sum(item["binaries_with_reader_hints"] for item in results),
        "results": results,
        "acceptance_policy": "No cipher, schema or source field is approved from string hits alone.",
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({
        "apk_count": len(results),
        "reader_hint_count": report["reader_hint_count"],
        "report": str(args.output),
    }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
