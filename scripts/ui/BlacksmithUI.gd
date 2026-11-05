extends Control
class_name BlacksmithUI

@onready var slot_option: OptionButton = get_node_or_null("Panel/SlotOption")
@onready var upgrade_option: OptionButton = get_node_or_null("Panel/UpgradeOption")
@onready var stat_option: OptionButton = get_node_or_null("Panel/StatOption")
@onready var info_label: Label = get_node_or_null("Panel/InfoLabel")
@onready var refine_button: Button = get_node_or_null("Panel/RefineButton")
@onready var upgrade_button: Button = get_node_or_null("Panel/UpgradeButton")
@onready var close_button: Button = get_node_or_null("Panel/CloseButton")
@onready var title_label: Label = get_node_or_null("Panel/TitleLabel")

func _ready() -> void:
	add_to_group("blacksmith_ui")
	visible = false
	if close_button:
		close_button.pressed.connect(close_ui)
	if refine_button:
		refine_button.pressed.connect(_on_refine_pressed)
	if upgrade_button:
		upgrade_button.pressed.connect(_on_upgrade_pressed)
	if slot_option:
		slot_option.item_selected.connect(_on_selection_changed)
	if upgrade_option:
		upgrade_option.item_selected.connect(_on_selection_changed)
	if stat_option:
		stat_option.item_selected.connect(_on_selection_changed)
	_setup_options()

func open_ui() -> void:
	FeatureGuidanceManager.show_feature_intro("blacksmith")
	visible = true
	_setup_options()
	_update_info()

func close_ui() -> void:
	visible = false

func _setup_options() -> void:
	if not slot_option:
		return
	var is_ar := GameManager == null or GameManager.current_language == "ar"
	slot_option.clear()
	if title_label:
		title_label.text = "حدادة الأساطير - تطوير العتاد" if is_ar else "Legends Blacksmith - Gear Progression"
	if refine_button:
		refine_button.text = "صقل +1 إلى +12" if is_ar else "Refine +1 to +12"
	if upgrade_button:
		upgrade_button.text = "تنفيذ التطوير" if is_ar else "Apply Upgrade"
	if close_button:
		close_button.text = "إغلاق" if is_ar else "Close"
	var slots_display := [
		{"key":"weapon","label":"السلاح الرئيسي" if is_ar else "Main Weapon"},
		{"key":"armor","label":"الدرع الجسدي" if is_ar else "Body Armor"},
		{"key":"head","label":"خوذة الرأس" if is_ar else "Headgear"},
		{"key":"shield","label":"الترس / السلاح الثانوي" if is_ar else "Shield / Offhand"},
		{"key":"boots","label":"الأحذية الحربية" if is_ar else "War Boots"},
		{"key":"necklace","label":"القلادة" if is_ar else "Necklace"},
		{"key":"ring","label":"الخاتم" if is_ar else "Ring"},
		{"key":"garment","label":"الزي الخارجي" if is_ar else "Garment"},
		{"key":"fan","label":"المروحة" if is_ar else "Fan"},
		{"key":"tower","label":"البرج الدفاعي" if is_ar else "Tower"},
		{"key":"mount","label":"المطية" if is_ar else "Mount"}
	]
	for entry in slots_display:
		slot_option.add_item(entry.label)
		slot_option.set_item_metadata(slot_option.get_item_count() - 1, entry.key)
	if upgrade_option:
		upgrade_option.clear()
		var upgrade_types := [
			{"id":"perfection","ar":"الكمال","en":"Perfection"},
			{"id":"blessing","ar":"البركة","en":"Blessing"},
			{"id":"enchant","ar":"التعويذة","en":"Enchant"},
			{"id":"purification","ar":"التطهير","en":"Purification"},
			{"id":"anima","ar":"الأنِيما","en":"Anima"}
		]
		for entry in upgrade_types:
			upgrade_option.add_item(entry.ar if is_ar else entry.en)
			upgrade_option.set_item_metadata(upgrade_option.get_item_count() - 1, entry.id)
	if stat_option:
		stat_option.clear()
		stat_option.add_item("هجوم" if is_ar else "Attack")
		stat_option.set_item_metadata(0, "attack")
		stat_option.add_item("دفاع" if is_ar else "Defense")
		stat_option.set_item_metadata(1, "defense")

func _on_selection_changed(_index: int) -> void:
	_update_info()

func _update_info() -> void:
	if not info_label or not slot_option:
		return
	var player = GameManager.player_reference if GameManager else null
	if not player or not player.has_node("PlayerInventory"):
		info_label.text = "لا يوجد بطل نشط" if GameManager.current_language == "ar" else "No active hero"
		return
	var inv: PlayerInventory = player.get_node("PlayerInventory")
	var slot_key := str(slot_option.get_selected_metadata())
	var eq = inv.equipment.get(slot_key, null)
	var is_ar := GameManager == null or GameManager.current_language == "ar"
	if eq == null:
		info_label.text = "لا يوجد عتاد مجهز في هذه الخانة!" if is_ar else "No equipment in this slot!"
		if upgrade_button:
			upgrade_button.disabled = true
		if refine_button:
			refine_button.disabled = true
		return
	var lines: Array[String] = []
	var item_name := str(eq.get("name_ar", "عتاد")) if is_ar else str(eq.get("name_en", "Gear"))
	lines.append("[%s]" % item_name)
	var refine := inv.get_refine_preview(slot_key)
	if refine.get("maxed", false):
		lines.append("الصقل: +12 (الحد الأقصى)" if is_ar else "Refinement: +12 (maximum)")
	else:
		lines.append(("الصقل: +%d ← +%d | حجر نيزك واحد | %d ذهب | نجاح %d%%" if is_ar else "Refine: +%d → +%d | 1 Meteor | %d Gold | %d%% success") % [int(refine.current_level), int(refine.next_level), int(refine.gold_cost), int(float(refine.success_chance) * 100.0)])
	var upgrade_id := str(upgrade_option.get_selected_metadata()) if upgrade_option else "perfection"
	var upgrade := inv.get_upgrade_preview(slot_key, upgrade_id)
	var stat_id := str(stat_option.get_selected_metadata()) if stat_option else "attack"
	if upgrade.is_empty():
		lines.append("بيانات التطوير غير متاحة" if is_ar else "Upgrade data unavailable")
	elif upgrade.get("maxed", false):
		lines.append("التطوير المختار وصل للحد الأقصى" if is_ar else "Selected upgrade is at maximum")
	else:
		var material := str(upgrade.material_id)
		lines.append(("التطوير: %s | المستوى %d ← %d | %s (%d/1) | %d ذهب | اختيار: %s" if is_ar else "Upgrade: %s | Level %d → %d | %s (%d/1) | %d Gold | Stat: %s") % [upgrade_id, int(upgrade.current_level), int(upgrade.next_level), material, int(upgrade.material_count), int(upgrade.gold_cost), stat_id])
	info_label.text = "\n".join(lines)
	if refine_button:
		refine_button.disabled = refine.is_empty() or bool(refine.get("maxed", false))
	if upgrade_button:
		upgrade_button.disabled = upgrade.is_empty() or bool(upgrade.get("maxed", false)) or int(upgrade.get("material_count", 0)) < 1

func _on_refine_pressed() -> void:
	var player = GameManager.player_reference if GameManager else null
	if not player or not player.has_node("PlayerInventory") or not slot_option:
		return
	var inv: PlayerInventory = player.get_node("PlayerInventory")
	inv.refine_equipment(str(slot_option.get_selected_metadata()))
	_update_info()

func _on_upgrade_pressed() -> void:
	var player = GameManager.player_reference if GameManager else null
	if not player or not player.has_node("PlayerInventory") or not slot_option or not upgrade_option:
		return
	var inv: PlayerInventory = player.get_node("PlayerInventory")
	var slot_key := str(slot_option.get_selected_metadata())
	var upgrade_id := str(upgrade_option.get_selected_metadata())
	var stat_id := str(stat_option.get_selected_metadata()) if stat_option else "attack"
	if not inv.apply_equipment_upgrade(slot_key, upgrade_id, stat_id):
		if GameManager:
			GameManager.post_notification("تحقق من المادة والذهب وحد التطوير" if GameManager.current_language == "ar" else "Check the required material, Gold and upgrade cap", true)
	_update_info()
