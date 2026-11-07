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
	var source_map_archive: Dictionary = index.get_source_map_archive(1002)
	if str(source_map_archive.get("resource_path", "")) != "map/map/newplain.7z" or not ["SOURCE_ARCHIVE_EXTRACTED_NOT_RUNTIME_READY", "SOURCE_ARCHIVE_NOT_EXTRACTED"].has(str(source_map_archive.get("status", ""))):
		_fail("WindPlain source map archive path/status metadata is inconsistent.")
		return
	if str(source_map_archive.get("status", "")) == "SOURCE_ARCHIVE_EXTRACTED_NOT_RUNTIME_READY" and str(source_map_archive.get("sha256", "")).length() != 64:
		_fail("Extracted WindPlain source map archive has no verified SHA-256.")
		return
		return
	var metadata_only_maps: Array = index.get_map_metadata_only()
	if metadata_only_maps.is_empty():
		_fail("Metadata-only map catalog was not preserved.")
		return
	var metadata_only_id := int(metadata_only_maps[0].get("map_id", -1))
	var metadata_only_entry: Dictionary = index.get_map_by_id(metadata_only_id)
	if metadata_only_entry.is_empty() or not bool(metadata_only_entry.get("metadata_only", false)):
		_fail("Metadata-only map lookup incorrectly claims an archive exists.")
		return
	var dialogue_status: Array = index.get_dialogue_source_status()
	if dialogue_status.size() != 5:
		_fail("Five decrypted source dialogue files were not registered.")
		return
	var source_dialogue: Dictionary = index.get_npc_dialogue(1051)
	if source_dialogue.is_empty() or source_dialogue.get("talks", []).is_empty():
		_fail("Known NPC dialogue 1051 was not parsed into runtime talk steps.")
		return
	var model_template: Dictionary = index.get_npc_model_template(5002)
	if str(model_template.get("fields", {}).get("Name", "")).strip_edges() != "WindSage":
		_fail("Source NPC model 5002 did not resolve to its audited WindSage template.")
		return
	var model_dialogues: Array = index.get_npc_dialogues_for_model_id(5002)
	var model_dialogue_ids: Array[int] = []
	for linked_dialogue in model_dialogues:
		model_dialogue_ids.append(int(linked_dialogue.get("dialogue_id", -1)))
	if not model_dialogue_ids.has(1060) or not model_dialogue_ids.has(1062):
		_fail("NPC model 5002 did not preserve both exact source dialogues that reference its DlgShowInfo.id.")
		return
	var dialogue_scene: PackedScene = load("res://scenes/ui/DialogueUI.tscn")
	if dialogue_scene == null:
		_fail("Dialogue UI scene could not be loaded for source-flow validation.")
		return
	var dialogue_ui: Control = dialogue_scene.instantiate()
	root.add_child(dialogue_ui)
	await process_frame
	if not dialogue_ui.show_source_dialogue(1060, "Wind Sage", "en"):
		_fail("Dialogue UI rejected a verified source dialogue.")
		return
	var option_container: VBoxContainer = dialogue_ui.get_node("Panel/OptionsVBox")
	if option_container.get_child_count() != 1:
		_fail("First source dialogue step did not expose its Next action.")
		return
	option_container.get_child(0).emit_signal("pressed")
	await process_frame
	if option_container.get_child_count() != 2:
		_fail("Second source dialogue step did not expose both localized source choices.")
		return
	option_container.get_child(1).emit_signal("pressed")
	await process_frame
	if not dialogue_ui.visible:
		_fail("Selecting the source dialogue branch did not navigate to its linked follow-up.")
		return
	dialogue_ui.queue_free()
	var first_talk: Dictionary = source_dialogue.get("talks", [])[0]
	if str(first_talk.get("text_key", "")).is_empty():
		_fail("NPC dialogue talk step has no source text key.")
		return
	var ar_text: String = index.get_dialogue_text(str(first_talk.get("text_key", "")), "ar")
	var en_text: String = index.get_dialogue_text(str(first_talk.get("text_key", "")), "en")
	if ar_text.is_empty() and en_text.is_empty():
		_fail("NPC dialogue text key could not be resolved in Arabic or English.")
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
	# Isolate the level-gate predicate itself; the real source quest 6126 has
	# additional gates and must not be assigned invented profession assumptions.
	var level_gate_fixture := {
		"min_level": 10,
		"max_level": 0,
		"profession_ids": [],
		"sex": 0,
		"prerequisite_ids": []
	}
	if not index._is_quest_available(level_gate_fixture, 10, 0, 0, []):
		_fail("Minimum-level gate rejected a character at the exact threshold.")
		return
	if index._is_quest_available(level_gate_fixture, 9, 0, 0, []):
		_fail("Minimum-level gate accepted a character below the threshold.")
		return
	# Mission 650's source profession codes are 10..15. Exercise the gate
	# predicate in isolation, while Python validation separately checks the source row.
	var profession_gate_fixture := {
		"min_level": 0,
		"max_level": 0,
		"profession_ids": [10, 11, 12, 13, 14, 15],
		"sex": 0,
		"prerequisite_ids": []
	}
	if not index._is_quest_available(profession_gate_fixture, 1, 10, 0, []):
		_fail("Profession gate rejected a profession code allowed by the source fixture.")
		return
	if index._is_quest_available(profession_gate_fixture, 1, 20, 0, []):
		_fail("Profession gate accepted a profession code not allowed by the source fixture.")
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
