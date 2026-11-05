#!/usr/bin/env python3
"""Audit version-matched gameplay source tables without publishing source blobs.

The script reads selected files directly from the supplied archive. It records
hashes, file paths, parse counts and opaque key/value structures. It does not
interpret undocumented binary fields or create runtime gameplay data.
"""
from __future__ import annotations
import argparse
import configparser
import hashlib
import json
import re
import shutil
import tempfile
import zipfile
from pathlib import Path

VERSION = "ConquerOnline-1.1.2.3"
ROOT_MARKER = "assets/ConquerRes/"
TARGETS = {
    "mounts": ["ini/mountinfo.ini", "ini/mounttype.dat", "ani/dragon.ani", "ani/sdragon.ani"],
    "skills": [
        "ini/weaponskillname.ini", "ini/weaponskilllevelexp.ini", "ani/magic.ani",
        "ani/magic1.ani", "ini/autousemagic.dat", "ini/3deffectinfo.ini",
        "ini/action3deffect.ini", "ini/actionlee3deffect.ini", "ini/weaponeffect.ini",
    ],
    "equipment": [
        "ini/weapon_trans.ini", "ini/armor_trans.ini", "ini/weaponmatch.ini",
        "ini/weaponshow.ini", "ini/weaponmotiondata.dat", "ini/equiphole.ini",
        "ini/equipsolidify.ini", "ini/equiptreeinfo.ini", "ini/hundred_weapon.dat",
        "ini/luacfg/hundredweapons.dat", "ini/luacfg/phaseequip.dat",
        "ini/luacfg/strengthdevelopequip.dat", "ini/luacfg/weaponsoulstory.dat",
    ],
    "refinement": [
        "ini/item_refine_attr.dat", "ini/item_refine_cost.dat",
        "ini/item_refine_upgrade.dat", "ini/item_refine_effect.dat",
        "ini/item_refine_effect_ex.dat",
    ],
    "gems": ["ini/gemtip.ini", "ini/equiphole.ini", "ini/equipsolidify.ini"],
    "fashion": ["ini/suittype.dat", "ini/wenzhang_suit_effect.ini"],
}

def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()

def decode_text(data: bytes) -> str:
    for encoding in ("utf-8-sig", "utf-8", "gb18030", "cp1252", "latin-1"):
        try:
            return data.decode(encoding)
        except UnicodeDecodeError:
            continue
    return data.decode("utf-8", errors="replace")

def parse_ini_opaque(data: bytes) -> dict:
    text = decode_text(data)
    parser = configparser.ConfigParser(interpolation=None, strict=False, delimiters=("=",))
    parser.optionxform = str
    try:
        parser.read_string(text)
        sections = [{"section": s, "keys": list(parser[s].keys())} for s in parser.sections()]
        return {"parse_status": "INI_SECTIONS_AND_KEYS_PARSED_OPAQUE", "section_count": len(sections), "sections": sections}
    except configparser.Error as exc:
        return {"parse_status": "TEXT_PRESENT_INI_PARSE_FAILED", "error": str(exc), "line_count": len(text.splitlines())}

def parse_itemtype(data: bytes, include_column_59_candidate: bool = False) -> dict:
    text = decode_text(data)
    ids, malformed, hist = set(), 0, {}
    samples = []
    records = []
    for line_no, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith(("#", ";", "//")):
            continue
        parts = line.split("@@")
        if parts and parts[-1] == "":
            parts.pop()
        if len(parts) < 2 or not parts[0].strip().isdigit() or not parts[1].strip():
            malformed += 1
            continue
        rid = parts[0].strip()
        if rid in ids:
            malformed += 1
            continue
        ids.add(rid)
        hist[str(len(parts))] = hist.get(str(len(parts)), 0) + 1
        record = {"record_id": rid, "record_name": parts[1].strip(), "source_line": line_no, "field_count": len(parts)}
        if include_column_59_candidate and len(parts) > 59:
            record["column_59_candidate"] = parts[59].strip()
        records.append(record)
        if len(samples) < 8:
            samples.append(record)
    return {"parse_status": "RECORD_ID_NAME_ONLY_REMAINDER_OPAQUE", "record_count": len(ids),
            "malformed_or_duplicate_lines": malformed, "field_count_histogram": hist,
            "samples": samples, "records": records}

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("archive", type=Path)
    ap.add_argument("--output", type=Path, default=Path("gameplay-source-table-audit.json"))
    args = ap.parse_args()
    if not args.archive.is_file():
        raise SystemExit(f"Archive not found: {args.archive}")
    with zipfile.ZipFile(args.archive) as outer:
        results = {}
        with tempfile.TemporaryDirectory(prefix="co-source-audit-") as temp_dir:
            # The supplied bundle stores the Android client as a nested APK.
            # Index both direct archive members and files inside the exact-version APK.
            sources = {}
            nested_archives = []
            for outer_name in outer.namelist():
                if VERSION in outer_name and ROOT_MARKER in outer_name:
                    rel = outer_name.split(ROOT_MARKER, 1)[1].replace("\\\\", "/")
                    sources.setdefault(rel, []).append((outer, outer_name, outer_name))
                elif VERSION in outer_name and outer_name.lower().endswith(".apk"):
                    nested_path = Path(temp_dir) / (str(len(nested_archives)) + ".apk")
                    with outer.open(outer_name) as src, nested_path.open("wb") as dst:
                        shutil.copyfileobj(src, dst, length=1024 * 1024)
                    nested = zipfile.ZipFile(nested_path)
                    nested_archives.append(nested)
                    for inner_name in nested.namelist():
                        if inner_name.startswith(ROOT_MARKER):
                            rel = inner_name.split(ROOT_MARKER, 1)[1].replace("\\\\", "/")
                            sources.setdefault(rel, []).append((nested, inner_name, outer_name + "!" + inner_name))
            for category, targets in TARGETS.items():
                entries = []
                for rel in targets:
                    for source_zip, member, display in sources.get(rel, []):
                        data = source_zip.read(member)
                        record = {"source_member": display, "relative_path": rel, "size_bytes": len(data),
                                  "sha256": hashlib.sha256(data).hexdigest(), "parse_status": "BINARY_OR_METADATA_ONLY"}
                        if rel.lower().endswith(".ini"):
                            record.update(parse_ini_opaque(data))
                        entries.append(record)
                if category == "equipment":
                    for rel, candidates in sources.items():
                        if rel.lower().startswith("ini/itemtype/itemtype") and rel.lower().endswith(".ini"):
                            for source_zip, member, display in candidates:
                                data = source_zip.read(member)
                                record = {"source_member": display, "relative_path": rel, "size_bytes": len(data),
                                          "sha256": hashlib.sha256(data).hexdigest(), **parse_itemtype(data, include_column_59_candidate=rel.lower().endswith("itemtype13.ini"))}
                                entries.append(record)
                results[category] = entries
            itemtypes = [e for e in results["equipment"] if e["relative_path"].lower().startswith("ini/itemtype/")]
            summary = {
                "schema_version": "1.0.0",
                "source_version": VERSION,
                "archive_name": args.archive.name,
                "archive_size_bytes": args.archive.stat().st_size,
                "archive_sha256": sha256_file(args.archive),
                "version_matched_member_count": sum(len(v) for v in sources.values()),
                "categories": {k: {"file_count": len(v), "files": v} for k, v in results.items()},
                "itemtype_catalog": {
                    "file_count": len(itemtypes),
                    "record_count": sum(int(e.get("record_count", 0)) for e in itemtypes),
                    "malformed_or_duplicate_lines": sum(int(e.get("malformed_or_duplicate_lines", 0)) for e in itemtypes),
                    "column_59_candidate_count": sum(1 for e in itemtypes for row in e.get("records", []) if "column_59_candidate" in row),
                    "schema_policy": "Only numeric record ID and visible name are parsed; every remaining positional field remains opaque."
                },
                "acceptance": "SOURCE_INVENTORY_ONLY_NOT_RUNTIME_APPROVED",
                "policy": "No undocumented binary fields are decoded or guessed. No proprietary source blobs are included in this JSON report."
            }
            for nested in nested_archives:
                nested.close()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\\n", encoding="utf-8")
    print(json.dumps({k: ({"file_count": v["file_count"]} if isinstance(v, dict) and "file_count" in v else v)
                      for k, v in summary["categories"].items()}, ensure_ascii=False))
    print(json.dumps(summary["itemtype_catalog"], ensure_ascii=False))

if __name__ == "__main__":
    main()
