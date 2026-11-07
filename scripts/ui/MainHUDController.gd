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
@onready var quest_description: Label = get_node_or_null("TopRight/QuestBanner/QuestDescription")

@onready var auto_hunt_btn: Button = get_node_or_null("TopRight/AutoControls/AutoHuntBtn")
@onready var auto_loot_btn: Button = get_node_or_null("TopRight/AutoControls/AutoLootBtn")

@onready var inv_btn: Button = get_node_or_null("TopRight/MenuButtons/InvBtn")
@onready var blacksmith_btn: Button = get_node_or_null("TopRight/MenuButtons/BlacksmithBtn")
@onready var settings_btn: Button = get_node_or_null("TopRight/MenuButtons/SettingsBtn")
@onready var travel_btn: Button = get_node_or_null("TopRight/MenuButtons/TravelBtn")
@onready var interact_btn: Button = get_node_or_null("BottomLeft/InteractBtn")

@onready var attack_btn: Button = get_node_or_null("BottomRight/ActionButtons/AttackBtn")
@onready var skill_1_btn: Button = get_node_or_null("BottomRight/ActionButtons/Skill1Btn")
@onready var skill_2_btn: Button = get_node_or_null("BottomRight/ActionButtons/Skill2Btn")
@onready var jump_btn: Button = get_node_or_null("BottomRight/UtilityButtons/JumpBtn")
@onready var mount_btn: Button = get_node_or_null("BottomRight/UtilityButtons/MountBtn")

@onready var joystick: VirtualJoystickController = get_node_or_null("BottomLeft/VirtualJoystick")
@onready var notification_label: Label = get_node_or_null("Center/NotificationLabel")

var current_skills: Array[String] = []
var travel_panel: PanelContainer = null
var travel_list: VBoxContainer = null

func _ready() -> void:
	if GameManager:
		GameManager.player_stats_changed.connect(_on_player_stats_changed)
		GameManager.player_registered.connect(_on_player_registered)
		GameManager.quest_updated.connect(_on_quest_updated)
		GameManager.quest_description_changed.connect(_on_quest_description_changed)
		GameManager.notification_posted.connect(_on_notification_posted)
		GameManager.language_changed.connect(_on_language_changed)

	if CombatEngine:
		CombatEngine.damage_dealt.connect(_on_damage_dealt)
	if ClassProgressionManager:
		ClassProgressionManager.weapon_style_changed.connect(_on_weapon_style_changed)
		ClassProgressionManager.progression_unlocked.connect(_on_progression_unlocked)

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
	if travel_btn:
		travel_btn.pressed.connect(_on_travel_pressed)
	_build_travel_panel()
	if quest_banner:
		quest_banner.pressed.connect(_on_quest_banner_pressed)
	if interact_btn:
		interact_btn.pressed.connect(_on_interact_pressed)
		interact_btn.visible = false
	if joystick:
		joystick.joystick_moved.connect(_on_joystick_moved)

	_refresh_hud_labels()
	_update_skill_buttons()
	_update_interact_button()

func _on_player_registered(_player: CharacterBody3D) -> void:
	_update_skill_buttons()

func _on_weapon_style_changed(_style_id: String) -> void:
	_update_skill_buttons()

func _on_progression_unlocked(_path_id: String) -> void:
	_update_skill_buttons()

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
	FeatureGuidanceManager.show_feature_intro("interact")
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
	FeatureGuidanceManager.show_feature_intro("skills")
	if current_skills.size() > 0:
		_cast_skill(current_skills[0])

func _on_skill_2_pressed() -> void:
	FeatureGuidanceManager.show_feature_intro("skills")
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
	FeatureGuidanceManager.show_feature_intro("mount")
	var player = GameManager.player_reference if GameManager else null
	if player and player.has_method("toggle_mount"):
		player.toggle_mount()

func _on_auto_hunt_pressed() -> void:
	FeatureGuidanceManager.show_feature_intro("auto_hunt")
	if AutoHuntManager:
		var active = AutoHuntManager.toggle_auto_hunt()
		if auto_hunt_btn:
			auto_hunt_btn.modulate = Color(0.4, 1.0, 0.4) if active else Color(1, 1, 1)

func _on_auto_loot_pressed() -> void:
	FeatureGuidanceManager.show_feature_intro("auto_loot")
	if AutoLootManager:
		var active = AutoLootManager.toggle_auto_loot()
		if auto_loot_btn:
			auto_loot_btn.modulate = Color(0.4, 1.0, 0.4) if active else Color(1, 1, 1)

func _on_inventory_pressed() -> void:
	FeatureGuidanceManager.show_feature_intro("inventory")
	var tree = get_tree()
	if tree:
		var inventory_ui = tree.get_first_node_in_group("inventory_ui")
		if inventory_ui and inventory_ui.has_method("toggle_ui"):
			inventory_ui.toggle_ui()

func _on_blacksmith_pressed() -> void:
	FeatureGuidanceManager.show_feature_intro("blacksmith")
	var tree = get_tree()
	if tree:
		var blacksmith_ui = tree.get_first_node_in_group("blacksmith_ui")
		if blacksmith_ui and blacksmith_ui.has_method("open_ui"):
			blacksmith_ui.open_ui()

func _on_settings_pressed() -> void:
	FeatureGuidanceManager.show_feature_intro("settings")
	var tree = get_tree()
	if tree:
		var settings_ui = tree.get_first_node_in_group("settings_ui")
		if settings_ui and settings_ui.has_method("toggle_ui"):
			settings_ui.toggle_ui()

func _build_travel_panel() -> void:
	travel_panel = PanelContainer.new()
	travel_panel.name = "InstantTravelPanel"
	travel_panel.visible = false
	travel_panel.set_anchors_preset(Control.PRESET_CENTER)
	travel_panel.position = Vector2(-175, -190)
	travel_panel.custom_minimum_size = Vector2(350, 380)
	travel_panel.z_index = 30
	add_child(travel_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	travel_panel.add_child(outer)
	var heading := Label.new()
	heading.text = "خريطة العالم والانتقال اللحظي" if GameManager.current_language == "ar" else "World Map & Instant Travel"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(heading)
	travel_list = VBoxContainer.new()
	travel_list.add_theme_constant_override("separation", 5)
	outer.add_child(travel_list)
	var close_button := Button.new()
	close_button.text = "إغلاق" if GameManager.current_language == "ar" else "Close"
	close_button.pressed.connect(func(): travel_panel.visible = false)
	outer.add_child(close_button)
	_refresh_travel_destinations()

func _refresh_travel_destinations() -> void:
	if travel_list == null:
		return
	for child in travel_list.get_children():
		child.queue_free()
	var manager := get_tree().get_first_node_in_group("world_travel_manager")
	if manager == null:
		var missing := Label.new()
		missing.text = "نظام النقل غير متاح" if GameManager.current_language == "ar" else "Travel system unavailable"
		travel_list.add_child(missing)
		return
	var destinations: Dictionary = manager.get_destinations()
	for destination_id in destinations:
		var data: Dictionary = destinations[destination_id]
		var is_ar := GameManager.current_language == "ar"
		var button := Button.new()
		var title := str(data.get("name_ar", destination_id)) if is_ar else str(data.get("name_en", destination_id))
		var description := str(data.get("description_ar", "")) if is_ar else str(data.get("description_en", ""))
		button.text = title + "  —  " + description
		button.custom_minimum_size = Vector2(0, 38)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_travel_destination_selected.bind(str(destination_id)))
		travel_list.add_child(button)

func _on_travel_pressed() -> void:
	if travel_panel == null:
		_build_travel_panel()
	_refresh_travel_destinations()
	travel_panel.visible = not travel_panel.visible

func _on_travel_destination_selected(destination_id: String) -> void:
	var manager := get_tree().get_first_node_in_group("world_travel_manager")
	if manager and manager.has_method("travel_to"):
		if manager.travel_to(destination_id, "manual"):
			travel_panel.visible = false

func _on_quest_banner_pressed() -> void:
	FeatureGuidanceManager.show_feature_intro("quest")
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
			quest_progress.text = "اكتملت وأضيفت المكافأة تلقائياً" if is_ar else "Completed; reward added automatically"
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
	var agent := get_tree().get_first_node_in_group("quest_agents")
	if agent and agent.has_method("get_active_quest"):
		var quest: Dictionary = agent.get_active_quest()
		var is_ar := GameManager.current_language == "ar"
		if quest_title:
			quest_title.text = str(quest.get("title_ar", "")) if is_ar else str(quest.get("title_en", ""))
		if quest_description:
			quest_description.text = str(quest.get("desc_ar", "")) if is_ar else str(quest.get("desc_en", ""))

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
	if travel_btn:
		travel_btn.text = "الخريطة" if is_ar else "World Map"
	if travel_panel and travel_panel.visible:
		_refresh_travel_destinations()
	if interact_btn:
		interact_btn.text = "تفاعل" if is_ar else "Interact"
	if attack_btn:
		attack_btn.text = "هجوم" if is_ar else "Attack"
	if jump_btn:
		jump_btn.text = "قفز" if is_ar else "Jump"
	if mount_btn:
		mount_btn.text = "الحصان" if is_ar else "Mount"

func _on_quest_description_changed(description: String) -> void:
	if quest_description:
		quest_description.text = description
