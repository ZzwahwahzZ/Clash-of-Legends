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

func add_item(item_data: Dictionary) -> bool:
	# Try stack with existing item
	if item_data.get("max_stack", 1) > 1:
		for i in range(MAX_SLOTS):
			var slot = slots[i]
			if slot != null and slot["id"] == item_data["id"]:
				var max_s = slot.get("max_stack", 99)
				var cur_q = slot.get("quantity", 1)
				if cur_q < max_s:
					var space = max_s - cur_q
					var to_add = min(space, item_data.get("quantity", 1))
					slot["quantity"] += to_add
					item_data["quantity"] -= to_add
					if item_data["quantity"] <= 0:
						emit_signal("inventory_updated")
						return true
						
	# Put in first empty slot
	for i in range(MAX_SLOTS):
		if slots[i] == null:
			slots[i] = item_data.duplicate(true)
			emit_signal("inventory_updated")
			return true
			
	if GameManager:
		GameManager.post_notification("الحقيبة ممتلئة!" if GameManager.current_language == "ar" else "Inventory is Full!", true)
	return false

func remove_item_at(index: int, quantity: int = 1) -> bool:
	if index < 0 or index >= MAX_SLOTS or slots[index] == null:
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
	var item = slots[index]
	if item.get("type") != "equipment" or not item.has("slot"):
		return false
		
	var target_slot = item["slot"]
	var old_eq = equipment.get(target_slot, null)
	equipment[target_slot] = item
	slots[index] = old_eq
	
	emit_signal("equipment_updated")
	emit_signal("inventory_updated")
	_recalculate_player_stats()
	return true

func equip_item(item: Dictionary) -> bool:
	var slot_name = item.get("slot", "")
	if equipment.has(slot_name):
		equipment[slot_name] = item
		emit_signal("equipment_updated")
		_recalculate_player_stats()
		return true
	return false

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
			total_atk += int(eq.get("attack_bonus", 0))
			total_def += int(eq.get("defense_bonus", 0))
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
		slots = data["slots"]
		if slots.size() < MAX_SLOTS:
			slots.resize(MAX_SLOTS)
	if data.has("equipment") and typeof(data["equipment"]) == TYPE_DICTIONARY:
		equipment = data["equipment"]
	emit_signal("inventory_updated")
	emit_signal("equipment_updated")
	_recalculate_player_stats()
