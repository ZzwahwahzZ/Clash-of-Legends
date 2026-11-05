extends Node

signal language_changed(new_lang: String)
signal player_registered(player: CharacterBody3D)
signal player_stats_changed(hp: int, max_hp: int, mp: int, max_mp: int, xp: int, max_xp: int, level: int, gold: int)
signal quest_updated(quest_id: String, objective: String, progress: int, goal: int, is_completed: bool)
signal quest_description_changed(description: String)
signal boss_spawned(boss_name: String, position: Vector3)
signal boss_defeated(boss_name: String, killer_name: String)
signal notification_posted(text: String, is_alert: bool)

var current_language: String = "ar"
var player_reference: CharacterBody3D = null
var current_target: Node3D = null
var nearby_npc: Node3D = null
var is_auto_hunting: bool = false
var is_auto_looting: bool = true

# Local economy: Gold only
var current_gold: int = 1500

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Arabic is default
	set_language("ar")

func register_player(player: CharacterBody3D) -> void:
	player_reference = player
	emit_signal("player_registered", player)
	post_notification("تم تسجيل دخول البطل في عالم صراع الأساطير" if current_language == "ar" else "Hero entered the world of Clash of Legends", false)

func set_language(lang_code: String) -> void:
	if lang_code != "ar" and lang_code != "en":
		lang_code = "ar"
	current_language = lang_code
	TranslationServer.set_locale(lang_code)
	emit_signal("language_changed", current_language)

func get_translated_text(key: String) -> String:
	var translations = {
		"game_title": {"ar": "صراع الأساطير", "en": "Clash of Legends"},
		"level": {"ar": "المستوى", "en": "Level"},
		"gold": {"ar": "ذهب", "en": "Gold"},
		"attack": {"ar": "هجوم", "en": "Attack"},
		"inventory": {"ar": "الحقيبة", "en": "Inventory"},
		"blacksmith": {"ar": "الحداد", "en": "Blacksmith"},
		"settings": {"ar": "الإعدادات", "en": "Settings"},
		"auto_hunt": {"ar": "صيد تلقائي", "en": "Auto Hunt"},
		"auto_loot": {"ar": "جمع تلقائي", "en": "Auto Loot"},
		"mount": {"ar": "امتطاء", "en": "Mount"},
		"jump": {"ar": "قفز", "en": "Jump"},
		"quest": {"ar": "المهمة", "en": "Quest"},
		"refine": {"ar": "صقل", "en": "Refine"},
		"equip": {"ar": "ارتداء", "en": "Equip"},
		"use": {"ar": "استخدام", "en": "Use"},
		"sell": {"ar": "بيع", "en": "Sell"},
		"close": {"ar": "إغلاق", "en": "Close"},
		"save": {"ar": "حفظ", "en": "Save"},
		"load": {"ar": "تحميل", "en": "Load"}
	}
	if translations.has(key):
		return translations[key].get(current_language, key)
	return key

func add_gold(amount: int) -> void:
	current_gold = max(0, current_gold + amount)
	if player_reference and player_reference.has_method("sync_stats_to_hud"):
		player_reference.sync_stats_to_hud()

func spend_gold(amount: int) -> bool:
	if amount < 0:
		return false
	if current_gold >= amount:
		current_gold -= amount
		if player_reference and player_reference.has_method("sync_stats_to_hud"):
			player_reference.sync_stats_to_hud()
		return true
	post_notification("ذهب غير كافٍ!" if current_language == "ar" else "Insufficient Gold!", true)
	return false

func post_notification(text: String, is_alert: bool = false) -> void:
	emit_signal("notification_posted", text, is_alert)


func set_nearby_npc(npc: Node3D) -> void:
	if not is_instance_valid(npc):
		return
	nearby_npc = npc
	post_notification("اضغط زر تفاعل للتحدث" if current_language == "ar" else "Tap Interact to talk", false)

func clear_nearby_npc(npc: Node3D) -> void:
	if nearby_npc == npc:
		nearby_npc = null
