extends Node

signal auto_loot_toggled(is_enabled: bool)
signal loot_collected(item_name: String, quantity: int, is_gold: bool)
signal filters_changed(settings: Dictionary)

var is_enabled: bool = true
var loot_radius: float = 8.0
var loot_gold: bool = true
var loot_equipment: bool = true
var loot_materials: bool = true
var loot_gems: bool = true
var loot_quest_items: bool = true
var loot_consumables: bool = true
var loot_refinement_materials: bool = true
var loot_crafting_materials: bool = true
var loot_cosmetics: bool = true

func _ready() -> void:
	loot_radius = maxf(loot_radius, 1.0)

func toggle_auto_loot() -> bool:
	is_enabled = not is_enabled
	if GameManager:
		GameManager.is_auto_looting = is_enabled
		var text_ar := "تم تفعيل الجمع التلقائي للغنائم" if is_enabled else "تم إيقاف الجمع التلقائي للغنائم"
		var text_en := "Auto-Loot Enabled" if is_enabled else "Auto-Loot Disabled"
		GameManager.post_notification(text_ar if GameManager.current_language == "ar" else text_en, false)
	auto_loot_toggled.emit(is_enabled)
	return is_enabled

func get_filter_settings() -> Dictionary:
	return {
		"gold": loot_gold,
		"equipment": loot_equipment,
		"materials": loot_materials,
		"gems": loot_gems,
		"quest_items": loot_quest_items,
		"consumables": loot_consumables,
		"refinement_materials": loot_refinement_materials,
		"crafting_materials": loot_crafting_materials,
		"cosmetics": loot_cosmetics
	}

func apply_filter_settings(settings: Dictionary) -> void:
	for category in settings.keys():
		set_category_enabled(str(category), bool(settings[category]))

func set_category_enabled(category: String, enabled: bool) -> bool:
	match category:
		"gold": loot_gold = enabled
		"equipment": loot_equipment = enabled
		"materials": loot_materials = enabled
		"gems": loot_gems = enabled
		"quest_items": loot_quest_items = enabled
		"consumables": loot_consumables = enabled
		"refinement_materials": loot_refinement_materials = enabled
		"crafting_materials": loot_crafting_materials = enabled
		"cosmetics": loot_cosmetics = enabled
		_: return false
	filters_changed.emit(get_filter_settings())
	return true

func _process(_delta: float) -> void:
	if not is_enabled:
		return
	var player = GameManager.player_reference if GameManager else null
	if not player or not is_instance_valid(player) or player.is_dead:
		return
	var tree := get_tree()
	if not tree:
		return
	for drop in tree.get_nodes_in_group("loot_drops"):
		if not is_instance_valid(drop) or drop.is_queued_for_deletion():
			continue
		if not _category_enabled_for(drop):
			continue
		if player.global_position.distance_to(drop.global_position) <= loot_radius:
			_collect_drop(drop, player)

func _category_enabled_for(drop: Node) -> bool:
	if drop == null or not is_instance_valid(drop) or not drop.has_method("get_loot_category"):
		return false
	var category := str(drop.get_loot_category())
	match category:
		"gold": return loot_gold
		"equipment": return loot_equipment
		"material": return loot_materials
		"gem": return loot_gems
		"quest": return loot_quest_items
		"consumable": return loot_consumables
		"refinement_material": return loot_refinement_materials
		"crafting_material": return loot_crafting_materials
		"cosmetic": return loot_cosmetics
		_: return false

func _collect_drop(drop: Area3D, player: CharacterBody3D) -> void:
	if not _category_enabled_for(drop):
		return
	if drop.has_method("collect_by_player"):
		drop.collect_by_player(player)
