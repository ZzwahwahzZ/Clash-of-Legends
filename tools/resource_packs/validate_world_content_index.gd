extends SceneTree

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	await process_frame
	var index := root.get_node_or_null("WorldContentIndex")
	if index == null:
		_fail("WorldContentIndex autoload is missing.")
		return
	var status: Dictionary = index.get_index_status()
	if not bool(status.get("ready", false)):
		_fail("World source index did not load: " + str(status.get("error", "unknown error")))
		return
	if int(status.get("map_records", 0)) < 400 or int(status.get("unique_maps", 0)) < 400:
		_fail("Expected at least 400 source map records and unique IDs.")
		return
	if int(status.get("npc_templates", 0)) < 2500:
		_fail("Source NPC template catalog is incomplete.")
		return
	if int(status.get("quests", 0)) < 2400:
		_fail("Source quest catalog is incomplete.")
		return
	var map_data: Dictionary = index.get_map_by_id(1002)
	if map_data.is_empty():
		_fail("Known source map 1002 is missing.")
		return
	var known_quest: Array = index.get_quests_by_mission_id(6126)
	if known_quest.is_empty():
		_fail("Known source quest 6126 is missing.")
		return
	var target: Dictionary = index.get_quest_npc_target(6126, false)
	if target.is_empty() or int(target.get("map_id", -1)) != 1002:
		_fail("Quest 6126 did not resolve its source NPC and map reference.")
		return
	if index.get_quests_for_npc(20536).is_empty():
		_fail("Source NPC 20536 is not connected to its quest records.")
		return
	if index.get_quests_for_map(1002).is_empty():
		_fail("Source map 1002 is not connected to its quest records.")
		return
	if not index.is_source_quest_available(6126, 90, 0, 0, []):
		_fail("Level gate for source quest 6126 was not accepted at level 90.")
		return
	if index.is_source_quest_available(6126, 89, 0, 0, []):
		_fail("Level gate for source quest 6126 was incorrectly accepted below level 90.")
		return
	if not index.is_source_quest_available(650, 8, 10, 0, []):
		_fail("Profession gate for source quest 650 was not accepted for profession 10.")
		return
	if index.is_source_quest_available(650, 8, 20, 0, []):
		_fail("Profession gate for source quest 650 was incorrectly accepted for profession 20.")
		return
	if index.get_quests_by_mission_id(3938).size() != 2:
		_fail("Duplicate mission ID 3938 rows were not preserved.")
		return
	var duplicate_map: Dictionary = index.get_map_by_id(10246)
	if duplicate_map.is_empty() or duplicate_map.get("_duplicate_source_records", []).size() != 1:
		_fail("Duplicate map ID 10246 source records were not preserved.")
		return
	print("RUNTIME WORLD CONTENT INDEX AUDIT PASSED: ", status)
	quit(0)

func _fail(message: String) -> void:
	push_error("RUNTIME WORLD CONTENT INDEX AUDIT FAILED: " + message)
	quit(1)
