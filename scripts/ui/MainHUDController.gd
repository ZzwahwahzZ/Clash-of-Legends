extends Control
class_name MainHUDController

@onready var hp_bar: ProgressBar = get_node_or_null("TopLeft/BarsVBox/HPBar")
@onready var mp_bar: ProgressBar = get_node_or_null("TopLeft/BarsVBox/MPBar")
@onready var xp_bar: ProgressBar = get_node_or_null("Bottom/XPBar")
@onready var hp_label: Label = get_node_or_null("TopLeft/BarsVBox/HPBar/HPLabel")
@onready var mp_label: Label = get_node_or_null("TopLeft/BarsVBox/MPBar/MPLabel")
@onready var level_label: Label = get_node_or_null("TopLeft/LevelBadge/LevelLabel")
@onready var gold_label: Label = get_node_or_null("TopLeft/GoldBox/GoldLabel")

@onready var quest_banner: Button = get_node_or_null("TopRight/QuestBanner")
@onready var quest_title: Label = get_node_or_null("TopRight/QuestBanner/QuestTitle")
@onready var quest_progress: Label = get_node_or_null("TopRight/QuestBanner/QuestProgress")

@onready var auto_hunt_btn: Button = get_node_or_null("TopRight/AutoControls/AutoHuntBtn")
@onready var auto_loot_btn: Button = get_node_or_null("TopRight/AutoControls/AutoLootBtn")

@onready var inv_btn: Button = get_node_or_null("TopRight/MenuButtons/InvBtn")
@onready var blacksmith_btn: Button = get_node_or_null("TopRight/MenuButtons/BlacksmithBtn")
@onready var settings_btn: Button = get_node_or_null("TopRight/MenuButtons/SettingsBtn")

@onready var attack_btn: Button = get_node_or_null("BottomRight/ActionButtons/AttackBtn")
@onready var skill_1_btn: Button = get_node_or_null("BottomRight/ActionButtons/Skill1Btn")
@onready var skill_2_btn: Button = get_node_or_null("BottomRight/ActionButtons/Skill2Btn")
@onready var jump_btn: Button = get_node_or_null("BottomRight/UtilityButtons/JumpBtn")
@onready var mount_btn: Button = get_node_or_null("BottomRight/UtilityButtons/MountBtn")

@onready var joystick: VirtualJoystickController = get_node_or_null("BottomLeft/VirtualJoystick")
@onready var notification_label: Label = get_node_or_null("Center/NotificationLabel")
@onready var chat_label: Label = get_node_or_null("BottomLeft/ChatLabel")

var current_skills: Array[String] = []

func _ready() -> void:
	# Connect to GameManager signals
	if GameManager:
		GameManager.player_stats_changed.connect(_on_player_stats_changed)
		GameManager.quest_updated.connect(_on_quest_updated)
		GameManager.notification_posted.connect(_on_notification_posted)
		GameManager.chat_message_received.connect(_on_chat_received)
		GameManager.language_changed.connect(_on_language_changed)
		
	if CombatEngine:
		CombatEngine.damage_dealt.connect(_on_damage_dealt)
		
	# Connect button events safely
	if attack_btn:
		attack_btn.pressed.connect(_on_attack_pressed)
	if skill_1_btn:
		skill_1_btn.pressed.connect(_on_skill_1_pressed)
	if skill_2_btn:
		skill_2_btn.pressed.connect(_on_skill_2_pressed)
	if jump_btn:
		jump_btn.pressed.connect(_on_jump_pressed)
	if mount_btn:
		mount_btn.pressed.connect(_on_mount_pressed)
		
	if auto_hunt_btn:
		auto_hunt_btn.pressed.connect(_on_auto_hunt_pressed)
	if auto_loot_btn:
		auto_loot_btn.pressed.connect(_on_auto_loot_pressed)
		
	if inv_btn:
		inv_btn.pressed.connect(_on_inventory_pressed)
	if blacksmith_btn:
		blacksmith_btn.pressed.connect(_on_blacksmith_pressed)
	if settings_btn:
		settings_btn.pressed.connect(_on_settings_pressed)
	if quest_banner:
		quest_banner.pressed.connect(_on_quest_banner_pressed)
		
	if joystick:
		joystick.joystick_moved.connect(_on_joystick_moved)
		
	_refresh_hud_labels()

func _on_player_stats_changed(hp: int, max_hp: int, mp: int, max_mp: int, xp: int, max_xp: int, level: int, gold: int) -> void:
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
	if hp_label:
		hp_label.text = "%d / %d" % [hp, max_hp]
		
	if mp_bar:
		mp_bar.max_value = max_mp
		mp_bar.value = mp
	if mp_label:
		mp_label.text = "%d / %d" % [mp, max_mp]
		
	if xp_bar:
		xp_bar.max_value = max_xp
		xp_bar.value = xp
		
	if level_label:
		level_label.text = "%d" % level
	if gold_label:
		gold_label.text = "%d" % gold
		
	_update_skill_buttons()

func _update_skill_buttons() -> void:
	var player = GameManager.player_reference if GameManager else null
	if not player or not CombatEngine:
		return
	var cls = player.get_character_class() if player.has_method("get_character_class") else "Trojan"
	current_skills = CombatEngine.get_class_skills(cls)
	var is_ar = GameManager and GameManager.current_language == "ar"
	
	if skill_1_btn and current_skills.size() > 0:
		var s1_def = CombatEngine.skill_database[current_skills[0]]
		skill_1_btn.text = s1_def["name_ar"] if is_ar else s1_def["name_en"]
		skill_1_btn.visible = true
	elif skill_1_btn:
		skill_1_btn.visible = false
		
	if skill_2_btn and current_skills.size() > 1:
		var s2_def = CombatEngine.skill_database[current_skills[1]]
		skill_2_btn.text = s2_def["name_ar"] if is_ar else s2_def["name_en"]
		skill_2_btn.visible = true
	elif skill_2_btn:
		skill_2_btn.visible = false

func _on_attack_pressed() -> void:
	var player = GameManager.player_reference if GameManager else null
	if player and player.has_method("execute_basic_attack"):
		player.execute_basic_attack()

func _on_skill_1_pressed() -> void:
	if current_skills.size() > 0:
		_cast_skill(current_skills[0])

func _on_skill_2_pressed() -> void:
	if current_skills.size() > 1:
		_cast_skill(current_skills[1])

func _cast_skill(skill_id: String) -> void:
	var player = GameManager.player_reference if GameManager else null
	if not player or not CombatEngine:
		return
	var target = GameManager.current_target if GameManager else null
	CombatEngine.execute_skill(skill_id, player, target)

func _on_jump_pressed() -> void:
	var player = GameManager.player_reference if GameManager else null
	if player and player.has_method("perform_jump"):
		player.perform_jump()

func _on_mount_pressed() -> void:
	var player = GameManager.player_reference if GameManager else null
	if player and player.has_method("toggle_mount"):
		player.toggle_mount()

func _on_auto_hunt_pressed() -> void:
	if AutoHuntManager:
		var active = AutoHuntManager.toggle_auto_hunt()
		if auto_hunt_btn:
			auto_hunt_btn.modulate = Color(0.4, 1.0, 0.4) if active else Color(1, 1, 1)

func _on_auto_loot_pressed() -> void:
	if AutoLootManager:
		var active = AutoLootManager.toggle_auto_loot()
		if auto_loot_btn:
			auto_loot_btn.modulate = Color(0.4, 1.0, 0.4) if active else Color(1, 1, 1)

func _on_inventory_pressed() -> void:
	var tree = get_tree()
	if tree:
		var inv_ui = tree.get_first_node_in_group("inventory_ui")
		if inv_ui and inv_ui.has_method("toggle_ui"):
			inv_ui.toggle_ui()

func _on_blacksmith_pressed() -> void:
	var tree = get_tree()
	if tree:
		var b_ui = tree.get_first_node_in_group("blacksmith_ui")
		if b_ui and b_ui.has_method("open_ui"):
			b_ui.open_ui()

func _on_settings_pressed() -> void:
	var tree = get_tree()
	if tree:
		var s_ui = tree.get_first_node_in_group("settings_ui")
		if s_ui and s_ui.has_method("toggle_ui"):
			s_ui.toggle_ui()

func _on_quest_banner_pressed() -> void:
	var tree = get_tree()
	if tree:
		var qa = tree.get_first_node_in_group("quest_agents")
		if qa and qa.has_method("navigate_to_quest_target"):
			qa.navigate_to_quest_target()

func _on_joystick_moved(dir: Vector2) -> void:
	var player = GameManager.player_reference if GameManager else null
	if player and player.has_method("set_joystick_input"):
		player.set_joystick_input(dir)

func _on_quest_updated(_qid: String, obj_title: String, prog: int, goal: int, is_done: bool) -> void:
	if quest_title:
		quest_title.text = obj_title
	if quest_progress:
		var is_ar = GameManager and GameManager.current_language == "ar"
		if is_done:
			quest_progress.text = "مكتملة! انقر للاستلام" if is_ar else "Completed! Tap to turn in"
		else:
			quest_progress.text = "التقدم: %d / %d (انقر للملاحة)" % [prog, goal] if is_ar else "Progress: %d / %d (Tap to navigate)" % [prog, goal]

func _on_notification_posted(msg: String, is_alert: bool) -> void:
	if notification_label:
		notification_label.text = msg
		notification_label.modulate = Color(1, 0.3, 0.3) if is_alert else Color(1, 0.9, 0.4)
		var tween = create_tween()
		notification_label.modulate.a = 1.0
		tween.tween_property(notification_label, "modulate:a", 0.0, 3.5).set_delay(1.5)

func _on_chat_received(sender: String, message: String, channel: String) -> void:
	if chat_label:
		chat_label.text = "[%s] %s: %s" % [channel, sender, message]

func _on_damage_dealt(_target: Node3D, amount: int, is_crit: bool, _pos: Vector3) -> void:
	if notification_label and is_crit:
		var is_ar = GameManager and GameManager.current_language == "ar"
		var crit_text = "ضربة حرجة! -%d" % amount if is_ar else "CRITICAL HIT! -%d" % amount
		notification_label.text = crit_text
		notification_label.modulate = Color(1, 0.2, 0.1)

func _on_language_changed(_new_lang: String) -> void:
	_refresh_hud_labels()
	_update_skill_buttons()

func _refresh_hud_labels() -> void:
	var is_ar = GameManager and GameManager.current_language == "ar"
	if auto_hunt_btn:
		auto_hunt_btn.text = "صيد تلقائي" if is_ar else "Auto Hunt"
	if auto_loot_btn:
		auto_loot_btn.text = "جمع تلقائي" if is_ar else "Auto Loot"
	if inv_btn:
		inv_btn.text = "الحقيبة" if is_ar else "Bag"
	if blacksmith_btn:
		blacksmith_btn.text = "الحداد" if is_ar else "Forge"
	if settings_btn:
		settings_btn.text = "الإعدادات" if is_ar else "Settings"
	if attack_btn:
		attack_btn.text = "هجوم" if is_ar else "Attack"
	if jump_btn:
		jump_btn.text = "قفز" if is_ar else "Jump"
	if mount_btn:
		mount_btn.text = "الحصان" if is_ar else "Mount"
