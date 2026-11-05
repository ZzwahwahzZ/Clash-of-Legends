#!/usr/bin/env python3
"""Build provenance-preserving catalogs from explicitly readable mobile source files.

This parser deliberately keeps positional monster fields opaque. It only labels the
first two @@ columns as record_id and record_name because those are directly visible
in the source rows. It does not infer undocumented column meanings or fabricate drops.
"""
from __future__ import annotations
import configparser
import hashlib
import json
from pathlib import Path

ROOT = Path("resource_stage")
OUT = ROOT / "world" / "gameplay_reference"
REPORT = Path("reports") / "gameplay-readable-catalog-report.json"


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def find_one(filename: str, preferred: str | None = None) -> Path | None:
    if preferred:
        p = ROOT / preferred
        if p.is_file():
            return p
    matches = sorted(ROOT.rglob(filename))
    return matches[0] if matches else None


def read_text(path: Path) -> str:
    raw = path.read_bytes()
    for encoding in ("utf-8-sig", "utf-8", "cp1252", "gbk", "latin-1"):
        try:
            return raw.decode(encoding)
        except UnicodeDecodeError:
            pass
    raise RuntimeError(f"Unable to decode text source: {path}")


def parse_monsters(path: Path) -> dict:
    text = read_text(path)
    rows = []
    malformed = 0
    seen = set()
    for line_no, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith(("#", ";", "//")):
            continue
        parts = line.split("@@")
        if parts and parts[-1] == "":
            parts.pop()
        if len(parts) < 3 or not parts[0].strip().isdigit() or not parts[1].strip():
            malformed += 1
            continue
        record_id = parts[0].strip()
        if record_id in seen:
            malformed += 1
            continue
        seen.add(record_id)
        rows.append({
            "record_id": record_id,
            "record_name": parts[1].strip(),
            "source_line": line_no,
            "opaque_fields": parts[2:],
            "opaque_field_count": len(parts) - 2,
        })
    return {
        "source": str(path),
        "sha256": sha256(path),
        "record_count": len(rows),
        "malformed_or_duplicate_lines": malformed,
        "field_policy": "Only record_id and record_name are named; all remaining columns are preserved as opaque_fields pending a version-matched schema.",
        "records": rows,
    }


def parse_gem_ini(path: Path) -> dict:
    text = read_text(path)
    parser = configparser.ConfigParser(interpolation=None, strict=False, delimiters=("=",))
    parser.optionxform = str
    parser.read_string(text)
    sections = []
    for section in parser.sections():
        sections.append({
            "section": section,
            "values": dict(parser.items(section, raw=True)),
        })
    return {
        "source": str(path),
        "sha256": sha256(path),
        "section_count": len(sections),
        "sections": sections,
        "field_policy": "Preserves source section/key/value strings; no gameplay effects are inferred from key names.",
    }


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    monster = find_one(
        "monstertype.ini",
        "world/apk_assets/ConquerOnline-1.1.2.3/assets/ConquerRes/ini/monstertype.ini",
    )
    gem = find_one(
        "gemtip.ini",
        "world/apk_assets/ConquerOnline-1.1.2.3/assets/ConquerRes/ini/gemtip.ini",
    )
    result = {
        "schema_version": "1.0.0",
        "reference": "Supplied Conquer Online Mobile source archives",
        "policy": "Only directly readable source records are cataloged. No item/drop/quest/refinement values are inferred from encrypted probes or external PC-client schemas.",
        "monster_type_catalog": None,
        "gem_definition_catalog": None,
        "blocked_sources": [],
    }
    if monster:
        data = parse_monsters(monster)
        result["monster_type_catalog"] = {
            "source": data["source"], "sha256": data["sha256"],
            "record_count": data["record_count"],
            "malformed_or_duplicate_lines": data["malformed_or_duplicate_lines"],
        }
        (OUT / "monster_type_source_catalog.json").write_text(
            json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
    else:
        result["blocked_sources"].append({"role": "monster_type_definitions", "reason": "monstertype.ini not found"})
    if gem:
        data = parse_gem_ini(gem)
        result["gem_definition_catalog"] = {
            "source": data["source"], "sha256": data["sha256"],
            "section_count": data["section_count"],
        }
        (OUT / "gem_definition_source_catalog.json").write_text(
            json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
    else:
        result["blocked_sources"].append({"role": "gem_definitions", "reason": "gemtip.ini not found"})
    for role, filename in [
        ("item_definitions", "itemcfg.dat"),
        ("monster_drop_rules", "copydrop.dat"),
        ("quest_definitions", "questinfo.dat"),
        ("quest_item_requirements", "taskitem_info.dat"),
        ("refinement_visual_effects", "item_refine_effect.dat"),
        ("extended_refinement_visual_effects", "item_refine_effect_ex.dat"),
    ]:
        found = sorted(ROOT.rglob(filename))
        result["blocked_sources"].append({
            "role": role,
            "source_paths": [str(p) for p in found],
            "status": "ENCRYPTED_OR_UNDOCUMENTED_MOBILE_FORMAT_NOT_DECODED",
            "rule": "Do not import fabricated item/drop/quest/refinement values into runtime tables.",
        })
    REPORT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if result["blocked_sources"] and (not monster or not gem):
        raise SystemExit("Required readable source file missing; see report.")
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
