extends RefCounted
class_name QuestRuntimeGraph
## Source-backed quest dependency and world-link graph.
## The graph exposes raw source semantics and refuses to invent a class-code
## mapping, dialogue join, reward interpretation or map transform.

const DEFAULT_CATALOG := "res://data/quests/mobile_quest_catalog.json"

var status := "NOT_LOADED"
var missions: Dictionary = {}
var maps: Dictionary = {}
var map_names: Dictionary = {}
var map_directory: Array[Dictionary] = []
var map_directory: Dictionary = {}
var dependents: Dictionary = {}
var npc_starts: Dictionary = {}
var npc_turnins: Dictionary = {}
var map_missions: Dictionary = {}
var city_hubs: Array[Dictionary] = []
var npc_placements: Array[Dictionary] = []
var dialogue_links: Array[Dictionary] = []
var source_version := ""

func load_graph(path: String = DEFAULT_CATALOG) -> bool:
	status = "NOT_LOADED"
	missions.clear()
	maps.clear()
	map_names.clear()
	map_directory.clear()
	map_directory.clear()
	dependents.clear()
	npc_starts.clear()
	npc_turnins.clear()
	map_missions.clear()
	city_hubs.clear()
	npc_placements.clear()
	dialogue_links.clear()
	if not FileAccess.file_exists(path):
		status = "CATALOG_MISSING"
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		status = "CATALOG_UNREADABLE"
		return false
	var root: Variant = JSON.parse_string(file.get_as_text())
	if not root is Dictionary:
		status = "INVALID_JSON"
		return false
	if str(root.get("source_version", "")) != "Conquer Online Mobile 1.1.2.3":
		status = "SOURCE_VERSION_MISMATCH"
		return false
	source_version = str(root.get("source_version", ""))
	for row in root.get("missions", []):
		if not row is Dictionary:
			continue
		var id := str(row.get("id", ""))
		if id.is_empty() or missions.has(id):
			status = "DUPLICATE_OR_EMPTY_MISSION_ID"
			missions.clear()
			return false
		missions[id] = row
	for row in root.get("maps", []):
		if row is Dictionary:
			var map_id := str(row.get("map_id", ""))
			if not map_id.is_empty():
				maps[map_id] = row
	for row in root.get("map_names", []):
		if row is Dictionary:
			var map_id := str(row.get("map_id", ""))
			if not map_id.is_empty():
				map_names[map_id] = row
	for row in root.get("map_directory", []):
		if row is Dictionary:
			map_directory.append(row)
	for row in root.get("map_directory", []):
		if row is Dictionary:
			var map_id := str(row.get("map_id", ""))
			if not map_id.is_empty():
				map_directory[map_id] = row
	for row in root.get("city_hubs", []):
		if row is Dictionary:
			city_hubs.append(row)
	for row in root.get("npc_placements", []):
		if row is Dictionary:
			npc_placements.append(row)
	for row in root.get("dialogue_links", []):
		if row is Dictionary:
			dialogue_links.append(row)
	for id in missions:
		var mission: Dictionary = missions[id]
		for prerequisite in mission.get("prerequisites", []):
			var parent := str(prerequisite)
			if not dependents.has(parent):
				dependents[parent] = []
			if not dependents[parent].has(id):
				dependents[parent].append(id)
		_index_npc(npc_starts, mission.get("begin_npc", {}), id)
		_index_npc(npc_turnins, mission.get("finish_npc", {}), id)
		_index_map(mission.get("begin_npc", {}), id)
		_index_map(mission.get("finish_npc", {}), id)
		for intention in mission.get("intentions", []):
			if intention is Dictionary:
				var map_id := str(intention.get("map_id", ""))
				if not map_id.is_empty():
					_index_value(map_missions, map_id, id)
	status = "SOURCE_GRAPH_READY_CANDIDATE"
	return not missions.is_empty()

func _index_npc(index: Dictionary, endpoint: Dictionary, mission_id: String) -> void:
	var npc_id := str(endpoint.get("npc_id", "")).lstrip("0")
	if npc_id.is_empty() or npc_id == "0":
		return
	_index_value(index, npc_id, mission_id)

func _index_map(endpoint: Dictionary, mission_id: String) -> void:
	var map_id := str(endpoint.get("map_id", ""))
	if not map_id.is_empty() and map_id != "0":
		_index_value(map_missions, map_id, mission_id)

func _index_value(index: Dictionary, key: String, mission_id: String) -> void:
	if not index.has(key):
		index[key] = []
	if not index[key].has(mission_id):
		index[key].append(mission_id)

func get_mission(mission_id: String) -> Dictionary:
	return (missions.get(mission_id, {}) as Dictionary).duplicate(true)

func get_prerequisites(mission_id: String) -> Array[String]:
	var result: Array[String] = []
	for value in missions.get(mission_id, {}).get("prerequisites", []):
		result.append(str(value))
	return result

func get_dependents(mission_id: String) -> Array[String]:
	var result: Array[String] = []
	for value in dependents.get(mission_id, []):
		result.append(str(value))
	return result

func is_available(mission_id: String, completed_ids: Array, player_level: int = 0, profession_code: String = "") -> bool:
	if not missions.has(mission_id):
		return false
	var mission: Dictionary = missions[mission_id]
	for prerequisite in mission.get("prerequisites", []):
		if not completed_ids.has(str(prerequisite)):
			return false
	var level_min := int(mission.get("level_min", 0) if mission.get("level_min") != null else 0)
	var level_max := int(mission.get("level_max", 0) if mission.get("level_max") != null else 0)
	if player_level > 0 and ((level_min > 0 and player_level < level_min) or (level_max > 0 and player_level > level_max)):
		return false
	var raw := str(mission.get("profession_raw", "0")).strip_edges()
	if raw != "0":
		if profession_code.is_empty():
			return false
		var allowed := false
		for token in raw.split(","):
			if token.strip_edges() == profession_code:
				allowed = true
				break
		if not allowed:
			return false
	return true

func is_available_for_class(mission_id: String, completed_ids: Array, player_level: int, class_id: String) -> bool:
	var profession_code: String = GameContentDatabase.get_source_profession_id(class_id) if GameContentDatabase != null else ""
	return is_available(mission_id, completed_ids, player_level, profession_code)

func get_available_at_npc_for_class(npc_id: String, completed_ids: Array, player_level: int, class_id: String, map_id: String = "") -> Array[Dictionary]:
	var profession_code: String = GameContentDatabase.get_source_profession_id(class_id) if GameContentDatabase != null else ""
	return get_available_at_npc(npc_id, completed_ids, player_level, profession_code, map_id)

func get_available_at_npc(npc_id: String, completed_ids: Array = [], player_level: int = 0, profession_code: String = "", map_id: String = "") -> Array[Dictionary]:
	# Only start-NPC offers are returned here. Turn-ins must be checked against
	# the player's active mission by QuestNavigationAgent.
	var key := npc_id.lstrip("0")
	var result: Array[Dictionary] = []
	for id in npc_starts.get(key, []):
		var mission: Dictionary = missions.get(str(id), {})
		var endpoint: Dictionary = mission.get("begin_npc", {})
		if not map_id.is_empty() and str(endpoint.get("map_id", "")) != map_id:
			continue
		if is_available(str(id), completed_ids, player_level, profession_code):
			result.append(get_mission(str(id)))
	return result

func is_turnin_npc(mission_id: String, npc_id: String, map_id: String = "") -> bool:
	if not missions.has(mission_id):
		return false
	var endpoint: Dictionary = missions[mission_id].get("finish_npc", {})
	var same_npc := str(endpoint.get("npc_id", "")).lstrip("0") == npc_id.lstrip("0") and npc_id.lstrip("0") != "0"
	var same_map := map_id.is_empty() or str(endpoint.get("map_id", "")) == map_id
	return same_npc and same_map

func get_city_hubs() -> Array[Dictionary]:
	return city_hubs.duplicate(true)

func get_city_hub(map_id: String) -> Dictionary:
	for hub in city_hubs:
		if str(hub.get("map_id", "")) == map_id:
			return hub.duplicate(true)
	return {}

func get_map_directory_entry(map_id: String) -> Dictionary:
	for row in map_directory:
		if str(row.get("map_id", "")) == map_id:
			return row.duplicate(true)
	return {}

func get_dialogues_for_npc(npc_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for link in dialogue_links:
		if not link is Dictionary:
			continue
		for match_row in link.get("source_npc_matches", []):
			if str(match_row.get("npc_id", "")).lstrip("0") == npc_id.lstrip("0"):
				result.append(link.duplicate(true))
				break
	return result

func get_objective_routes(mission_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var mission := get_mission(mission_id)
	if mission.is_empty():
		return result
	for index in range(mission.get("intentions", []).size()):
		var intention: Dictionary = mission.get("intentions", [])[index]
		result.append({
			"index": index,
			"kind": str(intention.get("kind", "")),
			"npc_id": str(intention.get("npc_id", "")),
			"npc_name": str(intention.get("npc_name", "")),
			"monster_name": str(intention.get("monster_name", "")),
			"item_name": str(intention.get("item_name", "")),
			"item_id": str(intention.get("item_id", "")),
			"map_id": str(intention.get("map_id", "")),
			"x": intention.get("x"),
			"y": intention.get("y"),
			"target_resolution": str(intention.get("target_resolution", "")),
			"field": str(intention.get("field", "")),
		})
	return result

func get_route(mission_id: String, turn_in: bool = false) -> Dictionary:
	var mission := get_mission(mission_id)
	if mission.is_empty():
		return {}
	var endpoint: Dictionary = mission.get("finish_npc", {}) if turn_in else mission.get("begin_npc", {})
	var role := "finish_npc" if turn_in else "begin_npc"
	var status_value := str(endpoint.get("status", "MISSING"))
	var map_id := str(endpoint.get("map_id", ""))
	var npc_id := str(endpoint.get("npc_id", ""))
	var map_name := str(endpoint.get("map_name", ""))
	return {
		"mission_id": mission_id,
		"role": role,
		"npc_id": npc_id,
		"map_id": map_id,
		"map_name": map_name,
		"map_resource": str(get_map_directory_entry(map_id).get("resource_path", "")),
		"source_x": endpoint.get("x"),
		"source_y": endpoint.get("y"),
		"npc_name": str(endpoint.get("npc_name", "")),
		"status": "SOURCE_ENDPOINT_PARSED_CANDIDATE" if status_value == "PARSED" else "SOURCE_ENDPOINT_UNRESOLVED",
		"runtime_transform_verified": false,
	}

func get_map_directory_entry(map_id: String) -> Dictionary:
	return (map_directory.get(map_id, {}) as Dictionary).duplicate(true)

func get_city_hubs() -> Array[Dictionary]:
	return city_hubs.duplicate(true)

func get_npc_placements(npc_id: String, map_id: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row in npc_placements:
		if str(row.get("npc_id", "")).lstrip("0") != npc_id.lstrip("0"):
			continue
		if not map_id.is_empty() and str(row.get("map_id", "")) != map_id:
			continue
		result.append(row.duplicate(true))
	return result

func get_dialogue_links(mission_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row in dialogue_links:
		if str(row.get("mission_id", "")) == mission_id:
			result.append(row.duplicate(true))
	return result

func get_objective_coverage() -> Dictionary:
	var kind_counts: Dictionary = {}
	var supported_candidate_count := 0
	var total_count := 0
	for mission_id in missions:
		var mission: Dictionary = missions[mission_id]
		for intention in mission.get("intentions", []):
			if not intention is Dictionary:
				continue
			total_count += 1
			var kind := str(intention.get("kind", "unknown"))
			kind_counts[kind] = int(kind_counts.get(kind, 0)) + 1
			var supported := false
			match kind:
				"npc":
				supported = not str(intention.get("npc_id", "")).is_empty()
				"mob":
				supported = not str(intention.get("monster_name", "")).is_empty()
				"item_t":
				supported = not str(intention.get("item_name", "")).is_empty()
				"chk_item":
				supported = not intention.get("parts", []).is_empty()
				"map":
				supported = not str(intention.get("map_id", "")).is_empty()
			if supported:
				supported_candidate_count += 1
	return {
		"total_intentions": total_count,
		"supported_candidate_intentions": supported_candidate_count,
		"unsupported_or_unresolved_intentions": total_count - supported_candidate_count,
		"kind_counts": kind_counts,
		"status": "PARTIAL_OBJECTIVE_INTERPRETATION_LUA_AND_QUEST_COUNTER_SEMANTICS_PENDING",
	}

func get_world_summary() -> Dictionary:
	return {
		"missions": missions.size(),
		"map_ids": maps.size(),
		"map_names": map_names.size(),
		"map_directory": map_directory.size(),
		"city_hubs": city_hubs.duplicate(true),
		"npc_start_ids": npc_starts.size(),
		"npc_turnin_ids": npc_turnins.size(),
		"npc_placements": npc_placements.size(),
		"dialogue_links": dialogue_links.size(),
		"dependency_edges": _count_edges(),
		"objective_coverage": get_objective_coverage(),
		"status": status,
	}

func _count_edges() -> int:
	var total := 0
	for parent in dependents:
		total += dependents[parent].size()
	return total
