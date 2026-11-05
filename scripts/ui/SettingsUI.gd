extends Control
class_name SettingsUI

@onready var lang_option: OptionButton = get_node_or_null("Panel/LangOption")
@onready var class_option: OptionButton = get_node_or_null("Panel/ClassOption")
@onready var save_button: Button = get_node_or_null("Panel/SaveButton")
@onready var load_button: Button = get_node_or_null("Panel/LoadButton")
@onready var close_button: Button = get_node_or_null("Panel/CloseButton")
@onready var resource_packs_button: Button = get_node_or_null("Panel/ResourcePacksButton")
@onready var guide_button: Button = get_node_or_null("Panel/GuideButton")
@onready var title_label: Label = get_node_or_null("Panel/TitleLabel")
@onready var progression_label: Label = get_node_or_null("Panel/ProgressionLabel")
@onready var progression_option: OptionButton = get_node_or_null("Panel/ProgressionOption")
@onready var loot_filters_label: Label = get_node_or_null("Panel/LootFiltersLabel")
@onready var loot_filters_grid: GridContainer = get_node_or_null("Panel/LootFiltersGrid")

func _ready() -> void:
	add_to_group("settings_ui")
	visible = false
	if close_button:
		close_button.pressed.connect(close_ui)
	if resource_packs_button:
		resource_packs_button.pressed.connect(_on_resource_packs_pressed)
	if guide_button:
		guide_button.pressed.connect(_on_guide_pressed)
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if load_button:
		load_button.pressed.connect(_on_load_pressed)
	if lang_option:
		lang_option.item_selected.connect(_on_language_selected)
	if class_option:
		class_option.item_selected.connect(_on_class_selected)
	if progression_option:
		progression_option.item_selected.connect(_on_progression_selected)
	_setup_options()

func open_ui() -> void:
	FeatureGuidanceManager.show_feature_intro("settings")
	visible = true
	_setup_options()

func close_ui() -> void:
	visible = false

func toggle_ui() -> void:
	if visible:
		close_ui()
	else:
		open_ui()

func _setup_options() -> void:
	var is_ar = GameManager and GameManager.current_language == "ar"
	if title_label:
		title_label.text = "إعدادات صراع الأساطير" if is_ar else "Clash of Legends Settings"
	if loot_filters_label:
		loot_filters_label.text = "فلاتر الجمع التلقائي" if is_ar else "Auto-Loot Filters"
	if progression_label:
		progression_label.text = "مسار التقدم" if is_ar else "Progression Path"
	if save_button:
		save_button.text = "حفظ اللعبة محلياً" if is_ar else "Save Game Locally"
	if load_button:
		load_button.text = "استرجاع الحفظ" if is_ar else "Load Saved Game"
	if close_button:
		close_button.text = "إغلاق" if is_ar else "Close"
	if resource_packs_button:
		resource_packs_button.text = "تنزيل موارد اللعبة" if is_ar else "Download Game Resources"
	if guide_button:
		guide_button.text = "دليل اللعب للمبتدئين" if is_ar else "New Player Guide"
		
	if lang_option:
		lang_option.clear()
		lang_option.add_item("العربية (افتراضي)")
		lang_option.set_item_metadata(0, "ar")
		lang_option.add_item("English")
		lang_option.set_item_metadata(1, "en")
		lang_option.selected = 0 if is_ar else 1
		
	if class_option:
		class_option.clear()
		var class_ids := GameContentDatabase.get_selectable_class_ids() if GameContentDatabase else []
		for class_id in class_ids:
			if class_id == "Taoist":
				continue
			var definition: Dictionary = GameContentDatabase.get_class_definition(class_id)
			var display := "%s (%s)" % [definition.get("name_ar", class_id), definition.get("name_en", class_id)] if is_ar else str(definition.get("name_en", class_id))
			class_option.add_item(display)
			class_option.set_item_metadata(class_option.get_item_count() - 1, class_id)
		var player = GameManager.player_reference if GameManager else null
		if player and player.has_method("get_character_class"):
			var current_class: String = str(player.get_character_class())
			for i in range(class_option.get_item_count()):
				if class_option.get_item_metadata(i) == current_class:
					class_option.select(i)
					break
	_setup_progression_options()
	_build_loot_filter_controls()

func _setup_progression_options() -> void:
	if not progression_option:
		return
	progression_option.clear()
	var player = GameManager.player_reference if GameManager else null
	var choices: Array[String] = player.get_available_progression_choices() if player and player.has_method("get_available_progression_choices") else []
	if choices.size() <= 1:
		progression_option.visible = false
		if progression_label:
			progression_label.visible = false
		return
	progression_option.visible = true
	if progression_label:
		progression_label.visible = true
	var selected_choice := str(player.get_selected_progression_choice()) if player and player.has_method("get_selected_progression_choice") else ""
	var labels := {
		"bow":["القوس","Bow"],
		"throwing_knives":["الخناجر الرامية","Throwing Knives"],
		"WaterTaoist":["طاوي الماء","Water Taoist"],
		"FireTaoist":["طاوي النار","Fire Taoist"],
		"Stomper":["ستومبر","Stomper"],
		"Chaser":["تشيسر","Chaser"]
	}
	for choice_id in choices:
		var label_pair: Array = labels.get(choice_id, [choice_id, choice_id])
		var display := "%s (%s)" % [label_pair[0], label_pair[1]] if GameManager and GameManager.current_language == "ar" else str(label_pair[1])
		progression_option.add_item(display)
		var item_index := progression_option.get_item_count() - 1
		progression_option.set_item_metadata(item_index, choice_id)
		if choice_id == selected_choice:
			progression_option.select(item_index)

func _on_progression_selected(index: int) -> void:
	if not progression_option:
		return
	var choice_id := str(progression_option.get_item_metadata(index))
	var player = GameManager.player_reference if GameManager else null
	if player and player.has_method("select_progression_choice"):
		player.select_progression_choice(choice_id)
	_setup_progression_options()

func _build_loot_filter_controls() -> void:
	if not loot_filters_grid or not AutoLootManager:
		return
	for child in loot_filters_grid.get_children():
		loot_filters_grid.remove_child(child)
		child.queue_free()
	var definitions := [
		{"key":"gold","ar":"الذهب","en":"Gold"},
		{"key":"equipment","ar":"المعدات","en":"Equipment"},
		{"key":"materials","ar":"المواد","en":"Materials"},
		{"key":"gems","ar":"الأحجار الكريمة","en":"Gems"},
		{"key":"quest_items","ar":"أغراض المهام","en":"Quest Items"},
		{"key":"consumables","ar":"المستهلكات","en":"Consumables"},
		{"key":"refinement_materials","ar":"مواد التطوير","en":"Refinement"},
		{"key":"crafting_materials","ar":"مواد التصنيع","en":"Crafting"},
		{"key":"cosmetics","ar":"المظاهر","en":"Cosmetics"}
	]
	var settings: Dictionary = AutoLootManager.get_filter_settings()
	var is_ar: bool = GameManager != null and GameManager.current_language == "ar"
	for definition in definitions:
		var filter_key := str(definition.key)
		var checkbox := CheckBox.new()
		checkbox.name = filter_key
		checkbox.text = str(definition.ar) if is_ar else str(definition.en)
		checkbox.button_pressed = bool(settings.get(filter_key, true))
		checkbox.toggled.connect(_on_loot_filter_toggled.bind(filter_key))
		loot_filters_grid.add_child(checkbox)

func _on_loot_filter_toggled(enabled: bool, category: String) -> void:
	if AutoLootManager:
		AutoLootManager.set_category_enabled(category, enabled)

func _on_language_selected(idx: int) -> void:
	if not lang_option or not GameManager:
		return
	var code = lang_option.get_item_metadata(idx)
	GameManager.set_language(code)
	_setup_options()

func _on_class_selected(idx: int) -> void:
	if not class_option or not GameManager:
		return
	var cls_id = class_option.get_item_metadata(idx)
	var player = GameManager.player_reference
	if player and player.has_method("set_character_class"):
		player.set_character_class(cls_id)

func _on_save_pressed() -> void:
	var player = GameManager.player_reference if GameManager else null
	if not player or not LocalSaveEngine:
		return
		
	var inv_data = {}
	if player.has_node("PlayerInventory"):
		var inv: PlayerInventory = player.get_node("PlayerInventory")
		inv_data = inv.serialize()
		
	var p_data = {
		"level": player.current_level,
		"hp": player.current_hp,
		"max_hp": player.max_hp,
		"mp": player.current_mp,
		"max_mp": player.max_mp,
		"xp": player.current_xp,
		"max_xp": player.max_xp,
		"gold": GameManager.current_gold,
		"class": player.get_character_class(),
		"class_progression": ClassProgressionManager.serialize() if ClassProgressionManager else {},
		"position": {"x": player.global_position.x, "y": player.global_position.y, "z": player.global_position.z},
		"inventory": inv_data,
		"quest_agents": LocalSaveEngine.capture_quest_states(),
		"loot_filters": AutoLootManager.get_filter_settings() if AutoLootManager else {}
	}
	LocalSaveEngine.save_game(p_data)

func _on_load_pressed() -> void:
	if not LocalSaveEngine or not GameManager:
		return
	var data = LocalSaveEngine.load_game()
	if data.is_empty():
		return
		
	var player = GameManager.player_reference
	if player:
		player.current_level = data.get("level", 1)
		player.max_hp = data.get("max_hp", 500)
		player.current_hp = data.get("hp", player.max_hp)
		player.max_mp = data.get("max_mp", 200)
		player.current_mp = data.get("mp", player.max_mp)
		player.current_xp = data.get("xp", 0)
		player.max_xp = data.get("max_xp", 1000)
		if data.has("class"):
			player.set_character_class(data["class"])
		if data.has("class_progression") and ClassProgressionManager:
			ClassProgressionManager.deserialize(data["class_progression"])
		if data.has("gold"):
			GameManager.current_gold = data["gold"]
		if data.has("position"):
			var p = data["position"]
			player.global_position = Vector3(p.get("x", 0), p.get("y", 1), p.get("z", 0))
		if data.has("inventory") and player.has_node("PlayerInventory"):
			var inv: PlayerInventory = player.get_node("PlayerInventory")
			inv.deserialize(data["inventory"])
		if data.has("quest_agents") and typeof(data["quest_agents"]) == TYPE_DICTIONARY:
			LocalSaveEngine.restore_quest_states(data["quest_agents"])
		if data.has("loot_filters") and typeof(data["loot_filters"]) == TYPE_DICTIONARY and AutoLootManager:
			AutoLootManager.apply_filter_settings(data["loot_filters"])
			_build_loot_filter_controls()
		player.sync_stats_to_hud()

func _on_resource_packs_pressed() -> void:
	var panel := get_tree().get_first_node_in_group("resource_packs_ui")
	if panel and panel.has_method("open_ui"):
		panel.open_ui()

func _on_guide_pressed() -> void:
	var guide := get_tree().get_first_node_in_group("new_player_guide")
	if guide and guide.has_method("open_guide"):
		guide.open_guide()
