# Mobile quest-to-world linkage contract

**Status:** research contract; not runtime content.  
**Target client:** Conquer Online Mobile 1.1.2.3 (com.Tq.CQ2ClientAndroid).  
**Branch:** research/mobile-quest-dat-decoder.

This contract defines how validated quest records will connect to the playable city, maps, NPCs, monsters, items and rewards. It deliberately contains no guessed source IDs. Official-guide names and coordinates remain reference evidence until matched to the target APK resources.

## 1. Core records

Use stable source IDs as strings at ingestion time so leading zeroes and non-decimal identifiers are not lost. Keep the original raw value alongside any normalized numeric value.

- **Quest:** source_id, name_key, description_key, quest_type, class_gate, level_min, level_max, rebirth_gate, sphere_gate, repeat_policy, availability_window, source_file, source_hash, confidence.
- **QuestStage:** source_id, quest_id, sequence, objective_type, target_id, required_count, turn_in_npc_id, map_id, coordinate, next_stage_ids.
- **NPC:** source_id, name_key, map_id, x, y, role, dialogue_id, interaction_options, source_file, source_hash.
- **Map:** source_id, name_key, resource_key, bounds, entry_points, exit_links, navigation_resource, source_file, source_hash.
- **Monster:** source_id, name_key, map_id, spawn_group_id, drop_table_id, source_file, source_hash.
- **Item:** source_id, name_key, item_type, stack_policy, quest_item, source_file, source_hash.
- **Reward:** source_id, reward_kind, item_id, amount, experience, points, claim_policy, source_file, source_hash.

Every record carries provenance. Never discard the original source path, byte hash, locale, client version or extraction method.

## 2. Relationship graph

Represent relationships as explicit edges rather than relying on names or array position:

- QUEST_HAS_STAGE: Quest → QuestStage
- STAGE_REQUIRES_QUEST: QuestStage → prerequisite Quest
- STAGE_TALKS_TO: QuestStage → NPC
- NPC_LOCATED_ON: NPC → Map
- STAGE_OCCURS_ON: QuestStage → Map
- STAGE_TARGETS_MONSTER: QuestStage → Monster
- STAGE_REQUIRES_ITEM: QuestStage → Item
- STAGE_GRANTS_REWARD: QuestStage → Reward
- QUEST_UNLOCKS_MAP: Quest → Map
- QUEST_UNLOCKS_SYSTEM: Quest → System
- MAP_CONNECTS_TO: Map → Map, with an explicit exit/entry pair and transition rule

An edge must include source_record, source_field, source_file, source_hash, and confidence. A relation inferred only from an official guide must be marked GUIDE_REFERENCE; only a relation read from the exact APK and cross-checked against the referenced entity may be marked APK_VERIFIED.

## 3. City and map integration

The city is a first-class map in the same graph, not a special hard-coded quest hub. The world map should be built from validated map IDs and explicit transition links. NPC coordinates are map-local coordinates and must never be interpreted as world coordinates without the map transform.

For each NPC waypoint, validate:
1. NPC map ID exists.
2. Coordinates fall within that map's navigable bounds.
3. The target location is reachable through the map navigation data.
4. Dialogue/interaction options resolve to a known quest, shop, service or activity.
5. A quest's next stage remains reachable after the current stage is completed.

For each map transition, validate both ends: source exit exists, destination entry exists, and the transition does not point to a missing map. Preserve one-way transitions if the source data says they are one-way.

## 4. Quest-chain execution

A quest is a directed graph, not necessarily a simple linear list. Preserve branch conditions, class gates, level/rebirth gates, repeat/reset rules, timed availability, alternative turn-ins and failure paths.

The runtime quest tracker should resolve a stage into:
- the objective and remaining count;
- the exact target entity;
- a map-local waypoint;
- a navigation route from the player's current map;
- an interaction action when the player reaches the NPC/objective;
- the next eligible stage after authoritative completion.

Do not advance a quest solely because the player entered a map or touched a guessed coordinate. Objective completion must match the source-defined condition.

## 5. Evidence and acceptance levels

Use these states consistently:

- UNVERIFIED_CANDIDATE: filename/content heuristic only.
- CIPHER_CANDIDATE: output from a candidate decryption; not accepted as readable source.
- SOURCE_READABLE: structure and encoding are readable, but schema semantics are not yet confirmed.
- APK_SCHEMA_VERIFIED: field meanings and record boundaries match the exact Mobile reader/build.
- CROSS_FILE_JOIN_VERIFIED: referenced NPC/map/item/monster/reward IDs resolve to independently verified records.
- RUNTIME_ACCEPTED: integration tests prove the graph behaves correctly in the game.

A decoded Lua-looking file is not enough to pass beyond CIPHER_CANDIDATE. A guide coordinate is not enough to create an APK-verified NPC record.

## 6. Required integrity report before runtime import

Generate counts and explicit unresolved lists for:
- duplicate quest, stage, NPC, map, monster, item and reward IDs;
- missing prerequisite quests and cyclic prerequisite edges;
- missing NPC/map/monster/item/reward references;
- NPC coordinates outside map bounds or outside navigable space;
- quest stages with no valid next stage or terminal condition;
- map exits whose destination entry is missing;
- locale variants whose source IDs disagree;
- timed/event quests with missing start/end/reset metadata.

The importer must fail closed when a required reference is unresolved. It may retain the candidate in the research report, but must not silently substitute a similarly named entity.

## 7. Initial documented guide anchors (not source IDs)

The official Mobile guide catalogue already documents Twin City NPC anchors such as Eloise (441,379), Dunn Berg (383,346), Chinju (443,293), Roberts (349,342) and Splinter (392,324). These are useful validation targets for the eventual APK extraction. They must remain guide-reference fixtures until their NPC IDs, map IDs, coordinate system and current-build behavior are confirmed from the 1.1.2.3 client data.

The next data milestone is therefore not to hand-author a quest chain from these coordinates. It is to obtain the exact-version source inventory, verify the decoder against the Android reader, extract stable IDs, then build and validate the graph described above.
