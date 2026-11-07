extends Node
class_name WorldTravelManager

signal travel_started(destination_id: String)
signal travel_completed(destination_id: String, world_position: Vector3)

const DESTINATIONS := {
	"twin_city": {"name_ar":"مدينة التوأم","name_en":"Twin City","position":Vector3(0.0,0.15,0.0),"description_ar":"المدينة الرئيسية ومركز التجار والخدمات","description_en":"Main city, merchants and services"},
	"twin_plains": {"name_ar":"سهول التوأم","name_en":"Twin Plains","position":Vector3(20.0,0.15,16.0),"description_ar":"موطن الذئاب البرية ومهام التدريب","description_en":"Wild wolf grounds and training quests"},
	"desert_ruins": {"name_ar":"أطلال الصحراء","name_en":"Desert Ruins","position":Vector3(-35.0,0.15,30.0),"description_ar":"أطلال قديمة ومناطق استكشاف","description_en":"Ancient ruins and exploration"},
	"mountain_summit": {"name_ar":"قمة الجبل","name_en":"Mountain Summit","position":Vector3(38.0,0.15,-35.0),"description_ar":"ساحة تنين اللهب وزعماء الجبال","description_en":"Flame Dragon and mountain bosses"},
	"western_forest": {"name_ar":"الغابة الغربية","name_en":"Western Forest","position":Vector3(-42.0,0.15,-20.0),"description_ar":"غابة الوحوش والموارد النادرة","description_en":"Monster forest and rare resources"},
	"dragon_isle": {"name_ar":"جزيرة التنين","name_en":"Dragon Isle","position":Vector3(62.0,0.15,52.0),"description_ar":"منطقة تحديات التنين","description_en":"Dragon challenge region"},
	"market_district": {"name_ar":"سوق القوافل","name_en":"Caravan Market","position":Vector3(0.0,0.15,-25.0),"description_ar":"سوق المدينة ومركز التجارة","description_en":"City market and trade hub"}
}

var current_destination_id := "twin_city"
var travel_in_progress := false
var travel_serial := 0

func _ready() -> void:
	add_to_group("world_travel_manager")

func get_destinations() -> Dictionary:
	return DESTINATIONS.duplicate(true)

func get_current_destination_id() -> String:
	return current_destination_id

func travel_to(destination_id: String, reason: String = "manual") -> bool:
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
	if player is CharacterBody3D:
		player.velocity = Vector3.ZERO
	if player.has_method("set_joystick_input"):
		player.set_joystick_input(Vector2.ZERO)
	if player.has_method("clear_movement_target"):
		player.clear_movement_target()
	player.global_position = target
	current_destination_id = destination_id
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


## Exact-version source-map catalog access. This is metadata resolution only:
## it does not pretend a source map archive is already a playable Godot scene.
func get_source_map_catalog() -> Array:
	if not WorldContentIndex or not WorldContentIndex.index_ready:
		return []
	return WorldContentIndex.get_maps()

func get_source_map_by_id(map_id: int) -> Dictionary:
	if not WorldContentIndex or not WorldContentIndex.index_ready:
		return {}
	return WorldContentIndex.get_map_by_id(map_id)

func get_source_map_archive(map_id: int) -> Dictionary:
	if not WorldContentIndex or not WorldContentIndex.index_ready:
		return {}
	return WorldContentIndex.get_source_map_archive(map_id)

func get_source_map_archive_catalog() -> Array:
	if not WorldContentIndex or not WorldContentIndex.index_ready:
		return []
	return WorldContentIndex.get_source_map_archives()

func get_source_map_for_quest(mission_id: int, for_finish: bool = false) -> Dictionary:
	if not WorldContentIndex or not WorldContentIndex.index_ready:
		return {}
	var npc_target: Dictionary = WorldContentIndex.get_quest_npc_target(mission_id, for_finish)
	if npc_target.is_empty():
		return {}
	var map_id := int(npc_target.get("map_id", -1))
	var map_data := WorldContentIndex.get_map_by_id(map_id)
	return {
		"map_id": map_id,
		"map": map_data,
		"npc_target": npc_target,
		"source_map_available": not map_data.is_empty() and not bool(map_data.get("metadata_only", false)),
		"map_metadata_available": not map_data.is_empty(),
		"world_transform_status": "NOT_VALIDATED"
	}
