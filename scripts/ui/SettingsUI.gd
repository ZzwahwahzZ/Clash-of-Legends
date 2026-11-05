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
		var class_ids := GameContentDatabase.get_class_ids() if GameContentDatabase else []
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
		"quest_agents": LocalSaveEngine.capture_quest_states()
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
		player.sync_stats_to_hud()

func _on_resource_packs_pressed() -> void:
	var panel := get_tree().get_first_node_in_group("resource_packs_ui")
	if panel and panel.has_method("open_ui"):
		panel.open_ui()

func _on_guide_pressed() -> void:
	var guide := get_tree().get_first_node_in_group("new_player_guide")
	if guide and guide.has_method("open_guide"):
		guide.open_guide()
