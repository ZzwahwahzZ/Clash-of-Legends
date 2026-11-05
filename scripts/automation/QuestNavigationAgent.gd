extends Node
class_name QuestNavigationAgent

signal quest_state_changed(quest_id: String, state: String)
signal quest_started(quest_id: String)

const DEFAULT_QUEST_ID := "quest_wolves"

var active_quest_id: String = DEFAULT_QUEST_ID
var quest_progress: int = 0
var is_quest_completed: bool = false
var completed_quest_ids: Array[String] = []

# This is an offline starter chain. Content can be expanded without changing
# the progression API or requiring a server.
var quest_database: Dictionary = {
	"quest_wolves": {
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
	_validate_quest_database()
	_notify_game_manager()

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

	is_quest_completed = true
	var completed_id := active_quest_id
	var quest: Dictionary = quest_database[completed_id]
	completed_quest_ids.append(completed_id)

	var gold: int = maxi(0, int(quest.get("reward_gold", 0)))
	var xp: int = maxi(0, int(quest.get("reward_xp", 0)))
	if GameManager:
		GameManager.add_gold(gold)
		var player = GameManager.player_reference
		if is_instance_valid(player) and player.has_method("add_xp"):
			player.add_xp(xp)
		var title := str(quest["title_ar"]) if GameManager.current_language == "ar" else str(quest["title_en"])
		var message_ar := "اكتملت المهمة: %s! حصلت على %d ذهب و%d خبرة" % [title, gold, xp]
		var message_en := "Quest completed: %s! Reward: %d Gold and %d XP" % [title, gold, xp]
		GameManager.post_notification(message_ar if GameManager.current_language == "ar" else message_en, false)

	emit_signal("quest_state_changed", completed_id, "completed")
	_notify_game_manager()

	var next_id := str(quest.get("next_quest", ""))
	if not next_id.is_empty() and quest_database.has(next_id):
		active_quest_id = next_id
		quest_progress = 0
		is_quest_completed = false
		emit_signal("quest_started", active_quest_id)
		_notify_game_manager()

func navigate_to_quest_target() -> void:
	if not GameManager or not is_instance_valid(GameManager.player_reference):
		return
	var destination := Vector3(18.0, 0.0, 15.0)
	match active_quest_id:
		"quest_dragon":
			destination = Vector3(35.0, 0.0, -30.0)
		"quest_guardian":
			destination = Vector3(25.0, 0.0, 20.0)
	if GameManager.player_reference.has_method("move_towards_target_position"):
		GameManager.player_reference.move_towards_target_position(destination, 0.0)
		var message := "الملاحة التلقائية إلى موقع المهمة..." if GameManager.current_language == "ar" else "Navigating to quest objective..."
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

func serialize() -> Dictionary:
	return {
		"active_quest_id": active_quest_id,
		"quest_progress": quest_progress,
		"is_quest_completed": is_quest_completed,
		"completed_quest_ids": completed_quest_ids.duplicate()
	}

func deserialize(data: Dictionary) -> void:
	var requested_id := str(data.get("active_quest_id", DEFAULT_QUEST_ID))
	active_quest_id = requested_id if quest_database.has(requested_id) else DEFAULT_QUEST_ID
	var quest: Dictionary = quest_database[active_quest_id]
	quest_progress = clampi(int(data.get("quest_progress", 0)), 0, int(quest["required_kills"]))
	is_quest_completed = bool(data.get("is_quest_completed", false))
	completed_quest_ids.clear()
	for value in data.get("completed_quest_ids", []):
		var quest_id := str(value)
		if quest_database.has(quest_id) and not completed_quest_ids.has(quest_id):
			completed_quest_ids.append(quest_id)
	# Completed history is authoritative; never replay its reward after loading.
	if completed_quest_ids.has(active_quest_id):
		is_quest_completed = true
	_notify_game_manager()
