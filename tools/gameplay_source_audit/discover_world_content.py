#!/usr/bin/env python3
"""Discover exact-version Mobile world, city, NPC, dialogue and quest source members.

This is an inventory stage only. It records source paths, hashes and format clues;
it never interprets undocumented binary fields or exports proprietary source text.
"""
from __future__ import annotations
import argparse, hashlib, json, re, zipfile
from pathlib import Path
import tempfile

VERSION = "ConquerOnline-1.1.2.3"
ROOT_MARKER = "assets/ConquerRes/"
PATTERNS = {
    "quest": re.compile(r"(quest|task|mission|taskitem)", re.I),
    "dialogue": re.compile(r"(dialog|talk|speech|chat|message|story)", re.I),
    "npc": re.compile(r"(^|[/_.-])(npc|role|character)([/_.-]|$)", re.I),
    "world_map": re.compile(r"(dmap|mapinfo|maplist|mapid|mapname|worldmap|map/|maps/)", re.I),
    "city_portal": re.compile(r"(city|town|portal|teleport|transfer|gate|warp)", re.I),
}
TEXT_EXTS = {".ini", ".txt", ".lua", ".json", ".xml", ".csv", ".cfg", ".dat"}

def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def collect_sources(archive: Path) -> list[tuple[str, str, bytes]]:
    sources = []
    with zipfile.ZipFile(archive) as outer, tempfile.TemporaryDirectory(prefix="world-source-") as td:
        nested = []
        for name in outer.namelist():
            if VERSION in name and ROOT_MARKER in name:
                rel = name.split(ROOT_MARKER, 1)[1].replace("\\", "/")
                if any(pattern.search(rel) for pattern in PATTERNS.values()):
                    sources.append((rel, name, outer.read(name)))
            elif VERSION in name and name.lower().endswith(".apk"):
                target = Path(td) / (str(len(nested)) + ".apk")
                with outer.open(name) as src, target.open("wb") as dst:
                    while True:
                        block = src.read(1024 * 1024)
                        if not block: break
                        dst.write(block)
                nested.append((target, name))
        for target, outer_name in nested:
            nested_zip = zipfile.ZipFile(target)
            for name in nested_zip.namelist():
                if name.startswith(ROOT_MARKER):
                    rel = name.split(ROOT_MARKER, 1)[1].replace("\\", "/")
                    sources.setdefault(rel, []).append((nested_zip, name, outer_name + "!" + name))
        return sources

def inspect_member(data: bytes, display: str, rel: str) -> dict:
    ext = Path(rel).suffix.lower()
    result = {
        "relative_path": rel, "source_member": display, "extension": ext,
        "size_bytes": len(data), "sha256": sha(data),
        "format_status": "OPAQUE_BINARY_OR_UNRECOGNIZED",
    }
    if ext in TEXT_EXTS:
        decoded = None
        encoding = None
        for candidate in ("utf-8-sig", "utf-8", "gb18030", "cp1252"):
            try:
                decoded = data.decode(candidate)
                encoding = candidate
                break
            except UnicodeDecodeError:
                pass
        if decoded is not None:
            lines = [line.strip() for line in decoded.splitlines() if line.strip()]
            sections = sum(1 for line in lines if line.startswith("[") and "]" in line)
            kv = sum(1 for line in lines if "=" in line and not line.startswith(("#", ";", "//")))
            atat = sum(1 for line in lines if "@@" in line)
            result.update({
                "format_status": "READABLE_TEXT_INVENTORIED_NOT_SEMANTICALLY_PARSED",
                "encoding_candidate": encoding, "line_count": len(lines),
                "ini_section_count": sections, "key_value_line_count": kv,
                "at_at_delimited_line_count": atat,
                "sample_line_shapes": [line[:120] for line in lines[:3]],
            })
    return result

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("archive", type=Path)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    sources = collect_sources(args.archive)
    matches = []
    for rel, display, data in sorted(sources, key=lambda item: (item[0], item[1])):
        groups = [key for key, pattern in PATTERNS.items() if pattern.search(rel)]
        if not groups:
            continue
        entry = inspect_member(data, display, rel)
        entry["candidate_domains"] = groups
        matches.append(entry)
    matches.sort(key=lambda x: (x["candidate_domains"][0], x["relative_path"], x["source_member"]))
    summary = {
        "schema_version": "1.0.0",
        "source_version": VERSION,
        "archive_name": args.archive.name,
        "version_matched_candidate_paths": len(sources),
        "candidate_member_count": len(matches),
        "candidate_counts_by_domain": {
            key: sum(1 for row in matches if key in row["candidate_domains"])
            for key in PATTERNS
        },
        "policy": "Path/name and format discovery only. No undocumented IDs, field semantics, dialogue strings, map geometry or quest logic are inferred.",
        "members": matches,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("WORLD CONTENT SOURCE DISCOVERY")
    print(json.dumps({k:v for k,v in summary.items() if k not in ("members", "policy")}, ensure_ascii=False))
    for row in matches:
        print(f'{",".join(row["candidate_domains"])} | {row["relative_path"]} | {row["extension"]} | {row["format_status"]} | {row["size_bytes"]} bytes | {row["sha256"]}')

if __name__ == "__main__":
    main()
