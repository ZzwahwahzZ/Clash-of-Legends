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
import re
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


def parse_itemtype_files() -> dict:
    # Index readable, version-matched itemtype INI records without guessing field names.
    paths = sorted(
        p for p in ROOT.rglob("itemtype*.ini")
        if "ConquerOnline-1.1.2.3" in p.as_posix()
        and "/ini/itemtype/" in p.as_posix()
        and "/ini_ar/" not in p.as_posix()
        and "/ini_sp/" not in p.as_posix()
    )
    files = []
    all_ids = set()
    total_records = 0
    total_malformed = 0
    for path in paths:
        rows = []
        seen = set()
        malformed = 0
        field_histogram = {}
        for line_no, raw in enumerate(read_text(path).splitlines(), 1):
            line = raw.strip()
            if not line or line.startswith(("#", ";", "//")):
                continue
            parts = line.split("@@")
            if parts and parts[-1] == "":
                parts.pop()
            if len(parts) < 2 or not parts[0].strip().isdigit() or not parts[1].strip():
                malformed += 1
                continue
            record_id = parts[0].strip()
            if record_id in seen:
                malformed += 1
                continue
            seen.add(record_id)
            all_ids.add(record_id)
            field_count = len(parts)
            field_histogram[str(field_count)] = field_histogram.get(str(field_count), 0) + 1
            record = {
                "record_id": record_id,
                "record_name": parts[1].strip(),
                "source_line": line_no,
                "field_count": field_count,
            }
            # Preserve the observed positional value as an unnamed candidate only.
            if path.name.lower() == "itemtype13.ini" and field_count > 59:
                record["column_59_candidate"] = parts[59].strip()
            rows.append(record)
        total_records += len(rows)
        total_malformed += malformed
        files.append({
            "file": path.name,
            "source": str(path),
            "sha256": sha256(path),
            "record_count": len(rows),
            "malformed_or_duplicate_lines": malformed,
            "field_count_histogram": field_histogram,
            "records": rows,
        })
    return {
        "source_version": "ConquerOnline-1.1.2.3",
        "file_count": len(files),
        "record_count": total_records,
        "unique_record_id_count": len(all_ids),
        "malformed_or_duplicate_lines": total_malformed,
        "field_policy": "Only numeric record_id, record_name, line and field_count are named; all other columns remain opaque. itemtype13 column 59 is retained as an unnamed candidate only.",
        "record_ids": sorted(all_ids),
        "files": files,
    }


def numeric_ini_section_ids(path: Path) -> set[str]:
    if not path.is_file():
        return set()
    text = read_text(path)
    return set(re.findall(r"(?m)^\s*\[\s*(\d+)\s*\]\s*$", text))


def candidate_id_cross_check(label: str, candidate_path: Path, reference_ids: set[str]) -> dict:
    candidate_ids = numeric_ini_section_ids(candidate_path)
    overlap = candidate_ids & reference_ids
    coverage = len(overlap) / len(reference_ids) if reference_ids else 0.0
    precision = len(overlap) / len(candidate_ids) if candidate_ids else 0.0
    if not candidate_path.is_file():
        status = "NO_CANDIDATE_DECODE_OUTPUT"
    elif not reference_ids:
        status = "NO_REFERENCE_IDS"
    elif coverage >= 0.90:
        status = "HIGH_REFERENCE_ID_COVERAGE_SCHEMA_UNVERIFIED"
    elif coverage >= 0.50:
        status = "PARTIAL_REFERENCE_ID_COVERAGE_SCHEMA_UNVERIFIED"
    else:
        status = "LOW_REFERENCE_ID_COVERAGE"
    return {
        "dataset": label,
        "candidate_path": str(candidate_path),
        "candidate_section_count": len(candidate_ids),
        "reference_id_count": len(reference_ids),
        "overlap_count": len(overlap),
        "reference_coverage_percent": round(coverage * 100.0, 2),
        "candidate_precision_percent": round(precision * 100.0, 2),
        "overlap_id_samples": sorted(overlap)[:40],
        "status": status,
        "acceptance": "NOT_ACCEPTED_FOR_RUNTIME; ID overlap does not validate field semantics or the complete mobile schema.",
    }


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
        "itemtype_catalog": None,
        "candidate_mobile_id_cross_checks": {},
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
    itemtype_data = parse_itemtype_files()
    if itemtype_data["file_count"] > 0:
        (OUT / "itemtype_source_catalog.json").write_text(
            json.dumps(itemtype_data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        result["itemtype_catalog"] = {
            "file_count": itemtype_data["file_count"],
            "record_count": itemtype_data["record_count"],
            "unique_record_id_count": itemtype_data["unique_record_id_count"],
            "malformed_or_duplicate_lines": itemtype_data["malformed_or_duplicate_lines"],
            "source_version": itemtype_data["source_version"],
        }
    else:
        result["blocked_sources"].append({"role": "readable_itemtype_definitions", "reason": "No version-matched itemtype INI files found"})

    monster_ids = {str(row["record_id"]) for row in parse_monsters(monster)["records"]} if monster else set()
    item_ids = set(itemtype_data["record_ids"])
    candidate_dir = Path("build/gameplay_decode_candidates")
    cross_checks = {
        "itemcfg_vs_itemtype_ids": candidate_id_cross_check(
            "itemcfg.dat sections vs readable itemtype INI IDs",
            candidate_dir / "item_definitions_itemcfg_seed_9527.txt", item_ids
        ),
        "monster_dat_vs_monstertype_ids": candidate_id_cross_check(
            "monster.dat sections vs readable monstertype.ini IDs",
            candidate_dir / "monster_definitions_monster_seed_9527.txt", monster_ids
        ),
        "copydrop_vs_monstertype_ids": candidate_id_cross_check(
            "copydrop.dat sections vs readable monstertype.ini IDs",
            candidate_dir / "monster_drop_rules_copydrop_seed_9527.txt", monster_ids
        ),
    }
    result["candidate_mobile_id_cross_checks"] = cross_checks

    for role, filename in [
        ("item_definitions", "itemcfg.dat"),
        ("monster_definitions", "monster.dat"),
        ("monster_drop_rules", "copydrop.dat"),
        ("quest_definitions", "questinfo.dat"),
        ("quest_item_requirements", "taskitem_info.dat"),
        ("refinement_visual_effects", "item_refine_effect.dat"),
        ("extended_refinement_visual_effects", "item_refine_effect_ex.dat"),
    ]:
        found = sorted(ROOT.rglob(filename))
        candidate_map = {
            "item_definitions": cross_checks["itemcfg_vs_itemtype_ids"],
            "monster_definitions": cross_checks["monster_dat_vs_monstertype_ids"],
            "monster_drop_rules": cross_checks["copydrop_vs_monstertype_ids"],
        }
        candidate = candidate_map.get(role)
        status = "ENCRYPTED_OR_UNDOCUMENTED_MOBILE_FORMAT_NOT_DECODED"
        if candidate and candidate["status"] in ("HIGH_REFERENCE_ID_COVERAGE_SCHEMA_UNVERIFIED", "PARTIAL_REFERENCE_ID_COVERAGE_SCHEMA_UNVERIFIED"):
            status = candidate["status"]
        elif candidate and candidate["status"] == "LOW_REFERENCE_ID_COVERAGE":
            status = "CANDIDATE_TEXT_FOUND_BUT_ID_CROSS_CHECK_LOW"
        result["blocked_sources"].append({
            "role": role,
            "source_paths": [str(p) for p in found],
            "status": status,
            "rule": "Do not import into runtime until mobile field semantics and version-specific schema are validated.",
        })
    REPORT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if result["blocked_sources"] and (not monster or not gem):
        raise SystemExit("Required readable source file missing; see report.")
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
