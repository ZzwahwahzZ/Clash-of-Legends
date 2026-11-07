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

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--catalog", type=Path, required=True)
    ap.add_argument("--analysis", type=Path, required=True)
    ap.add_argument("--output", type=Path, required=True)
    a = ap.parse_args()
    src = load(a.catalog)
    analysis = load(a.analysis)
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
        rows[mid] = {
            "id": mid,
            "name": str(raw.get("name", "")),
            "name_ar": str(ar_names.get(mid, "")),
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
        "missions": list(rows.values()),
    }
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(output, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    assert len(rows) == 2509, f"Expected 2509 unique source missions, got {len(rows)}"
    assert len(output["maps"]) == 413, f"Expected 413 map index records, got {len(output['maps'])}"
    assert len(output["duplicate_mission_ids"]) == 1 and output["duplicate_mission_ids"][0] == "3938"
    print(f"Imported {len(rows)} unique missions, {len(output['maps'])} map IDs; duplicate IDs: {output['duplicate_mission_ids']}; bytes={a.output.stat().st_size}")

if __name__ == "__main__":
    main()
