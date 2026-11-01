extends Node

signal language_changed(new_lang: String)
signal player_registered(player: CharacterBody3D)
signal player_stats_changed(hp: int, max_hp: int, mp: int, max_mp: int, xp: int, max_xp: int, level: int, gold: int)
signal quest_updated(quest_id: String, objective: String, progress: int, goal: int, is_completed: bool)
signal boss_spawned(boss_name: String, position: Vector3)
signal boss_defeated(boss_name: String, killer_name: String)
signal notification_posted(text: String, is_alert: bool)
signal chat_message_received(sender: String, message: String, channel: String)

var current_language: String = "ar"
var player_reference: CharacterBody3D = null
var current_target: Node3D = null
var is_auto_hunting: bool = false
var is_auto_looting: bool = true

# Local economy: Gold only
var current_gold: int = 1500

var local_chat_pool_ar: Array[Dictionary] = [
	{"sender": "سيد_السيوف", "msg": "هل ينضم أحد لصيد التنين في سهل التوأم؟", "channel": "world"},
	{"sender": "حكيم_الرياح", "msg": "أحتاج أحجار نيزكية لترقية درع التروجان +3", "channel": "trade"},
	{"sender": "صائد_الذئاب", "msg": "منطقة الذئاب البرية مليئة بالذهب والعتاد اليوم!", "channel": "general"},
	{"sender": "فارس_الصحراء", "msg": "مدينة التوأم آمنة، التجار مستعدون للشراء", "channel": "world"},
	{"sender": "رامي_السهام", "msg": "مهارة السهم السريع تصيب الأهداف بدقة فائقة", "channel": "team"}
]

var local_chat_pool_en: Array[Dictionary] = [
	{"sender": "SwordMaster", "msg": "Anyone up for hunting the dragon at Twin Plains?", "channel": "world"},
	{"sender": "WindSage", "msg": "Looking for meteors to upgrade Trojan armor +3", "channel": "trade"},
	{"sender": "WolfHunter", "msg": "Wild wolf zone has great gold drops today!", "channel": "general"},
	{"sender": "DesertKnight", "msg": "Twin City is safe, merchants ready to buy", "channel": "world"},
	{"sender": "ArrowMaster", "msg": "Rapid arrow skill strikes targets with lethal precision", "channel": "team"}
]

var _chat_timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Arabic is default
	set_language("ar")

func _process(delta: float) -> void:
	_chat_timer += delta
	if _chat_timer > 12.0:
		_chat_timer = 0.0
		_trigger_simulated_world_chat()

func register_player(player: CharacterBody3D) -> void:
	player_reference = player
	emit_signal("player_registered", player)
	post_notification("تم تسجيل دخول البطل في عالم صراع الأساطير" if current_language == "ar" else "Hero logged into Clash of Legends world", false)

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
	if current_gold >= amount:
		current_gold -= amount
		if player_reference and player_reference.has_method("sync_stats_to_hud"):
			player_reference.sync_stats_to_hud()
		return true
	post_notification("ذهب غير كافٍ!" if current_language == "ar" else "Insufficient Gold!", true)
	return false

func post_notification(text: String, is_alert: bool = false) -> void:
	emit_signal("notification_posted", text, is_alert)

func _trigger_simulated_world_chat() -> void:
	var pool = local_chat_pool_ar if current_language == "ar" else local_chat_pool_en
	if pool.size() > 0:
		var entry = pool[randi() % pool.size()]
		emit_signal("chat_message_received", entry["sender"], entry["msg"], entry["channel"])
