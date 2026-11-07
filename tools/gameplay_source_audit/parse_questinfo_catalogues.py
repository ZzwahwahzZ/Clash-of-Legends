#!/usr/bin/env python3
"""Read-only audit of the three Mobile questinfo.ini locale catalogues.

This emits aggregate metadata only; it never copies quest text or proprietary
records into the report. The INI source files remain in the decoded APK output.
"""
from __future__ import annotations
import argparse
import collections
import hashlib
import json
from pathlib import Path
import re
import sys

LANG_PATHS = {
    "en": Path("ini/questinfo.ini"),
    "ar": Path("ini_ar/questinfo.ini"),
    "es": Path("ini_sp/questinfo.ini"),
}
KEY_FIELDS = [
    "MissionId", "Name", "TypeId", "BigTypeId", "ActivityType",
    "Prequest", "Map", "BeginNpcId", "FinishNpcId", "IntentAmount",
    "Content", "Prize", "IntentionDesp", "PersonalNpcId1", "AutoLuaCmd",
]

def parse_ini(path: Path):
    raw = path.read_bytes()
    source = raw.decode("utf-8-sig", errors="replace")
    parts = re.split(r"^\[([^\]]+)\]\s*$", source, flags=re.M)
    sections = {}
    for i in range(1, len(parts), 2):
        name, body = parts[i], parts[i + 1]
        fields = {}
        for line in body.splitlines():
            if "=" not in line:
                continue
            key, value = line.split("=", 1)
            fields[key.strip()] = value.strip()
        sections[name] = fields
    header = sections.get("TaskType", {})
    type_names = {}
    for i in range(1, int(header.get("Num", "0")) + 1):
        type_id = header.get(f"TypeId{i}")
        if type_id is not None:
            type_names[type_id] = header.get(f"TypeName{i}", "")
    records = []
    for section, fields in sections.items():
        if section.isdigit():
            records.append((int(section), fields))
    records.sort(key=lambda item: item[0])
    return raw, sections, type_names, records

def summarize(path: Path, language: str):
    raw, sections, type_names, records = parse_ini(path)
    mission_sections = collections.defaultdict(list)
    for section, record in records:
        mission_id = record.get("MissionId", "")
        if mission_id:
            mission_sections[mission_id].append({
                "section": section,
                "name": record.get("Name", ""),
                "type_id": record.get("TypeId", ""),
            })
    duplicates = {
        mission_id: rows for mission_id, rows in mission_sections.items()
        if len(rows) > 1
    }
    type_counts = collections.Counter(
        record.get("TypeId", "<missing>") for _, record in records
    )
    field_presence = {
        key: sum(bool(record.get(key, "")) for _, record in records)
        for key in KEY_FIELDS
    }
    intention_counts = {
        str(i): sum(bool(record.get(f"Intention{i}", "")) for _, record in records)
        for i in range(1, 11)
    }
    map_counts = collections.Counter(
        record.get("Map", "<missing>") for _, record in records
    )
    activity_counts = collections.Counter(
        record.get("ActivityType", "<missing>") for _, record in records
    )
    complete_counts = collections.Counter(
        record.get("CompleteFlag", "<missing>") for _, record in records
    )
    declared_total = int(
        sections.get("TotalMission", {}).get("TotalMission", "0") or 0
    )
    return {
        "language": language,
        "source_relative_path": path.as_posix(),
        "source_sha256": hashlib.sha256(raw).hexdigest(),
        "source_bytes": len(raw),
        "declared_total": declared_total,
        "numeric_record_sections": len(records),
        "unique_mission_ids": len(mission_sections),
        "duplicate_mission_ids": duplicates,
        "task_type_names": type_names,
        "task_type_record_counts": dict(sorted(type_counts.items())),
        "activity_type_record_counts": dict(sorted(activity_counts.items())),
        "complete_flag_record_counts": dict(sorted(complete_counts.items())),
        "map_value_counts": dict(sorted(map_counts.items())),
        "nonzero_map_record_count": sum(
            count for map_id, count in map_counts.items()
            if map_id not in ("0", "", "<missing>")
        ),
        "field_nonempty_record_counts": field_presence,
        "intention_field_record_counts": intention_counts,
        "record_section_count_matches_declared_total": (
            len(records) == declared_total
        ),
    }, set(mission_sections)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--conquerres-root", type=Path, required=True,
                        help="Decoded ConquerRes directory containing ini/, ini_ar/, ini_sp/")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    results = {}
    id_sets = {}
    for language, relative in LANG_PATHS.items():
        path = args.conquerres_root / relative
        if not path.is_file():
            raise SystemExit(f"Missing required locale catalogue: {path}")
        results[language], id_sets[language] = summarize(path, language)
    cross_locale = {}
    for left, right in (("en", "ar"), ("en", "es"), ("ar", "es")):
        cross_locale[f"{left}_{right}"] = {
            "left_unique_ids": len(id_sets[left]),
            "right_unique_ids": len(id_sets[right]),
            "ids_only_in_left": sorted(id_sets[left] - id_sets[right]),
            "ids_only_in_right": sorted(id_sets[right] - id_sets[left]),
            "shared_id_count": len(id_sets[left] & id_sets[right]),
        }
    report = {
        "schema_version": "1.0.0",
        "source_version": "ConquerOnline-1.1.2.3",
        "source_scope": "Base APK decoded resources; exact locale INI paths and hashes recorded per language",
        "policy": "Aggregate audit only. Record sections are not asserted to be unique live quests. No runtime data is generated.",
        "locales": results,
        "cross_locale_mission_id_comparison": cross_locale,
        "known_caveats": [
            "A numeric INI section is a catalogue record, not proof of an independently playable quest.",
            "MissionId collisions are preserved and reported; do not deduplicate without understanding the client selection logic.",
            "Locale catalogues have different record counts and mission-ID sets; the English, Arabic and Spanish files are not interchangeable.",
            "TaskType labels are localized data and contain apparent semantic mismatches that require review before UI normalization.",
            "Fields such as BeginNpcId, FinishNpcId, Map, Intention and Prize are source declarations; their runtime interpretation and references still require corroboration."
        ],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n",
                           encoding="utf-8")
    print(json.dumps({
        "output": str(args.output),
        "locales": {
            key: {
                "declared_total": value["declared_total"],
                "record_sections": value["numeric_record_sections"],
                "unique_ids": value["unique_mission_ids"],
                "duplicate_id_count": len(value["duplicate_mission_ids"]),
                "type_counts": value["task_type_record_counts"],
            } for key, value in results.items()
        },
        "cross_locale": {
            key: {
                "shared": value["shared_id_count"],
                "only_left": len(value["ids_only_in_left"]),
                "only_right": len(value["ids_only_in_right"]),
            } for key, value in cross_locale.items()
        }
    }, ensure_ascii=False, indent=2), flush=True)
    if any(not value["record_section_count_matches_declared_total"]
           for value in results.values()):
        raise SystemExit(2)

if __name__ == "__main__":
    main()
