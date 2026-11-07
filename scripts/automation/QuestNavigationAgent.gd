extends Node
class_name QuestNavigationAgent

signal quest_state_changed(quest_id: String, state: String)
signal quest_started(quest_id: String)

const DEFAULT_QUEST_ID := "quest_wolves"

var active_quest_id: String = DEFAULT_QUEST_ID
var quest_progress: int = 0
var is_quest_completed: bool = false
var completed_quest_ids: Array[String] = []
var source_catalog := QuestSourceCatalog.new()
var source_graph := QuestRuntimeGraph.new()
var active_source_mission_id := ""
var completed_source_mission_ids: Array[String] = []
var source_objective_progress: Dictionary = {}
var source_objective_counts: Dictionary = {}
var source_ready_to_turn_in_ids: Array[String] = []

func get_source_catalog_status() -> Dictionary:
	return source_catalog.get_counts()

func get_source_graph_summary() -> Dictionary:
	return source_graph.get_world_summary()

func get_source_missions_available_at_npc(npc_id: String, player_level: int = 0, profession_code: String = "") -> Array[Dictionary]:
	return source_graph.get_available_at_npc(npc_id, completed_source_mission_ids, player_level, profession_code)

func get_source_missions_available_for_class(npc_id: String, player_level: int, class_id: String, map_id: String = "") -> Array[Dictionary]:
	return source_graph.get_available_at_npc_for_class(npc_id, completed_source_mission_ids, player_level, class_id, map_id)

func get_source_missions_for_npc_interaction(npc_id: String, player_level: int, class_id: String, map_id: String = "") -> Array[Dictionary]:
	var result := source_graph.get_available_at_npc_for_class(npc_id, completed_source_mission_ids, player_level, class_id, map_id)
	if not active_source_mission_id.is_empty() and source_graph.is_turnin_npc(active_source_mission_id, npc_id, map_id):
		var active := source_graph.get_mission(active_source_mission_id)
		if not active.is_empty():
			active["runtime_state"] = "READY_TO_TURN_IN" if source_ready_to_turn_in_ids.has(active_source_mission_id) else "ACTIVE_OBJECTIVES"
			result.push_front(active)
	return result

func get_source_active_state() -> Dictionary:
	if active_source_mission_id.is_empty():
		return {}
	return {
		"mission_id": active_source_mission_id,
		"ready_to_turn_in": source_ready_to_turn_in_ids.has(active_source_mission_id),
		"objective_progress": source_objective_progress.get(active_source_mission_id, []).duplicate(true),
	}

func get_source_mission_route(mission_id: String, turn_in: bool = false) -> Dictionary:
	return source_graph.get_route(mission_id, turn_in)

func activate_source_mission(mission_id: String, player_level: int, profession_code: String = "") -> bool:
	if not active_source_mission_id.is_empty() or not source_graph.is_available(mission_id, completed_source_mission_ids, player_level, profession_code):
		return false
	var mission := source_graph.get_mission(mission_id)
	if mission.is_empty():
		return false
	active_source_mission_id = mission_id
	source_objective_progress[mission_id] = []
	for _intention in mission.get("intentions", []):
		source_objective_progress[mission_id].append(false)
	source_ready_to_turn_in_ids.erase(mission_id)
	emit_signal("quest_state_changed", mission_id, "source_active_candidate")
	_notify_source_quest_state()
	return true

func select_source_mission_at_npc(mission_id: String, npc_id: String, player_level: int, class_id: String, map_id: String = "") -> bool:
	if mission_id == active_source_mission_id:
		if not source_ready_to_turn_in_ids.has(mission_id) or not source_graph.is_turnin_npc(mission_id, npc_id, map_id):
			return false
		return complete_source_mission_turnin(mission_id, npc_id, map_id)
	var mission := source_graph.get_mission(mission_id)
	if mission.is_empty():
		return false
	var begin_npc: Dictionary = mission.get("begin_npc", {})
	if str(begin_npc.get("npc_id", "")).lstrip("0") != npc_id.lstrip("0"):
		return false
	if not map_id.is_empty() and str(begin_npc.get("map_id", "")) != map_id:
		return false
	if not map_id.is_empty() and str(begin_npc.get("map_id", "")) != map_id:
		return false
	var profession_code := GameContentDatabase.get_source_profession_id(class_id) if GameContentDatabase else ""
	if not source_graph.is_available(mission_id, completed_source_mission_ids, player_level, profession_code):
		return false
	return activate_source_mission(mission_id, player_level, profession_code)

func on_source_npc_talked(npc_id: String, map_id: String = "") -> void:
	_advance_source_objectives("npc", npc_id, map_id, 1)

func on_source_enemy_killed(monster_name: String, map_id: String = "") -> void:
	_advance_source_objectives("mob", monster_name, map_id, 1)

func on_source_item_collected(item_id: String, item_name: String = "", map_id: String = "", quantity: int = 1) -> void:
	_advance_source_objectives("item", item_id if not item_id.is_empty() else item_name, map_id, maxi(1, quantity))

func on_source_map_entered(map_id: String) -> void:
	_advance_source_objectives("map", map_id, map_id, 1)

func _advance_source_objectives(event_kind: String, target: String, map_id: String, amount: int) -> void:
	if active_source_mission_id.is_empty() or amount <= 0:
		return
	var mission := source_graph.get_mission(active_source_mission_id)
	var intentions: Array = mission.get("intentions", [])
	var progress: Array = source_objective_progress.get(active_source_mission_id, [])
	if intentions.is_empty() or progress.size() != intentions.size():
		return
	for index in range(intentions.size()):
		if bool(progress[index]):
			continue
		var intention: Dictionary = intentions[index]
		var kind := str(intention.get("kind", ""))
		var matched := false
		var required := 1
		match kind:
			"npc":
				matched = event_kind == "npc" and str(intention.get("npc_id", "")).lstrip("0") == target.lstrip("0") and (map_id.is_empty() or str(intention.get("map_id", "")) == map_id)
				if matched and not map_id.is_empty() and not str(intention.get("map_id", "")).is_empty():
					matched = str(intention.get("map_id", "")) == map_id
			"mob":
				var expected_mob := str(intention.get("monster_name", "")).strip_edges()
				matched = event_kind == "mob" and not expected_mob.is_empty() and expected_mob.casefold() == target.casefold()
				if matched and not map_id.is_empty() and not str(intention.get("map_id", "")).is_empty():
					matched = str(intention.get("map_id", "")) == map_id
				if matched:
					for companion in intentions:
						if str(companion.get("kind", "")) == "chk_quest" and str(companion.get("quest_id", "")) == active_source_mission_id and str(companion.get("field", "")) == str(intention.get("field", "")):
							var condition_parts: Array = companion.get("parts", [])
							if not condition_parts.is_empty():
								required = maxi(required, int(condition_parts[condition_parts.size() - 1]))
			"item_t":
				var expected_item := str(intention.get("item_name", "")).strip_edges().to_lower().replace(" ", "").replace("_", "").replace("-", "")
				var actual_item := target.to_lower().replace(" ", "").replace("_", "").replace("-", "")
				matched = event_kind == "item" and not expected_item.is_empty() and expected_item == actual_item
			"chk_item":
				var parts: Array = intention.get("parts", [])
				if not parts.is_empty():
					matched = event_kind == "item" and str(parts[0]) == target
					if parts.size() > 1:
						required = maxi(1, int(parts[1]))
			"map":
				matched = event_kind == "map" and str(intention.get("map_id", "")) == map_id
			_:
				matched = false
		if matched:
			var counter_key := "%s:%d" % [active_source_mission_id, index]
			var count := int(source_objective_counts.get(counter_key, 0)) + amount
			source_objective_counts[counter_key] = count
			if count >= required:
				progress[index] = true
				if kind == "mob":
					for companion_index in range(intentions.size()):
						var companion: Dictionary = intentions[companion_index]
						if str(companion.get("kind", "")) == "chk_quest" and str(companion.get("quest_id", "")) == active_source_mission_id and str(companion.get("field", "")) == str(intention.get("field", "")):
							progress[companion_index] = true
	source_objective_progress[active_source_mission_id] = progress
	var all_complete := true
	for value in progress:
		if not bool(value):
			all_complete = false
			break
	if all_complete and not source_ready_to_turn_in_ids.has(active_source_mission_id):
		source_ready_to_turn_in_ids.append(active_source_mission_id)
		emit_signal("quest_state_changed", active_source_mission_id, "source_ready_to_turn_in_candidate")
	_notify_source_quest_state()

func complete_source_mission_turnin(mission_id: String, npc_id: String = "", map_id: String = "") -> bool:
	if mission_id != active_source_mission_id or completed_source_mission_ids.has(mission_id):
		return false
	if not source_ready_to_turn_in_ids.has(mission_id):
		return false
	if not npc_id.is_empty() and not source_graph.is_turnin_npc(mission_id, npc_id, map_id):
		return false
	var mission := source_graph.get_mission(mission_id)
	if mission.is_empty():
		return false
	completed_source_mission_ids.append(mission_id)
	source_ready_to_turn_in_ids.erase(mission_id)
	source_objective_progress.erase(mission_id)
	active_source_mission_id = ""
	emit_signal("quest_state_changed", mission_id, "source_completed_candidate")
	_notify_source_quest_state()
	return true

func _notify_source_quest_state() -> void:
	if not GameManager:
		return
	if active_source_mission_id.is_empty():
		GameManager.emit_signal("quest_updated", "", "لا توجد مهمة مصدر نشطة" if GameManager.current_language == "ar" else "No active source quest", 0, 0, false)
		GameManager.emit_signal("quest_description_changed", "")
		return
	var mission := source_graph.get_mission(active_source_mission_id)
	if mission.is_empty():
		return
	var progress: Array = source_objective_progress.get(active_source_mission_id, [])
	var completed_count := 0
	for value in progress:
		if bool(value):
			completed_count += 1
	var title := str(mission.get("name_ar", mission.get("name", active_source_mission_id))) if GameManager.current_language == "ar" else str(mission.get("name", active_source_mission_id))
	var ready := source_ready_to_turn_in_ids.has(active_source_mission_id)
	GameManager.emit_signal("quest_updated", active_source_mission_id, title, completed_count, progress.size(), ready)
	var description := str(mission.get("intention_description", ""))
	GameManager.emit_signal("quest_description_changed", description)

func get_source_mission(mission_id: String) -> Dictionary:
	return source_catalog.get_mission(mission_id)

func get_source_missions_for_npc(npc_id: String, role: String = "") -> Array[Dictionary]:
	return source_catalog.get_missions_for_npc(npc_id, role)

func get_source_missions_for_map(map_id: String) -> Array[Dictionary]:
	return source_catalog.get_missions_for_map(map_id)

# This is an offline starter chain. Content can be expanded without changing
# the progression API or requiring a server.
var quest_database: Dictionary = {
	"quest_wolves": {
		"turn_in_npc_id": "npc_sage",
		"title_ar": "تهديد الذئاب البرية",
		"title_en": "Wild Wolf Threat",
		"desc_ar": "اقضِ على 5 ذئاب برية في سهل التوأم لحماية القوافل.",
		"desc_en": "Defeat 5 wild wolves in Twin Plains to protect the caravans.",
		"target_enemy_type": "wolf",
		"required_kills": 5,
		"reward_gold": 500,
		"reward_xp": 800,
		"next_quest": "quest_wolf_alpha"
	},
	"quest_wolf_alpha": {
		"turn_in_npc_id": "npc_sage",
		"title_ar": "زعيم القطيع",
		"title_en": "Pack Leader",
		"desc_ar": "اهزم 8 ذئاب أخرى لتجبر زعيم القطيع على الظهور.",
		"desc_en": "Defeat 8 more wolves to draw out the pack leader.",
		"target_enemy_type": "wolf",
		"required_kills": 8,
		"reward_gold": 850,
		"reward_xp": 1200,
		"next_quest": "quest_meteor_gather"
	},
	"quest_dragon": {
		"turn_in_npc_id": "npc_sage",
		"title_ar": "تحدي تنين اللهب",
		"title_en": "Flame Dragon Challenge",
		"desc_ar": "اهزم تنين اللهب في قمة الجبل.",
		"desc_en": "Defeat the Flame Dragon at the mountain summit.",
		"target_enemy_type": "boss",
		"required_kills": 1,
		"reward_gold": 2500,
		"reward_xp": 3500,
		"next_quest": "quest_final_sage"
	},
	"quest_guardian": {
		"turn_in_npc_id": "npc_sage",
		"title_ar": "حارس الأطلال",
		"title_en": "Ruins Guardian",
		"desc_ar": "اقضِ على 10 وحوش في رحلة تطهير أطراف المدينة.",
		"desc_en": "Defeat 10 enemies while cleansing the outskirts of the city.",
		"target_enemy_type": "any",
		"required_kills": 10,
		"reward_gold": 1200,
		"reward_xp": 1800,
		"next_quest": "quest_level_10"
	},
	"quest_meteor_gather": {
		"turn_in_npc_id": "npc_sage",
		"title_ar":"أحجار من السماء",
		"title_en":"Stones from the Sky",
		"desc_ar":"اجمع 3 أحجار نيزك من الوحوش وأسقطها في الحقيبة.",
		"desc_en":"Collect 3 Meteor Stones from monsters.",
		"objective_type":"collect",
		"objective_target":"meteor_stone",
		"required_kills":3,
		"reward_gold":700,
		"reward_xp":900,
		"next_quest":"quest_blacksmith_visit"
	},
	"quest_blacksmith_visit": {
		"turn_in_npc_id": "npc_blacksmith",
		"title_ar":"سر الحداد",
		"title_en":"The Blacksmith's Secret",
		"desc_ar":"تحدث إلى حداد الأساطير وتعرف على صقل العتاد.",
		"desc_en":"Speak to the Master Blacksmith and learn equipment refinement.",
		"objective_type":"talk",
		"objective_target":"npc_blacksmith",
		"required_kills":1,
		"reward_gold":400,
		"reward_xp":500,
		"next_quest":"quest_guardian"
	},
	"quest_level_10": {
		"turn_in_npc_id": "npc_sage",
		"title_ar":"اختبار البطل",
		"title_en":"Hero's Trial",
		"desc_ar":"واصل التدريب حتى تصل إلى المستوى 10.",
		"desc_en":"Keep training until you reach level 10.",
		"objective_type":"reach_level",
		"objective_target":"10",
		"required_kills":1,
		"reward_gold":1000,
		"reward_xp":1500,
		"next_quest":"quest_dragon"
	},
	"quest_final_sage": {
		"turn_in_npc_id": "npc_sage",
		"title_ar":"عودة إلى الحكيم",
		"title_en":"Return to the Sage",
		"desc_ar":"عد إلى حكيم التوأم وأبلغه بانتصارك على التنين.",
		"desc_en":"Return to the Twin Sage and report the dragon's defeat.",
		"objective_type":"talk",
		"objective_target":"npc_sage",
		"required_kills":1,
		"reward_gold":3000,
		"reward_xp":4500,
		"next_quest":""
	}
}

func _ready() -> void:
	source_catalog.load_catalog()
	source_graph.load_graph()
	_validate_quest_database()
	_notify_game_manager()
	call_deferred("_connect_source_world_travel")

func _connect_source_world_travel() -> void:
	var manager := get_tree().get_first_node_in_group("world_travel_manager")
	if manager and manager.has_signal("travel_completed") and not manager.travel_completed.is_connected(_on_source_world_travel_completed):
		manager.travel_completed.connect(_on_source_world_travel_completed)
	if manager and manager.has_method("get_current_source_map_id"):
		var current_map := str(manager.get_current_source_map_id())
		if not current_map.is_empty():
			on_source_map_entered(current_map)

func _on_source_world_travel_completed(_destination_id: String, _world_position: Vector3) -> void:
	var manager := get_tree().get_first_node_in_group("world_travel_manager")
	if manager and manager.has_method("get_current_source_map_id"):
		var current_map := str(manager.get_current_source_map_id())
		if not current_map.is_empty():
			on_source_map_entered(current_map)

func _validate_quest_database() -> bool:
	for quest_id in quest_database:
		var quest: Dictionary = quest_database[quest_id]
		if int(quest.get("required_kills", 0)) <= 0:
			push_error("Quest %s has an invalid objective count." % quest_id)
			return false
		var objective_type := str(quest.get("objective_type", "kill"))
		if not ["kill", "collect", "talk", "reach_level"].has(objective_type):
			push_error("Quest %s has an unsupported objective type." % quest_id)
			return false
		var target := str(quest.get("objective_target", quest.get("target_enemy_type", "")))
		if target.is_empty():
			push_error("Quest %s has no objective target." % quest_id)
			return false
		var turn_in_npc := str(quest.get("turn_in_npc_id", "")).strip_edges()
		if turn_in_npc.is_empty():
			push_error("Quest %s has no designated turn-in NPC." % quest_id)
			return false
		var next_id := str(quest.get("next_quest", ""))
		if not next_id.is_empty() and not quest_database.has(next_id):
			push_error("Quest %s points to missing next quest %s." % [quest_id, next_id])
			return false
	return true

func get_active_quest() -> Dictionary:
	if not quest_database.has(active_quest_id):
		return {}
	return quest_database[active_quest_id].duplicate(true)

func on_enemy_killed(enemy_type: String) -> void:
	_advance_objective("kill", enemy_type, 1)

func on_item_collected(item_id: String, quantity: int = 1) -> void:
	_advance_objective("collect", item_id, quantity)

func on_npc_talked(npc_id: String) -> void:
	if is_quest_completed:
		var ready_quest := get_active_quest()
		var turn_in_id := str(ready_quest.get("turn_in_npc_id", "npc_sage"))
		if npc_id == turn_in_id:
			_claim_completed_quest()
		return
	_advance_objective("talk", npc_id, 1)

func on_level_reached(level: int) -> void:
	var quest: Dictionary = get_active_quest()
	if quest.is_empty() or str(quest.get("objective_type", "")) != "reach_level":
		return
	var required_level := int(quest.get("objective_target", "1"))
	if level >= required_level:
		_advance_objective("reach_level", str(required_level), 1)

func _advance_objective(event_type: String, target_id: String, amount: int) -> void:
	if is_quest_completed or not quest_database.has(active_quest_id) or amount <= 0:
		return
	var quest: Dictionary = quest_database[active_quest_id]
	var objective_type := str(quest.get("objective_type", "kill"))
	var objective_target := str(quest.get("objective_target", quest.get("target_enemy_type", "")))
	if objective_type != event_type or (objective_target != "any" and objective_target != target_id):
		return
	quest_progress = mini(quest_progress + amount, int(quest["required_kills"]))
	if quest_progress >= int(quest["required_kills"]):
		_complete_quest()
	else:
		_notify_game_manager()

func _complete_quest() -> void:
	if is_quest_completed or completed_quest_ids.has(active_quest_id):
		return
	# Objective completion is not quest completion: rewards are only granted
	# after the hero returns to the quest's designated turn-in NPC.
	is_quest_completed = true
	var quest: Dictionary = quest_database[active_quest_id]
	emit_signal("quest_state_changed", active_quest_id, "ready_to_turn_in")
	_notify_game_manager()
	if GameManager:
		var title := str(quest["title_ar"]) if GameManager.current_language == "ar" else str(quest["title_en"])
		var npc_name := str(quest.get("turn_in_npc_id", "npc_sage"))
		var message_ar := "اكتمل الهدف: %s. عُد إلى صاحب المهمة لتسلّم المكافأة." % title
		var message_en := "Objective complete: %s. Return to the quest NPC to claim your reward." % title
		GameManager.post_notification(message_ar if GameManager.current_language == "ar" else message_en, false)

func _claim_completed_quest() -> void:
	if not is_quest_completed or not quest_database.has(active_quest_id) or completed_quest_ids.has(active_quest_id):
		return
	var completed_id := active_quest_id
	var quest: Dictionary = quest_database[completed_id]
	var gold: int = maxi(0, int(quest.get("reward_gold", 0)))
	var xp: int = maxi(0, int(quest.get("reward_xp", 0)))
	completed_quest_ids.append(completed_id)
	if GameManager:
		GameManager.add_gold(gold)
		var player = GameManager.player_reference
		if is_instance_valid(player) and player.has_method("add_xp"):
			player.add_xp(xp)
		var title := str(quest["title_ar"]) if GameManager.current_language == "ar" else str(quest["title_en"])
		var message_ar := "استلمت مكافأة المهمة %s: %d ذهب و%d خبرة." % [title, gold, xp]
		var message_en := "Claimed %s reward: %d Gold and %d XP." % [title, gold, xp]
		GameManager.post_notification(message_ar if GameManager.current_language == "ar" else message_en, false)
	emit_signal("quest_state_changed", completed_id, "completed")
	var next_id := str(quest.get("next_quest", ""))
	if not next_id.is_empty() and quest_database.has(next_id):
		active_quest_id = next_id
		quest_progress = 0
		is_quest_completed = false
		emit_signal("quest_started", active_quest_id)
		_notify_game_manager()
	else:
		active_quest_id = ""
		quest_progress = 0
		is_quest_completed = true
		emit_signal("quest_state_changed", completed_id, "chain_completed")

func _get_navigation_target() -> Dictionary:
	if active_quest_id.is_empty():
		return {}
	var destination := Vector3(18.0, 0.0, 15.0)
	var travel_id := "twin_city"
	var turn_in_npc := ""
	if is_quest_completed:
		var active_data := get_active_quest()
		turn_in_npc = str(active_data.get("turn_in_npc_id", "npc_sage"))
		if turn_in_npc == "npc_blacksmith":
			destination = Vector3(-5.0, 0.0, 4.0)
		else:
			destination = Vector3(4.0, 0.0, 3.0)
	else:
		match active_quest_id:
			"quest_wolves", "quest_wolf_alpha", "quest_meteor_gather":
				travel_id = "twin_plains"
				destination = Vector3(18.0, 0.0, 15.0)
			"quest_dragon":
				travel_id = "mountain_summit"
				destination = Vector3(40.0, 0.0, -35.0)
			"quest_guardian":
				travel_id = "desert_ruins"
				destination = Vector3(-32.0, 0.0, 28.0)
			"quest_blacksmith_visit":
				travel_id = "twin_city"
				destination = Vector3(-5.0, 0.0, 4.0)
			"quest_final_sage":
				travel_id = "twin_city"
				destination = Vector3(4.0, 0.0, 3.0)
	return {
		"travel_id": travel_id,
		"destination": destination,
		"turn_in": is_quest_completed,
		"turn_in_npc_id": turn_in_npc
	}

func navigate_to_active_source_mission() -> bool:
	if active_source_mission_id.is_empty():
		return false
	var mission := source_graph.get_mission(active_source_mission_id)
	var objectives := source_graph.get_objective_routes(active_source_mission_id)
	var progress: Array = source_objective_progress.get(active_source_mission_id, [])
	var player := GameManager.player_reference if GameManager else null
	if player == null or not is_instance_valid(player):
		return false
	for index in range(objectives.size()):
		if index < progress.size() and bool(progress[index]):
			continue
		var objective: Dictionary = objectives[index]
		var map_id := str(objective.get("map_id", ""))
		var manager := get_tree().get_first_node_in_group("world_travel_manager")
		var current_map := str(manager.get_current_source_map_id()) if manager and manager.has_method("get_current_source_map_id") else ""
		if not map_id.is_empty() and not current_map.is_empty() and map_id != current_map:
			if manager and manager.has_method("travel_to"):
				return bool(manager.travel_to("city_" + map_id, "quest"))
			return false
		if str(objective.get("kind", "")) == "npc":
			var wanted_npc := str(objective.get("npc_id", "")).lstrip("0")
			for npc in get_tree().get_nodes_in_group("source_quest_npcs"):
				if str(npc.get("source_npc_id")).lstrip("0") == wanted_npc and str(npc.get("source_map_id")) == map_id:
					if player.has_method("move_towards_target_position"):
						player.move_towards_target_position(npc.global_position, 0.0)
					return true
			_notify_source_navigation_gap("لم يتم إدماج شخصية المهمة المطلوبة في هذه الخريطة بعد: " + str(objective.get("npc_name", wanted_npc)))
			return false
		if str(objective.get("kind", "")) == "mob":
			_notify_source_navigation_gap("هدف المهمة: " + str(objective.get("monster_name", "وحش غير محدد")) + " — لم يُربط نموذج هذا الوحش بالخريطة بعد.")
			return false
		if str(objective.get("kind", "")) in ["item_t", "chk_item"]:
			_notify_source_navigation_gap("هدف المهمة يتطلب العنصر: " + str(objective.get("item_name", objective.get("item_id", ""))) + " — ربط مصدر العنصر قيد الاستكمال.")
			return false
		_notify_source_navigation_gap("شرط المهمة يحتاج إلى ربط مصدر إضافي: " + str(objective.get("kind", "")))
		return false
	if source_ready_to_turn_in_ids.has(active_source_mission_id):
		var turnin := source_graph.get_route(active_source_mission_id, true)
		_notify_source_navigation_gap("اكتمل الهدف. ارجع إلى " + str(turnin.get("npc_name", "صاحب المهمة")) + " لاستلام المكافأة.")
		return true
	_notify_source_navigation_gap("لا توجد أهداف قابلة للملاحة في بيانات المهمة الحالية.")
	return false

func _notify_source_navigation_gap(message: String) -> void:
	if GameManager:
		GameManager.post_notification(message, true)

func navigate_to_quest_target() -> void:
	if not GameManager or not is_instance_valid(GameManager.player_reference):
		return
	if not active_source_mission_id.is_empty():
		var source_turn_in := source_ready_to_turn_in_ids.has(active_source_mission_id)
		var source_route := source_graph.get_route(active_source_mission_id, source_turn_in)
		var source_travel_manager := get_tree().get_first_node_in_group("world_travel_manager")
		if source_travel_manager and source_travel_manager.has_method("navigate_to_source_route"):
			if source_travel_manager.navigate_to_source_route(source_route):
				return
		if GameManager:
			GameManager.post_notification("تعذر الوصول إلى خريطة أو شخصية المهمة من المشهد المحمّل." if GameManager.current_language == "ar" else "The quest map or NPC is not available in the loaded scene.", true)
		return
	var target := _get_navigation_target()
	if target.is_empty():
		return
	var destination: Vector3 = target.get("destination", Vector3.ZERO)
	var travel_id := str(target.get("travel_id", "twin_city"))
	var travel_manager := get_tree().get_first_node_in_group("world_travel_manager")
	if travel_manager and travel_manager.has_method("travel_to"):
		if not travel_manager.travel_to(travel_id, "quest"):
			return
	if GameManager.player_reference.has_method("move_towards_target_position"):
		GameManager.player_reference.move_towards_target_position(destination, 0.0)
		var message := "العودة إلى صاحب المهمة لاستلام المكافأة..." if bool(target.get("turn_in", false)) and GameManager.current_language == "ar" else ("الملاحة التلقائية إلى موقع المهمة..." if GameManager.current_language == "ar" else ("Returning to the quest NPC to claim the reward..." if bool(target.get("turn_in", false)) else "Navigating to quest objective..."))
		GameManager.post_notification(message, false)

func _notify_game_manager() -> void:
	if not GameManager:
		return
	var quest: Dictionary = get_active_quest()
	if quest.is_empty():
		return
	var title := str(quest["title_ar"]) if GameManager.current_language == "ar" else str(quest["title_en"])
	GameManager.emit_signal(
		"quest_updated",
		active_quest_id,
		title,
		quest_progress,
		int(quest["required_kills"]),
		is_quest_completed
	)
	var description := str(quest.get("desc_ar", "")) if GameManager.current_language == "ar" else str(quest.get("desc_en", ""))
	GameManager.emit_signal("quest_description_changed", description)

func serialize() -> Dictionary:
	return {
		"active_quest_id": active_quest_id,
		"quest_progress": quest_progress,
		"is_quest_completed": is_quest_completed,
		"completed_quest_ids": completed_quest_ids.duplicate(),
		"chain_completed": active_quest_id.is_empty()
	}

func deserialize(data: Dictionary) -> void:
	var requested_id := str(data.get("active_quest_id", DEFAULT_QUEST_ID))
	completed_quest_ids.clear()
	for value in data.get("completed_quest_ids", []):
		var quest_id := str(value)
		if quest_database.has(quest_id) and not completed_quest_ids.has(quest_id):
			completed_quest_ids.append(quest_id)
	if bool(data.get("chain_completed", false)) or requested_id.is_empty():
		active_quest_id = ""
		quest_progress = 0
		is_quest_completed = true
		return
	active_quest_id = requested_id if quest_database.has(requested_id) else DEFAULT_QUEST_ID
	var quest: Dictionary = quest_database[active_quest_id]
	quest_progress = clampi(int(data.get("quest_progress", 0)), 0, int(quest["required_kills"]))
	is_quest_completed = bool(data.get("is_quest_completed", false))
	# Completed history is authoritative; never replay its reward after loading.
	if completed_quest_ids.has(active_quest_id):
		is_quest_completed = true
	_notify_game_manager()
