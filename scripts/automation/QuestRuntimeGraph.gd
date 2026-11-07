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
var dependents: Dictionary = {}
var npc_starts: Dictionary = {}
var npc_turnins: Dictionary = {}
var map_missions: Dictionary = {}
var city_hubs: Array[Dictionary] = []
var source_version := ""

func load_graph(path: String = DEFAULT_CATALOG) -> bool:
	status = "NOT_LOADED"
	missions.clear()
	maps.clear()
	map_names.clear()
	dependents.clear()
	npc_starts.clear()
	npc_turnins.clear()
	map_missions.clear()
	city_hubs.clear()
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
	for row in root.get("city_hubs", []):
		if row is Dictionary:
			city_hubs.append(row)
	for id in missions:
		var mission: Dictionary = missions[id]
		for prerequisite in mission.get("prerequisites", []):
			var parent := str(prerequisite)
			dependents.setdefault(parent, [])
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
	index.setdefault(key, [])
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
	if not profession_code.is_empty() and raw != "0":
		var allowed := false
		for token in raw.split(","):
			if token.strip_edges() == profession_code:
				allowed = true
				break
		if not allowed:
			return false
	return true

func get_available_at_npc(npc_id: String, completed_ids: Array = [], player_level: int = 0, profession_code: String = "") -> Array[Dictionary]:
	var key := npc_id.lstrip("0")
	var result: Array[Dictionary] = []
	for id in npc_starts.get(key, []):
		if is_available(str(id), completed_ids, player_level, profession_code):
			result.append(get_mission(str(id)))
	for id in npc_turnins.get(key, []):
		var mission := get_mission(str(id))
		if not result.any(func(row: Dictionary) -> bool: return str(row.get("id", "")) == str(id)):
			result.append(mission)
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
		"map_resource": str(maps.get(map_id, {}).get("resource_path", "")),
		"source_x": endpoint.get("x"),
		"source_y": endpoint.get("y"),
		"npc_name": str(endpoint.get("npc_name", "")),
		"status": "SOURCE_ENDPOINT_PARSED_CANDIDATE" if status_value == "PARSED" else "SOURCE_ENDPOINT_UNRESOLVED",
		"runtime_transform_verified": false,
	}

func get_world_summary() -> Dictionary:
	return {
		"missions": missions.size(),
		"map_ids": maps.size(),
		"map_names": map_names.size(),
		"city_hubs": city_hubs.duplicate(true),
		"npc_start_ids": npc_starts.size(),
		"npc_turnin_ids": npc_turnins.size(),
		"dependency_edges": _count_edges(),
		"status": status,
	}

func _count_edges() -> int:
	var total := 0
	for parent in dependents:
		total += dependents[parent].size()
	return total
