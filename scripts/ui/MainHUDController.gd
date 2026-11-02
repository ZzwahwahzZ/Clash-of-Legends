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
@onready var interact_btn: Button = get_node_or_null("BottomLeft/InteractBtn")

@onready var attack_btn: Button = get_node_or_null("BottomRight/ActionButtons/AttackBtn")
@onready var skill_1_btn: Button = get_node_or_null("BottomRight/ActionButtons/Skill1Btn")
@onready var skill_2_btn: Button = get_node_or_null("BottomRight/ActionButtons/Skill2Btn")
@onready var jump_btn: Button = get_node_or_null("BottomRight/UtilityButtons/JumpBtn")
@onready var mount_btn: Button = get_node_or_null("BottomRight/UtilityButtons/MountBtn")

@onready var joystick: VirtualJoystickController = get_node_or_null("BottomLeft/VirtualJoystick")
@onready var notification_label: Label = get_node_or_null("Center/NotificationLabel")

var current_skills: Array[String] = []

func _ready() -> void:
	if GameManager:
		GameManager.player_stats_changed.connect(_on_player_stats_changed)
		GameManager.quest_updated.connect(_on_quest_updated)
		GameManager.notification_posted.connect(_on_notification_posted)
		GameManager.language_changed.connect(_on_language_changed)

	if CombatEngine:
		CombatEngine.damage_dealt.connect(_on_damage_dealt)

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
	if interact_btn:
		interact_btn.pressed.connect(_on_interact_pressed)
		interact_btn.visible = false
	if joystick:
		joystick.joystick_moved.connect(_on_joystick_moved)

	_refresh_hud_labels()
	_update_interact_button()

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

func _process(_delta: float) -> void:
	_update_interact_button()

func _update_interact_button() -> void:
	if interact_btn:
		interact_btn.visible = GameManager != null and is_instance_valid(GameManager.nearby_npc)

func _on_interact_pressed() -> void:
	var npc = GameManager.nearby_npc if GameManager else null
	var player = GameManager.player_reference if GameManager else null
	if is_instance_valid(npc) and is_instance_valid(player) and npc.has_method("interact"):
		npc.interact(player)

func _update_skill_buttons() -> void:
	var player = GameManager.player_reference if GameManager else null
	if not player or not CombatEngine:
		return
	var player_class = player.get_character_class() if player.has_method("get_character_class") else "Trojan"
	current_skills = CombatEngine.get_class_skills(player_class)
	var is_ar = GameManager and GameManager.current_language == "ar"
	if skill_1_btn and current_skills.size() > 0:
		var first_skill = CombatEngine.skill_database[current_skills[0]]
		skill_1_btn.text = first_skill["name_ar"] if is_ar else first_skill["name_en"]
		skill_1_btn.visible = true
	elif skill_1_btn:
		skill_1_btn.visible = false
	if skill_2_btn and current_skills.size() > 1:
		var second_skill = CombatEngine.skill_database[current_skills[1]]
		skill_2_btn.text = second_skill["name_ar"] if is_ar else second_skill["name_en"]
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
		var inventory_ui = tree.get_first_node_in_group("inventory_ui")
		if inventory_ui and inventory_ui.has_method("toggle_ui"):
			inventory_ui.toggle_ui()

func _on_blacksmith_pressed() -> void:
	var tree = get_tree()
	if tree:
		var blacksmith_ui = tree.get_first_node_in_group("blacksmith_ui")
		if blacksmith_ui and blacksmith_ui.has_method("open_ui"):
			blacksmith_ui.open_ui()

func _on_settings_pressed() -> void:
	var tree = get_tree()
	if tree:
		var settings_ui = tree.get_first_node_in_group("settings_ui")
		if settings_ui and settings_ui.has_method("toggle_ui"):
			settings_ui.toggle_ui()

func _on_quest_banner_pressed() -> void:
	var tree = get_tree()
	if tree:
		var quest_agent = tree.get_first_node_in_group("quest_agents")
		if quest_agent and quest_agent.has_method("navigate_to_quest_target"):
			quest_agent.navigate_to_quest_target()

func _on_joystick_moved(direction: Vector2) -> void:
	var player = GameManager.player_reference if GameManager else null
	if player and player.has_method("set_joystick_input"):
		player.set_joystick_input(direction)

func _on_quest_updated(_quest_id: String, objective_title: String, progress: int, goal: int, is_done: bool) -> void:
	if quest_title:
		quest_title.text = objective_title
	if quest_progress:
		var is_ar = GameManager and GameManager.current_language == "ar"
		if is_done:
			quest_progress.text = "مكتملة! انقر للاستلام" if is_ar else "Completed! Tap to turn in"
		else:
			quest_progress.text = "التقدم: %d / %d (انقر للملاحة)" % [progress, goal] if is_ar else "Progress: %d / %d (Tap to navigate)" % [progress, goal]

func _on_notification_posted(message: String, is_alert: bool) -> void:
	if notification_label:
		notification_label.text = message
		notification_label.modulate = Color(1, 0.3, 0.3) if is_alert else Color(1, 0.9, 0.4)
		var tween = create_tween()
		notification_label.modulate.a = 1.0
		tween.tween_property(notification_label, "modulate:a", 0.0, 3.5).set_delay(1.5)

func _on_damage_dealt(_target: Node3D, amount: int, is_critical: bool, _position: Vector3) -> void:
	if notification_label and is_critical:
		var is_ar = GameManager and GameManager.current_language == "ar"
		var critical_text = "ضربة حرجة! -%d" % amount if is_ar else "CRITICAL HIT! -%d" % amount
		notification_label.text = critical_text
		notification_label.modulate = Color(1, 0.2, 0.1)

func _on_language_changed(_new_language: String) -> void:
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
	if interact_btn:
		interact_btn.text = "تفاعل" if is_ar else "Interact"
	if attack_btn:
		attack_btn.text = "هجوم" if is_ar else "Attack"
	if jump_btn:
		jump_btn.text = "قفز" if is_ar else "Jump"
	if mount_btn:
		mount_btn.text = "الحصان" if is_ar else "Mount"
