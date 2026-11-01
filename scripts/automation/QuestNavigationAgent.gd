extends Node
class_name QuestNavigationAgent

signal quest_state_changed(quest_id: String, state: String)

var active_quest_id: String = "quest_wolves"
var quest_progress: int = 0
var is_quest_completed: bool = false

var quest_database: Dictionary = {
	"quest_wolves": {
		"title_ar": "تهديد الذئاب البرية",
		"title_en": "Wild Wolf Threat",
		"desc_ar": "اذهب إلى سهل التوأم واقضِ على 5 ذئاب برية لحماية القوافل التجارية.",
		"desc_en": "Go to Twin Plains and defeat 5 Wild Wolves to protect trade caravans.",
		"target_enemy_type": "wolf",
		"required_kills": 5,
		"reward_gold": 500,
		"reward_xp": 800,
		"next_quest": "quest_dragon"
	},
	"quest_dragon": {
		"title_ar": "تحدي تنين اللهب",
		"title_en": "Flame Dragon Challenge",
		"desc_ar": "تحدَّ تنين اللهب في قمة الجبل واهزمه لإثبات جدارتك كأسطورة.",
		"desc_en": "Challenge the Flame Dragon at the mountain summit and defeat it.",
		"target_enemy_type": "boss",
		"required_kills": 1,
		"reward_gold": 2500,
		"reward_xp": 3500,
		"next_quest": ""
	}
}

func _ready() -> void:
	_notify_game_manager()

func on_enemy_killed(enemy_type: String) -> void:
	if is_quest_completed:
		return
	if not quest_database.has(active_quest_id):
		return
		
	var q = quest_database[active_quest_id]
	if q["target_enemy_type"] == enemy_type or q["target_enemy_type"] == "any":
		quest_progress += 1
		if quest_progress >= q["required_kills"]:
			_complete_quest()
		else:
			_notify_game_manager()

func _complete_quest() -> void:
	is_quest_completed = true
	var q = quest_database[active_quest_id]
	var gold = q.get("reward_gold", 0)
	var xp = q.get("reward_xp", 0)
	
	if GameManager:
		GameManager.add_gold(gold)
		if GameManager.player_reference and GameManager.player_reference.has_method("add_xp"):
			GameManager.player_reference.add_xp(xp)
		var txt_ar = "اكتملت المهمة: %s! حصلت على %d ذهب و %d خبرة" % [q["title_ar"], gold, xp]
		var txt_en = "Quest Completed: %s! Received %d Gold & %d XP" % [q["title_en"], gold, xp]
		GameManager.post_notification(txt_ar if GameManager.current_language == "ar" else txt_en, false)
		
	emit_signal("quest_state_changed", active_quest_id, "completed")
	_notify_game_manager()
	
	# Progress to next quest if available
	if q["next_quest"] != "":
		active_quest_id = q["next_quest"]
		quest_progress = 0
		is_quest_completed = false
		_notify_game_manager()

func navigate_to_quest_target() -> void:
	if not GameManager or not GameManager.player_reference:
		return
	var player = GameManager.player_reference
	
	# Determine destination based on active quest
	var dest = Vector3(18.0, 0.0, 15.0) # Wolf zone in Twin Plains
	if active_quest_id == "quest_dragon":
		dest = Vector3(35.0, 0.0, -30.0) # Dragon mountain summit
		
	if player.has_method("move_towards_target_position"):
		player.move_towards_target_position(dest, 0.0)
		var txt = "الملاحة التلقائية إلى موقع المهمة..." if GameManager.current_language == "ar" else "Navigating to quest objective..."
		GameManager.post_notification(txt, false)

func _notify_game_manager() -> void:
	if not GameManager:
		return
	var q = quest_database.get(active_quest_id, null)
	if q:
		var title = q["title_ar"] if GameManager.current_language == "ar" else q["title_en"]
		var req = q["required_kills"]
		GameManager.emit_signal("quest_updated", active_quest_id, title, quest_progress, req, is_quest_completed)

func serialize() -> Dictionary:
	return {
		"active_quest_id": active_quest_id,
		"quest_progress": quest_progress,
		"is_quest_completed": is_quest_completed
	}

func deserialize(data: Dictionary) -> void:
	active_quest_id = data.get("active_quest_id", "quest_wolves")
	quest_progress = data.get("quest_progress", 0)
	is_quest_completed = data.get("is_quest_completed", false)
	_notify_game_manager()
