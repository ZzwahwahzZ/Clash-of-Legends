extends Node
## Read-only runtime access to the verified Mobile 1.1.2.3-derived world catalog.
## Source coordinates remain source metadata until the map tile/world transform is validated.

const INDEX_PATH := "res://data/world_content_index.json"

var index_ready := false
var index_error := ""
var _index: Dictionary = {}
var _maps_by_id: Dictionary = {}
var _quests_by_section: Dictionary = {}
var _quests_by_mission_id: Dictionary = {}
var _quests_by_npc_id: Dictionary = {}
var _quests_by_map_id: Dictionary = {}
var _npc_model_templates_by_id: Dictionary = {}
var _npc_dialogues_by_id: Dictionary = {}
var _npc_dialogues_by_model_id: Dictionary = {}

func _ready() -> void:
	load_index()

func load_index() -> bool:
	index_ready = false
	index_error = ""
	_index.clear()
	_maps_by_id.clear()
	_quests_by_section.clear()
	_quests_by_mission_id.clear()
	_quests_by_npc_id.clear()
	_quests_by_map_id.clear()
	_npc_model_templates_by_id.clear()
	_npc_dialogues_by_id.clear()
	_npc_dialogues_by_model_id.clear()
	if not FileAccess.file_exists(INDEX_PATH):
		index_error = "Runtime source index is missing: " + INDEX_PATH
		push_warning(index_error)
		return false
	var file := FileAccess.open(INDEX_PATH, FileAccess.READ)
	if file == null:
		index_error = "Could not open runtime source index."
		push_error(index_error)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		index_error = "Runtime source index is not a JSON object."
		push_error(index_error)
		return false
	_index = parsed
	if str(_index.get("source_version", "")) != "ConquerOnline-1.1.2.3":
		index_error = "Runtime source index version does not match the audited Mobile source."
		push_error(index_error)
		_index.clear()
		return false
	for map_data in _index.get("maps", []):
		if not map_data is Dictionary:
			continue
		var map_id := int(map_data.get("map_id", -1))
		if map_id >= 0:
			if not _maps_by_id.has(map_id):
				_maps_by_id[map_id] = map_data
			else:
				var existing: Array = _maps_by_id[map_id].get("_duplicate_source_records", [])
				existing.append(map_data)
				_maps_by_id[map_id]["_duplicate_source_records"] = existing
	for metadata_entry in _index.get("map_metadata_without_binary_path", []):
		if not metadata_entry is Dictionary:
			continue
		var metadata_id := int(metadata_entry.get("map_id", -1))
		if metadata_id >= 0 and not _maps_by_id.has(metadata_id):
			var metadata_only: Dictionary = metadata_entry.duplicate(true)
			metadata_only["resource_path"] = ""
			metadata_only["metadata_only"] = true
			_maps_by_id[metadata_id] = metadata_only
	for quest in _index.get("quests", []):
		if not quest is Dictionary:
			continue
		var section_id := str(quest.get("source_section", ""))
		if not section_id.is_empty():
			_quests_by_section[section_id] = quest
		var mission_id := int(quest.get("mission_id", -1))
		if mission_id >= 0:
			if not _quests_by_mission_id.has(mission_id):
				_quests_by_mission_id[mission_id] = []
			_quests_by_mission_id[mission_id].append(quest)
		var quest_map_ids: Array[int] = []
		var direct_map_id := int(quest.get("map_id", 0))
		if direct_map_id > 0:
			quest_map_ids.append(direct_map_id)
		for npc_key in ["begin_npc", "finish_npc"]:
			var npc_ref: Variant = quest.get(npc_key, null)
			if npc_ref is Dictionary and str(npc_ref.get("parse_status", "")) == "parsed":
				var npc_map_id := int(npc_ref.get("map_id", 0))
				if npc_map_id > 0 and not quest_map_ids.has(npc_map_id):
					quest_map_ids.append(npc_map_id)
		for source_map_id in quest_map_ids:
			_index_quest_map(quest, source_map_id)
		_index_quest_npc(quest, quest.get("begin_npc", null), "begin")
		_index_quest_npc(quest, quest.get("finish_npc", null), "finish")
	for model_template in _index.get("npc_model_templates", []):
		if not model_template is Dictionary:
			continue
		var source_model_id := int(model_template.get("model_id", -1))
		if source_model_id > 0:
			_npc_model_templates_by_id[source_model_id] = model_template
	for dialogue in _index.get("npc_dialogues", []):
		if not dialogue is Dictionary:
			continue
		var dialogue_id := int(dialogue.get("dialogue_id", -1))
		if dialogue_id > 0:
			_npc_dialogues_by_id[dialogue_id] = dialogue
		for model_id_value in dialogue.get("model_template_ids", []):
			var model_id := int(model_id_value)
			if model_id <= 0:
				continue
			if not _npc_dialogues_by_model_id.has(model_id):
				_npc_dialogues_by_model_id[model_id] = []
			_npc_dialogues_by_model_id[model_id].append(dialogue)
	index_ready = true
	return true

func _index_quest_map(quest: Dictionary, map_id: int) -> void:
	if map_id <= 0:
		return
	if not _quests_by_map_id.has(map_id):
		_quests_by_map_id[map_id] = []
	if not _quests_by_map_id[map_id].has(quest):
		_quests_by_map_id[map_id].append(quest)

func _index_quest_npc(quest: Dictionary, npc_ref: Variant, role: String) -> void:
	if not npc_ref is Dictionary or str(npc_ref.get("parse_status", "")) != "parsed":
		return
	var npc_id := int(npc_ref.get("npc_id", -1))
	if npc_id < 0:
		return
	if not _quests_by_npc_id.has(npc_id):
		_quests_by_npc_id[npc_id] = []
	_quests_by_npc_id[npc_id].append({
		"role": role,
		"quest": quest,
		"npc": npc_ref
	})

func get_index_status() -> Dictionary:
	return {
		"ready": index_ready,
		"error": index_error,
		"source_version": str(_index.get("source_version", "")),
		"map_records": _index.get("maps", []).size(),
		"unique_maps": _maps_by_id.size(),
		"map_metadata_only": _index.get("map_metadata_without_binary_path", []).size(),
		"npc_templates": _index.get("npc_templates", []).size(),
		"npc_model_templates": _index.get("npc_model_templates", []).size(),
		"quests": _index.get("quests", []).size(),
		"dialogue_sources": _index.get("dialogue_sources", []).size()
	}

func get_maps() -> Array:
	return _index.get("maps", []).duplicate(true)

func get_map_by_id(map_id: int) -> Dictionary:
	return _maps_by_id.get(map_id, {}).duplicate(true)

func get_map_metadata_only() -> Array:
	return _index.get("map_metadata_without_binary_path", []).duplicate(true)

func get_npc_templates() -> Array:
	return _index.get("npc_templates", []).duplicate(true)

func get_npc_template_by_source_section(section_id: String) -> Dictionary:
	for entry in _index.get("npc_templates", []):
		if str(entry.get("source_section", "")) == section_id:
			return entry.duplicate(true)
	return {}

func get_npc_model_template(model_id: int) -> Dictionary:
	return _npc_model_templates_by_id.get(model_id, {}).duplicate(true)

func get_quests() -> Array:
	return _index.get("quests", []).duplicate(true)

func get_quest_by_source_section(section_id: String) -> Dictionary:
	return _quests_by_section.get(section_id, {}).duplicate(true)

func get_quests_by_mission_id(mission_id: int) -> Array:
	return _quests_by_mission_id.get(mission_id, []).duplicate(true)

func get_quests_for_map(map_id: int) -> Array:
	return _quests_by_map_id.get(map_id, []).duplicate(true)

func get_quests_for_npc(npc_id: int) -> Array:
	return _quests_by_npc_id.get(npc_id, []).duplicate(true)


func get_quests_for_profession(profession_id: int) -> Array:
	var result: Array = []
	for quest in _index.get("quests", []):
		var allowed: Array = quest.get("profession_ids", [])
		if allowed.is_empty() or allowed.has(0) or allowed.has(profession_id):
			result.append(quest)
	return result.duplicate(true)

func get_available_quests_for_character(level: int, profession_id: int, sex: int = 0, completed_mission_ids: Array = []) -> Array:
	var result: Array = []
	for quest in _index.get("quests", []):
		if _is_quest_available(quest, level, profession_id, sex, completed_mission_ids):
			result.append(quest)
	return result.duplicate(true)

func is_source_quest_available(mission_id: int, level: int, profession_id: int, sex: int = 0, completed_mission_ids: Array = []) -> bool:
	for quest in _quests_by_mission_id.get(mission_id, []):
		if _is_quest_available(quest, level, profession_id, sex, completed_mission_ids):
			return true
	return false

func _is_quest_available(quest: Dictionary, level: int, profession_id: int, sex: int, completed_mission_ids: Array) -> bool:
	var min_level := int(quest.get("min_level", 0))
	var max_level := int(quest.get("max_level", 0))
	if min_level > 0 and level < min_level:
		return false
	if max_level > 0 and level > max_level:
		return false
	var allowed_professions: Array = quest.get("profession_ids", [])
	if not allowed_professions.is_empty() and not allowed_professions.has(0) and not allowed_professions.has(profession_id):
		return false
	var required_sex := int(quest.get("sex", 0))
	if required_sex != 0 and sex != 0 and required_sex != sex:
		return false
	for prerequisite in quest.get("prerequisite_ids", []):
		if int(prerequisite) > 0 and not completed_mission_ids.has(int(prerequisite)):
			return false
	return true

func get_quest_npc_target(mission_id: int, for_finish: bool = false) -> Dictionary:
	var candidates: Array = get_quests_by_mission_id(mission_id)
	if candidates.is_empty():
		return {}
	var role := "finish_npc" if for_finish else "begin_npc"
	for quest in candidates:
		var npc_ref: Variant = quest.get(role, null)
		if npc_ref is Dictionary and str(npc_ref.get("parse_status", "")) == "parsed":
			var result: Dictionary = npc_ref.duplicate(true)
			result["mission_id"] = mission_id
			result["source_section"] = str(quest.get("source_section", ""))
			result["quest_name_ar"] = str(quest.get("name_ar", ""))
			result["quest_name_en"] = str(quest.get("name", ""))
			return result
	return {}

func get_dialogue_source_status() -> Array:
	return _index.get("dialogue_sources", []).duplicate(true)

func get_npc_dialogue(dialogue_id: int) -> Dictionary:
	return _npc_dialogues_by_id.get(dialogue_id, {}).duplicate(true)

func get_npc_dialogues_for_model_id(model_id: int) -> Array:
	return _npc_dialogues_by_model_id.get(model_id, []).duplicate(true)

func get_npc_dialogue_for_model_id(model_id: int) -> Dictionary:
	var candidates: Array = _npc_dialogues_by_model_id.get(model_id, [])
	if candidates.size() == 1:
		return candidates[0].duplicate(true)
	return {}

func get_npc_dialogue_ids_for_model_id(model_id: int) -> Array[int]:
	var result: Array[int] = []
	for entry in _npc_dialogues_by_model_id.get(model_id, []):
		var dialogue_id := int(entry.get("dialogue_id", -1))
		if dialogue_id > 0:
			result.append(dialogue_id)
	return result

func get_dialogue_text(text_key: String, locale: String = "ar") -> String:
	var localized: Dictionary = _index.get("dialogue_texts", {})
	var selected: Dictionary = localized.get(locale, {})
	var value: Variant = selected.get(text_key, null)
	if value == null:
		var fallback_locale := "en" if locale != "en" else "ar"
		selected = localized.get(fallback_locale, {})
		value = selected.get(text_key, "")
	return str(value)

func get_script_dialogue_text(text_key: String, locale: String = "ar") -> String:
	var localized: Dictionary = _index.get("script_dialogue_texts", {})
	var selected: Dictionary = localized.get(locale, {})
	var value: Variant = selected.get(text_key, null)
	if value == null:
		var fallback_locale := "en" if locale != "en" else "ar"
		selected = localized.get(fallback_locale, {})
		value = selected.get(text_key, "")
	return str(value)


func get_class_selection_source(locale: String = "en") -> Array:
	var selection: Dictionary = _index.get("class_selection", {})
	return selection.get(locale, []).duplicate(true)
