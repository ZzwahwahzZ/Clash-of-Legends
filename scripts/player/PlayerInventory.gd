extends Node
class_name PlayerInventory

signal inventory_updated()
signal equipment_updated()
signal item_used(item_id: String, effect: String)
signal item_refined(item_id: String, success: bool, new_level: int)

const MAX_SLOTS: int = 40
const MAX_REFINE_LEVEL: int = 12

var slots: Array = []
var equipment: Dictionary = {
	"head": null,
	"armor": null,
	"weapon": null,
	"shield": null,
	"boots": null,
	"necklace": null,
	"ring": null,
	"garment": null,
	"fan": null,
	"tower": null,
	"mount": null
}

func _ready() -> void:
	slots.resize(MAX_SLOTS)
	for i in range(MAX_SLOTS):
		slots[i] = null
	_initialize_starter_items()

func _initialize_starter_items() -> void:
	# Add starter Conquer-style items: HP Potions, Meteors, Starter Weapon & Armor
	add_item({
		"id": "potion_hp_small",
		"name_ar": "جرعة شفاء صغيرة",
		"name_en": "Small Healing Potion",
		"type": "consumable",
		"heal_amount": 120,
		"quantity": 15,
		"max_stack": 50,
		"sell_price": 20,
		"rarity": "normal"
	})
	
	add_item({
		"id": "potion_mp_small",
		"name_ar": "جرعة طاقة صغيرة",
		"name_en": "Small Mana Potion",
		"type": "consumable",
		"mana_amount": 80,
		"quantity": 10,
		"max_stack": 50,
		"sell_price": 20,
		"rarity": "normal"
	})
	
	add_item({
		"id": "meteor_stone",
		"name_ar": "حجر النيزك المقدس",
		"name_en": "Sacred Meteor",
		"type": "material",
		"description_ar": "حجر نيزكي نادر يُستخدم لصقل العتاد عند الحداد",
		"description_en": "Rare celestial stone used for blacksmith equipment refinement",
		"quantity": 5,
		"max_stack": 99,
		"sell_price": 150,
		"rarity": "elite"
	})
	
	# Initial weapon
	equip_item({
		"id": "coronet_trojan_bronze",
		"slot": "weapon",
		"name_ar": "فأس التروجان البرونزي",
		"name_en": "Bronze Trojan Axe",
		"type": "equipment",
		"attack_bonus": 32,
		"defense_bonus": 4,
		"refine_level": 1,
		"sockets": 1,
		"sell_price": 240,
		"rarity": "refined"
	})

func can_add_item(item_data: Dictionary) -> bool:
	var item_id := str(item_data.get("id", "")).strip_edges()
	var quantity := int(item_data.get("quantity", 1))
	var max_stack := maxi(1, int(item_data.get("max_stack", 1)))
	if item_id.is_empty() or quantity <= 0:
		return false

	var remaining := quantity
	if max_stack > 1:
		for slot in slots:
			if slot is Dictionary and str(slot.get("id", "")) == item_id:
				var slot_limit := maxi(1, int(slot.get("max_stack", max_stack)))
				var current_quantity := maxi(0, int(slot.get("quantity", 1)))
				remaining -= maxi(0, slot_limit - current_quantity)
				if remaining <= 0:
					return true

	var empty_slots := 0
	for slot in slots:
		if slot == null:
			empty_slots += 1
	var required_slots := int(ceil(float(remaining) / float(max_stack))) if max_stack > 1 else remaining
	return empty_slots >= required_slots


func add_item(item_data: Dictionary) -> bool:
	if not can_add_item(item_data):
		if GameManager:
			GameManager.post_notification("الحقيبة ممتلئة!" if GameManager.current_language == "ar" else "Inventory is Full!", true)
		return false

	var item_id := str(item_data.get("id", ""))
	var remaining := int(item_data.get("quantity", 1))
	var max_stack := maxi(1, int(item_data.get("max_stack", 1)))

	if max_stack > 1:
		for i in range(MAX_SLOTS):
			var slot: Variant = slots[i]
			if slot is Dictionary and str(slot.get("id", "")) == item_id:
				var slot_limit := maxi(1, int(slot.get("max_stack", max_stack)))
				var current_quantity := maxi(0, int(slot.get("quantity", 1)))
				var space := maxi(0, slot_limit - current_quantity)
				var to_add := mini(space, remaining)
				if to_add > 0:
					slot["quantity"] = current_quantity + to_add
					remaining -= to_add
				if remaining <= 0:
					emit_signal("inventory_updated")
					_notify_source_item_collected(item_data, int(item_data.get("quantity", 1)))
					return true

	while remaining > 0:
		var empty_index := slots.find(null)
		if empty_index < 0:
			# Capacity was preflighted; this is a defensive guard against concurrent mutation.
			return false
		var stack_quantity := mini(max_stack, remaining) if max_stack > 1 else 1
		var new_item := item_data.duplicate(true)
		new_item["quantity"] = stack_quantity
		slots[empty_index] = new_item
		remaining -= stack_quantity

	emit_signal("inventory_updated")
	_notify_source_item_collected(item_data, int(item_data.get("quantity", 1)))
	return true

func _notify_source_item_collected(item_data: Dictionary, quantity: int) -> void:
	var item_id := str(item_data.get("source_item_id", item_data.get("id", "")))
	var item_name := str(item_data.get("source_item_name", item_data.get("name_en", "")))
	for agent in get_tree().get_nodes_in_group("quest_agents"):
		if agent.has_method("on_source_item_collected"):
			agent.on_source_item_collected(item_id, item_name, "", quantity)

func remove_item_at(index: int, quantity: int = 1) -> bool:
	if quantity <= 0 or index < 0 or index >= MAX_SLOTS or slots[index] == null:
		return false
	var slot = slots[index]
	var current_q = slot.get("quantity", 1)
	if current_q <= quantity:
		slots[index] = null
	else:
		slot["quantity"] -= quantity
	emit_signal("inventory_updated")
	return true

func equip_item_from_slot(index: int) -> bool:
	if index < 0 or index >= MAX_SLOTS or slots[index] == null:
		return false
	var item: Dictionary = slots[index]
	if item.get("type") != "equipment" or not item.has("slot"):
		return false
	if not _is_item_compatible(item):
		if GameManager:
			GameManager.post_notification("هذا العتاد غير متوافق مع فئة البطل أو أسلوب سلاحه" if GameManager.current_language == "ar" else "This gear is incompatible with the hero class or weapon style", true)
		return false
	var target_slot := str(item["slot"])
	if not equipment.has(target_slot):
		return false
	var old_eq = equipment.get(target_slot, null)
	equipment[target_slot] = item
	slots[index] = old_eq
	
	emit_signal("equipment_updated")
	emit_signal("inventory_updated")
	_recalculate_player_stats()
	return true

func equip_item(item: Dictionary) -> bool:
	var slot_name := str(item.get("slot", ""))
	if equipment.has(slot_name) and _is_item_compatible(item):
		equipment[slot_name] = item
		emit_signal("equipment_updated")
		_recalculate_player_stats()
		return true
	return false

func _is_item_compatible(item: Dictionary) -> bool:
	var player := get_parent()
	var required_class := str(item.get("class_req", ""))
	if not required_class.is_empty() and player and player.has_method("get_character_class"):
		if str(player.get_character_class()) != required_class:
			return false
	var required_style := str(item.get("weapon_style", ""))
	if not required_style.is_empty() and ClassProgressionManager:
		if str(ClassProgressionManager.selected_weapon_style) != required_style:
			return false
	return true

func unequip_item(slot_name: String) -> bool:
	if not equipment.has(slot_name) or equipment[slot_name] == null:
		return false
	var item = equipment[slot_name]
	if add_item(item):
		equipment[slot_name] = null
		emit_signal("equipment_updated")
		_recalculate_player_stats()
		return true
	return false

func use_item_at(index: int, player: CharacterBody3D) -> bool:
	if index < 0 or index >= MAX_SLOTS or slots[index] == null:
		return false
	var item = slots[index]
	if item.get("type") == "consumable":
		if item.has("heal_amount") and player.has_method("apply_healing"):
			player.apply_healing(item["heal_amount"])
			remove_item_at(index, 1)
			emit_signal("item_used", item["id"], "heal")
			return true
		elif item.has("mana_amount") and player.has_method("restore_mp"):
			player.restore_mp(item["mana_amount"])
			remove_item_at(index, 1)
			emit_signal("item_used", item["id"], "mana")
			return true
	elif item.get("type") == "equipment":
		return equip_item_from_slot(index)
	return false

func sell_item_at(index: int) -> bool:
	if index < 0 or index >= MAX_SLOTS or slots[index] == null:
		return false
	var item = slots[index]
	var unit_price = item.get("sell_price", 10)
	var qty = item.get("quantity", 1)
	var total_gold = unit_price * qty
	
	slots[index] = null
	emit_signal("inventory_updated")
	if GameManager:
		GameManager.add_gold(total_gold)
		var msg_ar = "تم بيع %s مقابل %d ذهب" % [item.get("name_ar", "العنصر"), total_gold]
		var msg_en = "Sold %s for %d Gold" % [item.get("name_en", "Item"), total_gold]
		GameManager.post_notification(msg_ar if GameManager.current_language == "ar" else msg_en, false)
	return true

func get_refine_preview(slot_name: String) -> Dictionary:
	if not equipment.has(slot_name) or equipment[slot_name] == null:
		return {}
	var item: Dictionary = equipment[slot_name]
	var level := int(item.get("refine_level", 0))
	if level >= MAX_REFINE_LEVEL:
		return {"current_level": level, "maxed": true, "gold_cost": 0, "success_chance": 0.0}
	var chances := [1.0, 0.95, 0.90, 0.82, 0.72, 0.62, 0.52, 0.42, 0.32, 0.25, 0.20, 0.15]
	return {
		"current_level": level,
		"next_level": level + 1,
		"maxed": false,
		"gold_cost": 200 * int(pow(level + 1, 2)),
		"success_chance": chances[clampi(level, 0, chances.size() - 1)],
		"meteor_required": 1
	}

func refine_equipment(slot_name: String) -> bool:
	var preview := get_refine_preview(slot_name)
	if preview.is_empty() or preview.get("maxed", false):
		if GameManager:
			GameManager.post_notification("وصل العتاد إلى أقصى مستوى صقل +12" if GameManager.current_language == "ar" else "Equipment is already at maximum refinement +12", true)
		return false
	var meteor_idx := -1
	for i in range(MAX_SLOTS):
		if slots[i] != null and str(slots[i].get("id", "")) == "meteor_stone" and int(slots[i].get("quantity", 1)) > 0:
			meteor_idx = i
			break
	if meteor_idx == -1:
		if GameManager:
			GameManager.post_notification("تحتاج إلى حجر نيزك للصقل!" if GameManager.current_language == "ar" else "You need a Meteor for refinement!", true)
		return false
	var gold_cost := int(preview.gold_cost)
	if not GameManager or not GameManager.spend_gold(gold_cost):
		return false
	remove_item_at(meteor_idx, 1)
	var item: Dictionary = equipment[slot_name]
	var current_refine := int(preview.current_level)
	var next_refine := current_refine + 1
	var success := randf() < float(preview.success_chance)
	if success:
		if not item.has("base_attack_bonus"):
			item["base_attack_bonus"] = int(item.get("attack_bonus", 0))
			item["base_defense_bonus"] = int(item.get("defense_bonus", 0))
			item["base_refine_level"] = current_refine
		var base_level := int(item.get("base_refine_level", 0))
		item["refine_level"] = next_refine
		item["attack_bonus"] = int(item.get("base_attack_bonus", 0)) + (next_refine - base_level) * 12
		item["defense_bonus"] = int(item.get("base_defense_bonus", 0)) + (next_refine - base_level) * 6
		emit_signal("equipment_updated")
		emit_signal("item_refined", item["id"], true, next_refine)
		_recalculate_player_stats()
		if GameManager:
			var txt := "نجح صقل %s إلى المستوى +%d!" % [item.get("name_ar", ""), next_refine]
			GameManager.post_notification(txt if GameManager.current_language == "ar" else "Refinement succeeded: +%d" % next_refine, false)
		return true
	emit_signal("item_refined", item["id"], false, current_refine)
	if GameManager:
		GameManager.post_notification("فشلت محاولة الصقل؛ احتفظ العتاد بمستواه الحالي" if GameManager.current_language == "ar" else "Refinement failed; equipment level was preserved", true)
	return false

func get_upgrade_preview(slot_name: String, upgrade_type: String) -> Dictionary:
	if not equipment.has(slot_name) or equipment[slot_name] == null:
		return {}
	var item: Dictionary = equipment[slot_name]
	var rules := {
		"perfection": {"field":"perfection_level","cap":20,"material":"perfection_stone","base_cost":300},
		"blessing": {"field":"blessing_level","cap":7,"material":"blessing_stone","base_cost":500},
		"enchant": {"field":"enchant_level","cap":5,"material":"enchant_scroll","base_cost":400},
		"purification": {"field":"purification_level","cap":1,"material":"purification_stone","base_cost":800},
		"anima": {"field":"anima_level","cap":3,"material":"anima_core","base_cost":1000}
	}
	if not rules.has(upgrade_type):
		return {}
	var rule: Dictionary = rules[upgrade_type]
	var level := int(item.get(rule.field, 0))
	var material_count := 0
	for stack in slots:
		if stack != null and str(stack.get("id", "")) == str(rule.material):
			material_count += int(stack.get("quantity", 1))
	var maxed := level >= int(rule.cap) or (upgrade_type == "purification" and item.has("purification"))
	return {
		"upgrade_type": upgrade_type,
		"current_level": level,
		"next_level": level + 1,
		"maxed": maxed,
		"material_id": rule.material,
		"material_count": material_count,
		"gold_cost": int(rule.base_cost) * (level + 1),
		"material_required": 1
	}

func apply_equipment_upgrade(slot_name: String, upgrade_type: String, stat_choice: String = "attack") -> bool:
	var preview := get_upgrade_preview(slot_name, upgrade_type)
	if preview.is_empty() or preview.get("maxed", false) or int(preview.material_count) < 1:
		return false
	if stat_choice not in ["attack", "defense"]:
		return false
	if not GameManager or not GameManager.spend_gold(int(preview.gold_cost)):
		return false
	var material_index := -1
	for i in range(MAX_SLOTS):
		if slots[i] != null and str(slots[i].get("id", "")) == str(preview.material_id) and int(slots[i].get("quantity", 1)) > 0:
			material_index = i
			break
	if material_index < 0:
		GameManager.add_gold(int(preview.gold_cost))
		return false
	remove_item_at(material_index, 1)
	var item: Dictionary = equipment[slot_name]
	match upgrade_type:
		"perfection":
			item["perfection_level"] = int(preview.next_level)
			item["attack_bonus"] = int(item.get("attack_bonus", 0)) + 2
			item["defense_bonus"] = int(item.get("defense_bonus", 0)) + 2
		"blessing":
			item["blessing_level"] = int(preview.next_level)
		"enchant":
			item["enchant_level"] = int(preview.next_level)
			if stat_choice == "attack":
				item["enchant_attack_bonus"] = int(item.get("enchant_attack_bonus", 0)) + 5
			else:
				item["enchant_defense_bonus"] = int(item.get("enchant_defense_bonus", 0)) + 3
		"purification":
			item["purification_level"] = 1
			item["purification"] = {"stat": stat_choice, "value": 10 if stat_choice == "attack" else 8}
		"anima":
			item["anima_level"] = int(preview.next_level)
			item["attack_bonus"] = int(item.get("attack_bonus", 0)) + 4
			item["defense_bonus"] = int(item.get("defense_bonus", 0)) + 4
	emit_signal("equipment_updated")
	_recalculate_player_stats()
	return true

func get_total_blessing_reduction() -> float:
	var total_levels := 0
	for item in equipment.values():
		if item is Dictionary:
			total_levels += int(item.get("blessing_level", 0))
	return minf(0.35, float(total_levels) * 0.02)

func insert_gem(slot_name: String, inventory_index: int, socket_index: int) -> bool:
	if not equipment.has(slot_name) or equipment[slot_name] == null:
		return false
	if inventory_index < 0 or inventory_index >= MAX_SLOTS or slots[inventory_index] == null:
		return false
	var item: Dictionary = equipment[slot_name]
	var socket_count := int(item.get("sockets", 0))
	if socket_count <= 0 or socket_index < 0 or socket_index >= socket_count:
		return false
	var gem: Dictionary = slots[inventory_index]
	if str(gem.get("type", "")) != "gem":
		return false
	var socket_gems: Array = item.get("socket_gems", [])
	while socket_gems.size() < socket_count:
		socket_gems.append(null)
	if socket_gems[socket_index] != null:
		return false
	socket_gems[socket_index] = gem.duplicate(true)
	item["socket_gems"] = socket_gems
	remove_item_at(inventory_index, 1)
	emit_signal("equipment_updated")
	_recalculate_player_stats()
	return true

func remove_gem(slot_name: String, socket_index: int, gold_cost: int = 500) -> bool:
	if not equipment.has(slot_name) or equipment[slot_name] == null or gold_cost < 0:
		return false
	var item: Dictionary = equipment[slot_name]
	var socket_gems: Array = item.get("socket_gems", [])
	if socket_index < 0 or socket_index >= socket_gems.size() or socket_gems[socket_index] == null:
		return false
	if not GameManager or not GameManager.spend_gold(gold_cost):
		return false
	var gem: Dictionary = socket_gems[socket_index]
	if not add_item(gem):
		GameManager.add_gold(gold_cost)
		return false
	socket_gems[socket_index] = null
	item["socket_gems"] = socket_gems
	emit_signal("equipment_updated")
	_recalculate_player_stats()
	return true

func _recalculate_player_stats() -> void:
	var total_atk = 0
	var total_def = 0
	for k in equipment.keys():
		var eq = equipment[k]
		if eq != null:
			total_atk += int(eq.get("attack_bonus", 0)) + int(eq.get("enchant_attack_bonus", 0))
			total_def += int(eq.get("defense_bonus", 0)) + int(eq.get("enchant_defense_bonus", 0))
			var purification: Dictionary = eq.get("purification", {})
			if purification.get("stat", "") == "attack":
				total_atk += int(purification.get("value", 0))
			elif purification.get("stat", "") == "defense":
				total_def += int(purification.get("value", 0))
			for gem in eq.get("socket_gems", []):
				if gem is Dictionary:
					total_atk += int(gem.get("attack_bonus", 0))
					total_def += int(gem.get("defense_bonus", 0))
			
	var parent_body = get_parent()
	if parent_body and parent_body.has_method("update_equipment_bonuses"):
		parent_body.update_equipment_bonuses(total_atk, total_def)

func serialize() -> Dictionary:
	return {
		"slots": slots,
		"equipment": equipment
	}

func deserialize(data: Dictionary) -> void:
	if data.has("slots") and typeof(data["slots"]) == TYPE_ARRAY:
		slots = data["slots"].duplicate(true)
		slots.resize(MAX_SLOTS)
	if data.has("equipment") and typeof(data["equipment"]) == TYPE_DICTIONARY:
		var restored_equipment: Dictionary = data["equipment"].duplicate(true)
		for slot_name in equipment.keys():
			if not restored_equipment.has(slot_name):
				restored_equipment[slot_name] = null
		equipment = restored_equipment
	emit_signal("inventory_updated")
	emit_signal("equipment_updated")
	_recalculate_player_stats()
