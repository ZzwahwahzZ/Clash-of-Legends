extends Control
class_name InventoryUI

signal item_selected(slot_index: int)

var selected_slot: int = -1

@onready var grid_container: GridContainer = get_node_or_null("Panel/GridContainer")
@onready var details_label: Label = get_node_or_null("Panel/DetailsPanel/DetailsLabel")
@onready var equip_button: Button = get_node_or_null("Panel/DetailsPanel/EquipButton")
@onready var use_button: Button = get_node_or_null("Panel/DetailsPanel/UseButton")
@onready var sell_button: Button = get_node_or_null("Panel/DetailsPanel/SellButton")
@onready var close_button: Button = get_node_or_null("Panel/CloseButton")
@onready var title_label: Label = get_node_or_null("Panel/TitleLabel")

func _ready() -> void:
	add_to_group("inventory_ui")
	visible = false
	if close_button:
		close_button.pressed.connect(close_ui)
	if equip_button:
		equip_button.pressed.connect(_on_equip_pressed)
	if use_button:
		use_button.pressed.connect(_on_use_pressed)
	if sell_button:
		sell_button.pressed.connect(_on_sell_pressed)
	_apply_localization()

func open_ui() -> void:
	visible = true
	_apply_localization()
	refresh_inventory()

func close_ui() -> void:
	visible = false

func toggle_ui() -> void:
	if visible:
		close_ui()
	else:
		open_ui()

func _apply_localization() -> void:
	var is_ar = GameManager and GameManager.current_language == "ar"
	if title_label:
		title_label.text = "حقيبة البطل [٤٠ خانة]" if is_ar else "Hero Inventory [40 Slots]"
	if equip_button:
		equip_button.text = "ارتداء" if is_ar else "Equip"
	if use_button:
		use_button.text = "استخدام" if is_ar else "Use"
	if sell_button:
		sell_button.text = "بيع" if is_ar else "Sell"
	if close_button:
		close_button.text = "إغلاق" if is_ar else "Close"

func refresh_inventory() -> void:
	var player = GameManager.player_reference if GameManager else null
	if not player or not player.has_node("PlayerInventory"):
		return
		
	var inv: PlayerInventory = player.get_node("PlayerInventory")
	if not grid_container:
		return
		
	# Clear previous children
	for child in grid_container.get_children():
		child.queue_free()
		
	for i in range(PlayerInventory.MAX_SLOTS):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(56, 56)
		var item = inv.slots[i]
		if item != null:
			var is_ar = GameManager and GameManager.current_language == "ar"
			var nm = item.get("name_ar", "") if is_ar else item.get("name_en", "")
			var qty = item.get("quantity", 1)
			btn.text = "%s\nx%d" % [nm.substr(0, 8), qty] if qty > 1 else nm.substr(0, 10)
		else:
			btn.text = "%d" % (i + 1)
		btn.pressed.connect(_on_slot_clicked.bind(i))
		grid_container.add_child(btn)

func _on_slot_clicked(idx: int) -> void:
	selected_slot = idx
	emit_signal("item_selected", idx)
	_update_details(idx)

func _update_details(idx: int) -> void:
	var player = GameManager.player_reference if GameManager else null
	if not player or not player.has_node("PlayerInventory"):
		return
	var inv: PlayerInventory = player.get_node("PlayerInventory")
	var item = inv.slots[idx]
	if not details_label:
		return
		
	if item == null:
		details_label.text = "خانة فارغة" if (GameManager and GameManager.current_language == "ar") else "Empty Slot"
		return
		
	var is_ar = GameManager and GameManager.current_language == "ar"
	var name_str = item.get("name_ar", "") if is_ar else item.get("name_en", "")
	var type_str = item.get("type", "")
	var text = "[%s]\nالنوع: %s\nالكمية: %d\nسعر البيع: %d ذهب" % [
		name_str,
		type_str,
		item.get("quantity", 1),
		item.get("sell_price", 10)
	] if is_ar else "[%s]\nType: %s\nQuantity: %d\nSell Price: %d Gold" % [
		name_str,
		type_str,
		item.get("quantity", 1),
		item.get("sell_price", 10)
	]
	
	if item.has("attack_bonus"):
		text += ("\nهجوم إضافي: +%d" % item["attack_bonus"]) if is_ar else ("\nAttack Bonus: +%d" % item["attack_bonus"])
	if item.has("refine_level"):
		text += ("\nمستوى الصقل: +%d" % item["refine_level"]) if is_ar else ("\nRefine Level: +%d" % item["refine_level"])
	details_label.text = text

func _on_equip_pressed() -> void:
	if selected_slot == -1:
		return
	var player = GameManager.player_reference if GameManager else null
	if player and player.has_node("PlayerInventory"):
		var inv: PlayerInventory = player.get_node("PlayerInventory")
		inv.equip_item_from_slot(selected_slot)
		refresh_inventory()
		_update_details(selected_slot)

func _on_use_pressed() -> void:
	if selected_slot == -1:
		return
	var player = GameManager.player_reference if GameManager else null
	if player and player.has_node("PlayerInventory"):
		var inv: PlayerInventory = player.get_node("PlayerInventory")
		inv.use_item_at(selected_slot, player)
		refresh_inventory()
		_update_details(selected_slot)

func _on_sell_pressed() -> void:
	if selected_slot == -1:
		return
	var player = GameManager.player_reference if GameManager else null
	if player and player.has_node("PlayerInventory"):
		var inv: PlayerInventory = player.get_node("PlayerInventory")
		inv.sell_item_at(selected_slot)
		refresh_inventory()
		_update_details(selected_slot)
