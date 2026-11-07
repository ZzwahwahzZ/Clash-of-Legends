extends RefCounted
class_name QuestSourceCatalog
## Reads the imported Mobile 1.1.2.3 source catalog without promoting
## partially verified source fields into runtime truth.

const CATALOG_PATH := "res://data/quests/mobile_quest_catalog.json"

var status := "NOT_LOADED"
var source_version := ""
var missions_by_id: Dictionary = {}
var map_records_by_id: Dictionary = {}
var source_policy := ""

func load_catalog(path: String = CATALOG_PATH) -> bool:
	status = "NOT_LOADED"
	missions_by_id.clear()
	map_records_by_id.clear()
	if not FileAccess.file_exists(path):
		status = "CATALOG_MISSING"
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		status = "CATALOG_UNREADABLE"
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		status = "INVALID_JSON"
		return false
	var root: Dictionary = parsed
	if str(root.get("source_version", "")) != "Conquer Online Mobile 1.1.2.3":
		status = "SOURCE_VERSION_MISMATCH"
		return false
	for row in root.get("missions", []):
		if not row is Dictionary:
			continue
		var mission_id := str(row.get("id", ""))
		if mission_id.is_empty() or missions_by_id.has(mission_id):
			status = "DUPLICATE_OR_EMPTY_MISSION_ID"
			missions_by_id.clear()
			return false
		missions_by_id[mission_id] = row
	for row in root.get("maps", []):
		if not row is Dictionary:
			continue
		var map_id := str(row.get("map_id", ""))
		if not map_id.is_empty():
			map_records_by_id[map_id] = row
	source_version = str(root.get("source_version", ""))
	source_policy = str(root.get("policy", ""))
	status = str(root.get("status", "SOURCE_CATALOG_LOADED"))
	return not missions_by_id.is_empty()

func get_mission(mission_id: String) -> Dictionary:
	return (missions_by_id.get(mission_id, {}) as Dictionary).duplicate(true)

func get_missions_for_npc(npc_id: String, role: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mission_id in missions_by_id:
		var row: Dictionary = missions_by_id[mission_id]
		for endpoint in ["begin_npc", "finish_npc"]:
			if not role.is_empty() and endpoint != role:
				continue
			var npc: Dictionary = row.get(endpoint, {})
			if str(npc.get("npc_id", "")).lstrip("0") == npc_id.lstrip("0") and npc_id != "0":
				result.append(row.duplicate(true))
				break
	return result

func get_missions_for_map(map_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mission_id in missions_by_id:
		var row: Dictionary = missions_by_id[mission_id]
		var found := str(row.get("map_field_raw", "0")) == map_id
		for endpoint in ["begin_npc", "finish_npc"]:
			if str(row.get(endpoint, {}).get("map_id", "")) == map_id:
				found = true
		if not found:
			for intention in row.get("intentions", []):
				if str(intention.get("map_id", "")) == map_id:
					found = true
					break
		if found:
			result.append(row.duplicate(true))
	return result

func get_map(map_id: String) -> Dictionary:
	return (map_records_by_id.get(map_id, {}) as Dictionary).duplicate(true)

func get_counts() -> Dictionary:
	return {"missions": missions_by_id.size(), "maps": map_records_by_id.size(), "status": status}
