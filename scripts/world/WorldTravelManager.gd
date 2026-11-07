extends Node
class_name WorldTravelManager

signal travel_started(destination_id: String)
signal travel_completed(destination_id: String, world_position: Vector3)

const DESTINATIONS := {
	"twin_city": {"name_ar":"مدينة التوأم","name_en":"Twin City","source_map_id":"1002","position":Vector3(0.0,0.15,0.0),"description_ar":"المدينة الرئيسية ومركز التجار والخدمات","description_en":"Main city, merchants and services"},
	"twin_plains": {"name_ar":"سهول التوأم","name_en":"Twin Plains","position":Vector3(20.0,0.15,16.0),"description_ar":"موطن الذئاب البرية ومهام التدريب","description_en":"Wild wolf grounds and training quests"},
	"desert_ruins": {"name_ar":"أطلال الصحراء","name_en":"Desert Ruins","position":Vector3(-35.0,0.15,30.0),"description_ar":"أطلال قديمة ومناطق استكشاف","description_en":"Ancient ruins and exploration"},
	"mountain_summit": {"name_ar":"قمة الجبل","name_en":"Mountain Summit","position":Vector3(38.0,0.15,-35.0),"description_ar":"ساحة تنين اللهب وزعماء الجبال","description_en":"Flame Dragon and mountain bosses"},
	"western_forest": {"name_ar":"الغابة الغربية","name_en":"Western Forest","position":Vector3(-42.0,0.15,-20.0),"description_ar":"غابة الوحوش والموارد النادرة","description_en":"Monster forest and rare resources"},
	"dragon_isle": {"name_ar":"جزيرة التنين","name_en":"Dragon Isle","position":Vector3(62.0,0.15,52.0),"description_ar":"منطقة تحديات التنين","description_en":"Dragon challenge region"},
	"market_district": {"name_ar":"سوق القوافل","name_en":"Caravan Market","position":Vector3(0.0,0.15,-25.0),"description_ar":"سوق المدينة ومركز التجارة","description_en":"City market and trade hub"}
}

var current_destination_id := "twin_city"
var current_source_map_id := "1002"
var travel_in_progress := false
var travel_serial := 0
var source_quest_graph := QuestRuntimeGraph.new()
var current_source_map_id := "1002"

func _ready() -> void:
	add_to_group("world_travel_manager")
	source_quest_graph.load_graph()

func get_source_city_hubs() -> Array[Dictionary]:
	return source_quest_graph.get_city_hubs()

func get_source_city_runtime_state(map_id: String) -> Dictionary:
	var hub := source_quest_graph.get_city_hub(map_id)
	if hub.is_empty():
		return {}
	var scene_path := "res://scenes/cities/City_%s.tscn" % map_id
	var scene_available := ResourceLoader.exists(scene_path)
	var is_main_city := map_id == "1002"
	return {
		"map_id": map_id,
		"name_ar": str(hub.get("name_ar", "")),
		"name_en": str(hub.get("name_en", "")),
		"kind": str(hub.get("kind", "minor")),
		"resource_path": str(hub.get("resource_path", "")),
		"scene_path": scene_path,
		"scene_available": scene_available,
		"available": is_main_city or scene_available,
		"status": "MAIN_CITY_ACTIVE" if is_main_city else ("CITY_SCENE_READY" if scene_available else "CITY_SOURCE_INDEXED_SCENE_PENDING"),
	}

func get_destinations() -> Dictionary:
	var result := DESTINATIONS.duplicate(true)
	for hub in source_quest_graph.get_city_hubs():
		var map_id := str(hub.get("map_id", ""))
		var state := get_source_city_runtime_state(map_id)
		if map_id.is_empty() or state.is_empty():
			continue
		var destination_id := "city_" + map_id
		result[destination_id] = {
			"name_ar": str(hub.get("name_ar", "")),
			"name_en": str(hub.get("name_en", "")),
			"description_ar": "المدينة الرئيسية" if map_id == "1002" else ("خريطة المدينة مرتبطة بالمصدر؛ مشهدها ثلاثي الأبعاد قيد الدمج" if not bool(state.get("available", false)) else "مدينة مرتبطة بمشهدها"),
			"description_en": "Main city" if map_id == "1002" else ("Source city indexed; 3D scene integration pending" if not bool(state.get("available", false)) else "City scene available"),
			"source_map_id": map_id,
			"enabled": bool(state.get("available", false)),
			"status": str(state.get("status", "")),
		}
	return result

func get_source_city_hubs() -> Array[Dictionary]:
	var graph := QuestRuntimeGraph.new()
	if not graph.load_graph():
		return []
	return graph.get_city_hubs()

func get_source_map_directory_entry(map_id: String) -> Dictionary:
	var graph := QuestRuntimeGraph.new()
	if not graph.load_graph():
		return {}
	return graph.get_map_directory_entry(map_id)

func get_source_mission_route(mission_id: String, turn_in: bool = false) -> Dictionary:
	var graph := QuestRuntimeGraph.new()
	if not graph.load_graph():
		return {}
	return graph.get_route(mission_id, turn_in)

func navigate_to_source_route(route: Dictionary) -> bool:
	var map_id := str(route.get("map_id", ""))
	var npc_id := str(route.get("npc_id", ""))
	if map_id.is_empty() or npc_id.is_empty():
		_notify("بيانات موقع المهمة غير مكتملة" if GameManager.current_language == "ar" else "Quest route is missing its map or NPC ID.", true)
		return false
	if map_id != current_source_map_id or current_destination_id != "twin_city":
		_notify("خريطة المهمة غير محمّلة حاليًا؛ لن ننقل اللاعب إلى إحداثيات غير مؤكدة." if GameManager.current_language == "ar" else "The quest map is not loaded; refusing to navigate to unverified coordinates.", true)
		return false
	var matched_npc: Node3D = null
	for candidate in get_tree().get_nodes_in_group("npcs"):
		if not candidate is Node3D:
			continue
		var candidate_id := str(candidate.get("source_npc_id")).lstrip("0")
		var candidate_map := str(candidate.get("source_map_id"))
		if candidate_id == npc_id.lstrip("0") and candidate_map == map_id:
			matched_npc = candidate as Node3D
			break
	if matched_npc == null:
		_notify("صاحب المهمة غير موجود في مشهد المدينة المحمّل." if GameManager.current_language == "ar" else "The quest NPC is not present in the loaded city scene.", true)
		return false
	var game_manager := _get_game_manager()
	if game_manager == null or not is_instance_valid(game_manager.get("player_reference")):
		return false
	var player: Node = game_manager.get("player_reference")
	if player.has_method("move_towards_target_position"):
		player.call("move_towards_target_position", matched_npc.global_position, 0.0)
		_notify("جارٍ التوجه إلى %s" % str(route.get("npc_name", npc_id)), false)
		return true
	return false

func get_current_destination_id() -> String:
	return current_destination_id

func get_current_source_map_id() -> String:
	return current_source_map_id

func travel_to(destination_id: String, reason: String = "manual") -> bool:
	if destination_id.begins_with("city_"):
		var source_map_id := destination_id.trim_prefix("city_")
		if source_map_id == "1002":
			return travel_to("twin_city", reason)
		var city_state := get_source_city_runtime_state(source_map_id)
		if city_state.is_empty() or not bool(city_state.get("available", false)):
			_notify("هذه المدينة موجودة في سجل العالم، لكن مشهدها ثلاثي الأبعاد لم يُدمج بعد." if GameManager.current_language == "ar" else "This city is indexed in the world source, but its 3D scene is not integrated yet.", true)
			return false
		_notify("مشهد المدينة يحتاج إلى مهيئ الانتقال الخاص به." if GameManager.current_language == "ar" else "This city requires its dedicated scene transition handler.", true)
		return false
	if travel_in_progress:
		return false
	var game_manager := _get_game_manager()
	if game_manager == null:
		push_error("WorldTravelManager requires /root/GameManager.")
		return false
	if not DESTINATIONS.has(destination_id):
		_notify("وجهة الانتقال غير معروفة" if str(game_manager.get("current_language")) == "ar" else "Unknown travel destination", true)
		return false
	if not is_instance_valid(game_manager.get("player_reference")):
		_notify("لا يوجد بطل مسجل للانتقال" if str(game_manager.get("current_language")) == "ar" else "No active hero to travel", true)
		return false
	if destination_id == current_destination_id and reason != "respawn":
		_notify("أنت موجود بالفعل في هذه المنطقة" if str(game_manager.get("current_language")) == "ar" else "You are already in this area", false)
		return true

	travel_in_progress = true
	travel_serial += 1
	emit_signal("travel_started", destination_id)
	var player: Node3D = game_manager.get("player_reference") as Node3D
	var destination: Dictionary = DESTINATIONS[destination_id]
	var target: Vector3 = destination.position
	current_source_map_id = str(destination.get("source_map_id", ""))
	if player is CharacterBody3D:
		player.velocity = Vector3.ZERO
	if player.has_method("set_joystick_input"):
		player.set_joystick_input(Vector2.ZERO)
	if player.has_method("clear_movement_target"):
		player.clear_movement_target()
	player.global_position = target
	current_destination_id = destination_id
	if destination_id == "twin_city":
		current_source_map_id = "1002"
	if GameAudioManager:
		GameAudioManager.play_map_music(destination_id)
	travel_in_progress = false
	emit_signal("travel_completed", destination_id, target)
	var label := str(destination.name_ar) if str(game_manager.get("current_language")) == "ar" else str(destination.name_en)
	var message := "تم الانتقال اللحظي إلى %s" % label if str(game_manager.get("current_language")) == "ar" else "Instant travel to %s complete" % label
	if reason == "quest":
		message = "انتقلت مباشرة إلى موقع المهمة: %s" % label if str(game_manager.get("current_language")) == "ar" else "Instantly travelled to quest location: %s" % label
	_notify(message, false)
	return true

func _get_game_manager() -> Node:
	return get_node_or_null("/root/GameManager")

func _notify(message: String, alert: bool) -> void:
	var game_manager := _get_game_manager()
	if game_manager != null:
		game_manager.call("post_notification", message, alert)
