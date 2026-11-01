extends Area3D
class_name LootDrop3D

signal picked_up(player: CharacterBody3D)

var gold_amount: int = 50
var item_payload: Dictionary = {}
var is_collected: bool = false

@onready var label: Label3D = get_node_or_null("Label3D")
@onready var mesh_instance: MeshInstance3D = get_node_or_null("MeshInstance3D")

func _ready() -> void:
	add_to_group("loot_drops")
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	# Gentle rotation animation
	rotate_y(delta * 2.0)

func setup_loot(data: Dictionary) -> void:
	gold_amount = data.get("gold", 50)
	if data.get("has_item", false) and data.has("item_data") and data["item_data"] != null:
		item_payload = data["item_data"]
		
	if label:
		if not item_payload.is_empty():
			var it_name = item_payload.get("name_ar", "عتاد") if (GameManager and GameManager.current_language == "ar") else item_payload.get("name_en", "Gear")
			label.text = "%s + %d ذهب" % [it_name, gold_amount] if (GameManager and GameManager.current_language == "ar") else "%s + %d Gold" % [it_name, gold_amount]
			label.modulate = Color(1.0, 0.8, 0.2)
		else:
			label.text = "%d ذهب" % gold_amount if (GameManager and GameManager.current_language == "ar") else "%d Gold" % gold_amount
			label.modulate = Color(1.0, 0.95, 0.3)

func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController and not is_collected:
		collect_by_player(body)

func collect_by_player(player: CharacterBody3D) -> void:
	if is_collected:
		return
	is_collected = true
	
	if GameManager:
		GameManager.add_gold(gold_amount)
		if AutoLootManager:
			AutoLootManager.emit_signal("loot_collected", "Gold", gold_amount, true)
			
	if not item_payload.is_empty() and player.has_node("PlayerInventory"):
		var inv: PlayerInventory = player.get_node("PlayerInventory")
		inv.add_item(item_payload)
		if AutoLootManager:
			var n = item_payload.get("name_ar", "عتاد") if (GameManager and GameManager.current_language == "ar") else item_payload.get("name_en", "Gear")
			AutoLootManager.emit_signal("loot_collected", n, 1, false)
			
	emit_signal("picked_up", player)
	queue_free()
