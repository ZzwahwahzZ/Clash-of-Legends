#!/usr/bin/env python3
"""Build a compact, provenance-preserving runtime quest source catalog.

The input is the retained Mobile 1.1.2.3 evidence artifact. This importer does
not promote candidate NPC/dialogue joins or opaque reward payloads to verified
runtime behavior.
"""
from __future__ import annotations
import argparse, json
from pathlib import Path

def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))

def parse_ini_records(path: Path):
    records, current = {}, None
    if not path.is_file():
        raise SystemExit(f"Arabic quest source is missing: {path}")
    for line in path.read_text(encoding="utf-8-sig", errors="replace").splitlines():
        value = line.strip()
        if not value or value.startswith((";", "#", "//")):
            continue
        if value.startswith("[") and "]" in value:
            current = {}
            records[value[1:value.index("]")].strip()] = current
        elif current is not None and "=" in value:
            key, raw = value.split("=", 1)
            current[key.strip()] = raw.strip()
    by_id = {}
    for row in records.values():
        mission_id = str(row.get("MissionId", "")).strip()
        if mission_id:
            by_id.setdefault(mission_id, row)
    return by_id

def parse_localized_endpoint(raw: str):
    parts = str(raw or "").split(",", 5)
    if len(parts) != 6:
        return {"raw": str(raw or ""), "status": "UNPARSED"}
    return {
        "npc_id": parts[0].strip(), "map_id": parts[1].strip(),
        "x_raw": parts[2].strip(), "y_raw": parts[3].strip(),
        "npc_name_ar": parts[4].strip(), "map_name_ar": parts[5].strip(),
        "raw": str(raw), "status": "SOURCE_LOCALIZED_TEXT",
    }

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--catalog", type=Path, required=True)
    ap.add_argument("--analysis", type=Path, required=True)
    ap.add_argument("--world-links", type=Path, required=True)
    ap.add_argument("--arabic-questinfo", type=Path, required=True)
    ap.add_argument("--output", type=Path, required=True)
    a = ap.parse_args()
    src = load(a.catalog)
    analysis = load(a.analysis)
    world_links = load(a.world_links)
    arabic_records = parse_ini_records(a.arabic_questinfo)
    ar_names = {str(x.get("mission_id")): x.get("name_ar", "") for x in analysis.get("missions", [])}
    rows, duplicates = {}, []
    for raw in src.get("mission_catalog", []):
        mid = str(raw.get("mission_id", "")).strip()
        if not mid:
            continue
        if mid in rows:
            duplicates.append(mid)
            continue
        begin = raw.get("begin_npc") or {}
        finish = raw.get("finish_npc") or {}
        intentions = raw.get("intentions") or []
        ar = arabic_records.get(mid, {})
        rows[mid] = {
            "id": mid,
            "name": str(raw.get("name", "")),
            "name_ar": str(ar.get("Name", ar_names.get(mid, ""))),
            "intention_description_ar": str(ar.get("IntentionDesp", "")),
            "content_ar": str(ar.get("Content", "")),
            "prize_raw_ar": str(ar.get("Prize", "")),
            "begin_npc_ar": parse_localized_endpoint(ar.get("BeginNpcId", "")),
            "finish_npc_ar": parse_localized_endpoint(ar.get("FinishNpcId", "")),
            "intentions_ar": [str(value) for key, value in ar.items() if key.startswith("Intention")],
            "type_id": str(raw.get("type_id", "")),
            "big_type_id": str(raw.get("big_type_id", "")),
            "level_min": raw.get("level_min"),
            "level_max": raw.get("level_max"),
            "profession_raw": str(raw.get("profession", "0")),
            "sex_raw": str(raw.get("sex", "0")),
            "repeat_policy_raw": str(raw.get("repeat_or_abandon", "")),
            "activity_type_raw": str(raw.get("activity_type", "")),
            "activity_begin_raw": str(raw.get("activity_begin", "")),
            "activity_end_raw": str(raw.get("activity_end", "")),
            "prerequisites": [str(x) for x in raw.get("prerequisite_mission_ids", [])],
            "begin_npc": {k: begin.get(k) for k in ("status","npc_id","map_id","x","y","npc_name","map_name","raw")},
            "finish_npc": {k: finish.get(k) for k in ("status","npc_id","map_id","x","y","npc_name","map_name","raw")},
            "map_field_raw": str(raw.get("map_field", "0")),
            "intention_description": str(raw.get("intention_description", "")),
            "intentions": [{
                "field": str(x.get("field", "")),
                "kind": str(x.get("kind", "")),
                "raw": str(x.get("raw", "")),
                "parts": [str(v) for v in x.get("parts", [])],
                "npc_id": str(x.get("npc_id", "")),
                "npc_name": str(x.get("npc_name", "")),
                "monster_name": str(x.get("monster_name", "")),
                "item_name": str(x.get("item_name", "")),
                "map_id": str(x.get("map_id", "")),
                "x": x.get("x"), "y": x.get("y"),
                "quest_id": str(x.get("quest_id", "")),
            } for x in intentions],
            "prize_raw": str(raw.get("prize_raw", "")),
            "reward_item_candidates": raw.get("reward_item_candidates", []),
            "source_section": str(raw.get("section", "")),
            "source_line": raw.get("source_line"),
            "provenance": "SOURCE_READABLE_SCHEMA_SEMANTICS_PARTIALLY_UNVERIFIED",
        }
    maps = src.get("gamemap_catalog", {}).get("records", [])
    map_name_votes = {}
    for row in rows.values():
        for endpoint in ("begin_npc", "finish_npc"):
            npc = row.get(endpoint) or {}
            map_id, map_name = str(npc.get("map_id", "")).strip(), str(npc.get("map_name", "")).strip()
            if map_id and map_name:
                map_name_votes.setdefault(map_id, {})
                map_name_votes[map_id][map_name] = map_name_votes[map_id].get(map_name, 0) + 1
        for intention in row.get("intentions", []):
            map_id = str(intention.get("map_id", "")).strip()
            map_name = str(intention.get("map_name", "")).strip()
            if map_id and map_name:
                map_name_votes.setdefault(map_id, {})
                map_name_votes[map_id][map_name] = map_name_votes[map_id].get(map_name, 0) + 1
    city_aliases = {
        ("1002", "TwinCity"): ("مدينة التوأم", "main"),
        ("1000", "DesertCity"): ("مدينة الصحراء", "minor"),
        ("1015", "BirdIsland"): ("جزيرة الطيور", "minor"),
        ("1020", "ApeCity"): ("مدينة القرود", "minor"),
        ("1011", "PhoenixCastle"): ("قلعة العنقاء", "minor"),
        ("1011", "PhoenixCastal"): ("قلعة العنقاء", "minor"),
        ("1010", "BirthVillage"): ("قرية الميلاد", "minor"),
    }
    map_names = []
    city_hubs_by_id = {}
    for map_id, votes in sorted(map_name_votes.items(), key=lambda x: int(x[0]) if x[0].isdigit() else 0):
        aliases = [{"name": name, "occurrences": count} for name, count in sorted(votes.items(), key=lambda x: (-x[1], x[0]))]
        primary = aliases[0]["name"] if aliases else ""
        map_names.append({"map_id": map_id, "primary_name": primary, "aliases": aliases})
        for alias in aliases:
            if (map_id, alias["name"]) in city_aliases:
                name_ar, city_kind = city_aliases[(map_id, alias["name"])]
                if map_id not in city_hubs_by_id:
                    city_hubs_by_id[map_id] = {
                        "map_id": map_id, "source_aliases": [],
                        "name_ar": name_ar, "name_en": alias["name"],
                        "kind": city_kind, "evidence_occurrences": 0,
                        "status": "SOURCE_NAME_MATCH_CANDIDATE_REQUIRES_MAP_RESOURCE_CONFIRMATION",
                    }
                city_hubs_by_id[map_id]["source_aliases"].append(alias["name"])
                city_hubs_by_id[map_id]["evidence_occurrences"] += alias["occurrences"]
                if alias["name"] == "PhoenixCastle":
                    city_hubs_by_id[map_id]["name_en"] = alias["name"]
    city_hubs = list(city_hubs_by_id.values())
    for hub in city_hubs:
        if not any(str(row.get("map_id")) == hub["map_id"] for row in maps):
            hub["status"] = "SOURCE_CITY_NAME_FOUND_BUT_MAP_RESOURCE_INDEX_MISSING"
    world_map_names = world_links.get("map_linkage", {}).get("map_id_names", [])
    map_directory = [{
        "map_id": str(row.get("map_id", "")),
        "gamemapex_name": row.get("gamemapex_name"),
        "resource_path": row.get("gamemap_resource"),
        "quest_source_names": row.get("quest_source_names", []),
        "mapdestination_section_count": row.get("mapdestination_section_count", 0),
        "status": "MAP_RESOURCE_INDEXED" if row.get("gamemap_resource") else "MAP_RESOURCE_MISSING_FROM_INDEX",
    } for row in world_map_names]
    npc_placements = world_links.get("npc_placements", [])
    dialogue_links = world_links.get("dialogue_linkage", {}).get("mission_dialogue_links", [])
    city_definitions = {
        "1002": ("TwinCity", "مدينة التوأم", "main"),
        "1000": ("DesertCity", "مدينة الصحراء", "minor"),
        "1010": ("BirthVillage", "قرية الميلاد", "minor"),
        "1011": ("PhoenixCastle", "قلعة العنقاء", "minor"),
        "1015": ("BirdIsland", "جزيرة الطيور", "minor"),
        "1020": ("ApeCity", "مدينة القرود", "minor"),
    }
    source_city_hubs = []
    map_by_id = {row["map_id"]: row for row in map_directory}
    for map_id, (source_name, name_ar, kind) in city_definitions.items():
        map_row = map_by_id.get(map_id, {})
        names = map_row.get("quest_source_names", [])
        source_city_hubs.append({
            "map_id": map_id, "source_name": source_name, "name_ar": name_ar,
            "name_en": source_name, "kind": kind,
            "resource_path": map_row.get("resource_path"),
            "mapdestination_section_count": map_row.get("mapdestination_section_count", 0),
            "status": "SOURCE_CITY_AND_MAP_RESOURCE_INDEXED" if map_row.get("resource_path") else "SOURCE_CITY_NAME_FOUND_BUT_MAP_RESOURCE_INDEX_MISSING",
            "name_evidence": source_name in names,
        })
    output = {
        "schema_version": "1.0.0",
        "source_version": src.get("source_version", ""),
        "status": "SOURCE_CATALOG_IMPORTED_RUNTIME_NOT_YET_ACCEPTED",
        "policy": "Source IDs and raw fields are preserved. Duplicate mission 3938 is retained once and reported. NPC template joins, dialogue associations, opaque reward payloads, and quest semantics are not promoted to verified runtime behavior.",
        "mission_count": len(rows),
        "duplicate_mission_ids": sorted(set(duplicates)),
        "source_hashes": src.get("source_files", []),
        "map_catalog_status": src.get("gamemap_catalog", {}).get("status", ""),
        "maps": maps,
        "map_names": map_names,
        "map_directory": map_directory,
        "city_hubs": source_city_hubs,
        "npc_placements": npc_placements,
        "dialogue_links": dialogue_links,
        "missions": list(rows.values()),
    }
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(output, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    assert len(rows) == 2509, f"Expected 2509 unique source missions, got {len(rows)}"
    assert len(output["maps"]) == 413, f"Expected 413 map index records, got {len(output['maps'])}"
    assert rows["650"]["name_ar"] == "تاجر الملابس الحربية", "Arabic mission 650 localization was not imported"
    assert rows["650"]["finish_npc_ar"]["npc_name_ar"] == "تاجر الملابس الحربية"
    assert len(source_city_hubs) == 6 and len(npc_placements) == 881, "Source city/NPC placement evidence count mismatch"
    assert len(output["duplicate_mission_ids"]) == 1 and output["duplicate_mission_ids"][0] == "3938"
    print(f"Imported {len(rows)} unique missions, {len(output['maps'])} map IDs; duplicate IDs: {output['duplicate_mission_ids']}; bytes={a.output.stat().st_size}")

if __name__ == "__main__":
    main()
