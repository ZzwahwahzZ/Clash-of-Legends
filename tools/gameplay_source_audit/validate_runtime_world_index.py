#!/usr/bin/env python3
"""Structural acceptance checks for the generated Mobile 1.1.2.3 runtime world index."""
import json, sys
from pathlib import Path

path = Path(sys.argv[1] if len(sys.argv) > 1 else "data/world_content_index.json")
data = json.loads(path.read_text(encoding="utf-8"))
assert data.get("schema_version") == "1.0.0"
assert data.get("source_version") == "ConquerOnline-1.1.2.3"
maps = data.get("maps", [])
unique_maps = {int(row["map_id"]) for row in maps}
npcs = data.get("npc_templates", [])
quests = data.get("quests", [])
assert len(maps) >= 400, f"Expected at least 400 source map records, got {len(maps)}"
assert len(unique_maps) >= 400, f"Expected at least 400 unique source map IDs, got {len(unique_maps)}"
assert len(npcs) >= 2500, f"Expected at least 2500 NPC template sections, got {len(npcs)}"
assert len(quests) >= 2400, f"Expected at least 2400 quest rows, got {len(quests)}"
assert 1002 in unique_maps, "Twin City/WindPlain source map 1002 is missing"
assert any(q.get("mission_id") == 6126 for q in quests), "Known source quest 6126 is missing"
assert sum(1 for q in quests if q.get("mission_id") == 3938) == 2, "Duplicate mission 3938 rows must be preserved, not overwritten"
for q in quests:
    assert q.get("mission_id") is not None, f"Quest row {q.get('source_section')} has no MissionId"
    assert q.get("name") or q.get("name_ar"), f"Quest row {q.get('source_section')} has no localized name"
    for key in ("begin_npc", "finish_npc"):
        ref = q.get(key)
        if ref is not None and ref.get("parse_status") == "parsed":
            assert int(ref["map_id"]) > 0, f"Quest {q['mission_id']} has invalid {key} map ID"
dialogues = data.get("dialogue_sources", [])
assert dialogues and all(x.get("runtime_status") == "SOURCE_PRESENT_DECODE_NOT_VALIDATED" for x in dialogues), "Encrypted dialogue must remain explicitly unapproved"
print("RUNTIME WORLD INDEX STRUCTURE PASSED")
print(f"maps={len(maps)} unique_maps={len(unique_maps)} npc_templates={len(npcs)} quests={len(quests)} dialogue_sources={len(dialogues)}")
