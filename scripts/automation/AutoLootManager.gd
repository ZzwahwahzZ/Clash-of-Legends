extends Node

signal auto_loot_toggled(is_enabled: bool)
signal loot_collected(item_name: String, quantity: int, is_gold: bool)

var is_enabled: bool = true
var loot_radius: float = 8.0
var loot_gold: bool = true
var loot_equipment: bool = true
var loot_materials: bool = true

func _ready() -> void:
	pass

func toggle_auto_loot() -> bool:
	is_enabled = !is_enabled
	if GameManager:
		GameManager.is_auto_looting = is_enabled
		var text_ar = "تم تفعيل الجمع التلقائي للغنائم" if is_enabled else "تم إيقاف الجمع التلقائي للغنائم"
		var text_en = "Auto-Loot Enabled" if is_enabled else "Auto-Loot Disabled"
		GameManager.post_notification(text_ar if GameManager.current_language == "ar" else text_en, false)
	emit_signal("auto_loot_toggled", is_enabled)
	return is_enabled

func _process(delta: float) -> void:
	if not is_enabled:
		return
		
	var player = GameManager.player_reference if GameManager else null
	if not player or not is_instance_valid(player) or player.is_dead:
		return
		
	var tree = get_tree()
	if not tree:
		return
		
	var drops = tree.get_nodes_in_group("loot_drops")
	for drop in drops:
		if is_instance_valid(drop) and not drop.is_queued_for_deletion():
			if not _category_enabled_for(drop):
				continue
			var dist = player.global_position.distance_to(drop.global_position)
			if dist <= loot_radius:
				_collect_drop(drop, player)

func _category_enabled_for(drop: Node) -> bool:
	if drop == null or not is_instance_valid(drop):
		return false
	if not drop.has_method("get_loot_category"):
		return loot_materials
	var category := str(drop.get_loot_category())
	match category:
		"gold": return loot_gold
		"equipment": return loot_equipment
		"material", "gem", "quest": return loot_materials
		_: return loot_materials

func _collect_drop(drop: Area3D, player: CharacterBody3D) -> void:
	if not _category_enabled_for(drop):
		return
	if drop.has_method("collect_by_player"):
		drop.collect_by_player(player)
