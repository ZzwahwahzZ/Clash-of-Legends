extends Control
class_name BlacksmithUI

@onready var slot_option: OptionButton = get_node_or_null("Panel/SlotOption")
@onready var info_label: Label = get_node_or_null("Panel/InfoLabel")
@onready var refine_button: Button = get_node_or_null("Panel/RefineButton")
@onready var close_button: Button = get_node_or_null("Panel/CloseButton")
@onready var title_label: Label = get_node_or_null("Panel/TitleLabel")

func _ready() -> void:
	add_to_group("blacksmith_ui")
	visible = false
	if close_button:
		close_button.pressed.connect(close_ui)
	if refine_button:
		refine_button.pressed.connect(_on_refine_pressed)
	if slot_option:
		slot_option.item_selected.connect(_on_slot_selected)
	_setup_options()

func open_ui() -> void:
	visible = true
	_setup_options()
	_update_info()

func close_ui() -> void:
	visible = false

func _setup_options() -> void:
	if not slot_option:
		return
	slot_option.clear()
	var is_ar = GameManager and GameManager.current_language == "ar"
	if title_label:
		title_label.text = "حدادة الأساطير - صقل العتاد" if is_ar else "Legends Blacksmith - Gear Refine"
	if refine_button:
		refine_button.text = "صقل العتاد" if is_ar else "Refine Gear"
	if close_button:
		close_button.text = "إغلاق" if is_ar else "Close"
		
	var slots_display = [
		{"key": "weapon", "label": "السلاح الرئيسي" if is_ar else "Main Weapon"},
		{"key": "armor", "label": "الدرع الجسدي" if is_ar else "Body Armor"},
		{"key": "head", "label": "خوذة الرأس" if is_ar else "Helmet"},
		{"key": "shield", "label": "الترس / السلاح الثانوي" if is_ar else "Shield / Offhand"},
		{"key": "boots", "label": "الأحذية الحربية" if is_ar else "War Boots"}
	]
	
	for s in slots_display:
		slot_option.add_item(s["label"])
		slot_option.set_item_metadata(slot_option.get_item_count() - 1, s["key"])

func _on_slot_selected(_idx: int) -> void:
	_update_info()

func _update_info() -> void:
	if not info_label or not slot_option:
		return
	var player = GameManager.player_reference if GameManager else null
	if not player or not player.has_node("PlayerInventory"):
		return
		
	var inv: PlayerInventory = player.get_node("PlayerInventory")
	var slot_key = slot_option.get_selected_metadata()
	var eq = inv.equipment.get(slot_key, null)
	var is_ar = GameManager and GameManager.current_language == "ar"
	
	if eq == null:
		info_label.text = "لا يوجد عتاد مجهز في هذه الخانة!" if is_ar else "No equipment in this slot!"
		return
		
	var cur_ref = eq.get("refine_level", 0)
	var next_ref = cur_ref + 1
	var gold_cost = next_ref * 200
	var success_chance = int(max(0.35, 1.0 - (cur_ref * 0.12)) * 100)
	
	info_label.text = "[%s]\nالمستوى الحالي: +%d\nالمستوى القادم: +%d\nالمتطلبات: 1 حجر نيزك + %d ذهب\nنسبة النجاح: %d%%" % [
		eq.get("name_ar", "عتاد") if is_ar else eq.get("name_en", "Gear"),
		cur_ref,
		next_ref,
		gold_cost,
		success_chance
	] if is_ar else "[%s]\nCurrent Level: +%d\nNext Level: +%d\nRequirement: 1 Meteor + %d Gold\nSuccess Rate: %d%%" % [
		eq.get("name_ar", "Gear") if is_ar else eq.get("name_en", "Gear"),
		cur_ref,
		next_ref,
		gold_cost,
		success_chance
	]

func _on_refine_pressed() -> void:
	if not slot_option:
		return
	var player = GameManager.player_reference if GameManager else null
	if not player or not player.has_node("PlayerInventory"):
		return
	var inv: PlayerInventory = player.get_node("PlayerInventory")
	var slot_key = slot_option.get_selected_metadata()
	inv.refine_equipment(slot_key)
	_update_info()
