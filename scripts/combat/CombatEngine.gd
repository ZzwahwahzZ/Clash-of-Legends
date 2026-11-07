extends Node

signal skill_executed(skill_id: String, caster: Node3D, target: Node3D, value: int, is_critical: bool)
signal damage_dealt(target: Node3D, amount: int, is_critical: bool, hit_position: Vector3)

# Prototype entries only. The complete, version-pinned skill catalogue remains
# a separate data-audit task; weapon tags below enforce the Archer's bow path.
var skill_database: Dictionary = {
	"trojan_cyclone": {"name_ar":"إعصار التروجان","name_en":"Trojan Cyclone","class_req":"Trojan","cooldown":4.0,"mp_cost":25,"damage_multiplier":1.9,"range":4.5,"is_aoe":true,"aoe_radius":5.0,"effect":"damage"},
	"trojan_fast_blade": {"name_ar":"السيف الخاطف","name_en":"Fast Blade","class_req":"Trojan","cooldown":2.5,"mp_cost":15,"damage_multiplier":1.5,"range":3.0,"is_aoe":false,"effect":"damage"},
	"warrior_flying_dragon": {"name_ar":"التنين الطائر","name_en":"Flying Dragon","class_req":"Warrior","cooldown":5.0,"mp_cost":30,"damage_multiplier":2.2,"range":4.0,"is_aoe":false,"effect":"damage"},
	"warrior_shield_block": {"name_ar":"درع الصمود","name_en":"Shield Block","class_req":"Warrior","cooldown":8.0,"mp_cost":20,"damage_multiplier":0.0,"range":0.0,"is_aoe":false,"effect":"buff_defense"},
	"archer_rapid_arrow": {"name_ar":"السهم السريع","name_en":"Rapid Arrow","class_req":"Archer","weapon_style":"bow","cooldown":2.0,"mp_cost":12,"damage_multiplier":1.4,"range":16.0,"is_aoe":false,"effect":"damage"},
	"archer_scatter": {"name_ar":"السهام المتناثرة","name_en":"Scatter Arrows","class_req":"Archer","weapon_style":"bow","cooldown":6.0,"mp_cost":35,"damage_multiplier":1.7,"range":14.0,"is_aoe":true,"aoe_radius":7.0,"effect":"damage"},
	"taoist_thunder": {"name_ar":"الصاعقة السماوية","name_en":"Thunderbolt","class_req":"Taoist","cooldown":3.0,"mp_cost":25,"damage_multiplier":2.0,"range":12.0,"is_aoe":false,"effect":"damage"},
	"taoist_heal": {"name_ar":"الشفاء المقدس","name_en":"Holy Heal","class_req":"Taoist","cooldown":4.0,"mp_cost":30,"damage_multiplier":0.0,"range":10.0,"is_aoe":false,"heal_amount":280,"effect":"heal"},
	"ninja_fatal_strike": {"name_ar":"الضربة القاضية","name_en":"Fatal Strike","class_req":"Ninja","cooldown":3.5,"mp_cost":28,"damage_multiplier":2.4,"range":3.5,"is_aoe":false,"effect":"damage"},
	"monk_whirlwind": {"name_ar":"إعصار الراهب","name_en":"Monk Whirlwind","class_req":"Monk","cooldown":4.5,"mp_cost":30,"damage_multiplier":1.8,"range":4.5,"is_aoe":true,"aoe_radius":6.0,"effect":"damage"},
	"pirate_cannon": {"name_ar":"قذيفة المدفع","name_en":"Cannon Blast","class_req":"Pirate","cooldown":5.0,"mp_cost":35,"damage_multiplier":2.3,"range":11.0,"is_aoe":true,"aoe_radius":4.5,"effect":"damage"}
}

var cooldown_trackers: Dictionary = {}

func _ready() -> void:
	if GameContentDatabase:
		for skill_id in GameContentDatabase.get_skill_database():
			skill_database[skill_id] = GameContentDatabase.get_skill_database()[skill_id]

func _process(delta: float) -> void:
	for skill_id in cooldown_trackers.keys():
		cooldown_trackers[skill_id] = max(0.0, cooldown_trackers[skill_id] - delta)

func is_skill_compatible(skill_definition: Dictionary) -> bool:
	if ClassProgressionManager:
		return ClassProgressionManager.is_skill_compatible(skill_definition)
	return true

func can_cast_skill(skill_id: String, caster: CharacterBody3D) -> bool:
	if not skill_database.has(skill_id):
		return false
	var def = skill_database[skill_id]
	if ClassProgressionManager:
		if not ClassProgressionManager.is_class_compatible(str(def.get("class_req", ""))):
			return false
	elif caster.has_method("get_character_class") and caster.get_character_class() != def["class_req"]:
		return false
	if not is_skill_compatible(def):
		return false
	if cooldown_trackers.get(skill_id, 0.0) > 0.0:
		return false
	if caster.has_method("get_mp") and caster.get_mp() < def["mp_cost"]:
		return false
	return true

func execute_skill(skill_id: String, caster: CharacterBody3D, target: Node3D) -> bool:
	if not can_cast_skill(skill_id, caster):
		return false
	var def = skill_database[skill_id]
	if def.get("effect", "") == "form_toggle":
		if not ClassProgressionManager:
			return false
		var target_style := "throwing_knives" if ClassProgressionManager.selected_weapon_style == "bow" else "bow"
		if not ClassProgressionManager.select_weapon_style(target_style):
			if GameManager:
				GameManager.post_notification("تحتاج إلى تجهيز سلاح الخناجر الرامية أولاً" if GameManager.current_language == "ar" else "Equip a Throwing Knife in the Assassin loadout first", true)
			return false
		cooldown_trackers[skill_id] = 0.0
		emit_signal("skill_executed", skill_id, caster, caster, 0, false)
		return true
	cooldown_trackers[skill_id] = def["cooldown"]
	if caster.has_method("consume_mp"):
		caster.consume_mp(def["mp_cost"])
	if def["effect"] == "heal":
		var heal_val = def.get("heal_amount", 200)
		if caster.has_method("apply_healing"):
			caster.apply_healing(heal_val)
		if GameAudioManager:
			GameAudioManager.play_skill(skill_id, caster, caster)
		emit_signal("skill_executed", skill_id, caster, caster, heal_val, false)
		return true
	if def["effect"] == "buff_defense":
		if caster.has_method("apply_defense_buff"):
			caster.apply_defense_buff(12.0)
		if GameAudioManager:
			GameAudioManager.play_skill(skill_id, caster, caster)
		emit_signal("skill_executed", skill_id, caster, caster, 0, false)
		return true
	if target and is_instance_valid(target) and target.has_method("take_damage"):
		var base_dmg = 35
		if caster.has_method("get_attack_power"):
			base_dmg = caster.get_attack_power()
		var is_critical = randf() < 0.22
		var crit_mult = 1.75 if is_critical else 1.0
		var final_dmg = int(base_dmg * def["damage_multiplier"] * crit_mult)
		target.take_damage(final_dmg, caster)
		if GameAudioManager:
			GameAudioManager.play_skill(skill_id, caster, target)
		emit_signal("damage_dealt", target, final_dmg, is_critical, target.global_position + Vector3(0, 1.2, 0))
		emit_signal("skill_executed", skill_id, caster, target, final_dmg, is_critical)
		if def.get("is_aoe", false):
			var radius = def.get("aoe_radius", 5.0)
			var tree = get_tree()
			if tree:
				for m in tree.get_nodes_in_group("enemies"):
					if m != target and is_instance_valid(m) and m.global_position.distance_to(target.global_position) <= radius:
						var splash_dmg = int(final_dmg * 0.75)
						m.take_damage(splash_dmg, caster)
						emit_signal("damage_dealt", m, splash_dmg, false, m.global_position + Vector3(0, 1.2, 0))
		return true
	return false

func get_class_skills(target_class: String) -> Array[String]:
	var result: Array[String] = []
	for skill_id in skill_database.keys():
		var definition: Dictionary = skill_database[skill_id]
		if str(definition.get("class_req", "")) != target_class:
			continue
		if ClassProgressionManager and not ClassProgressionManager.is_skill_compatible(definition):
			continue
		result.append(str(skill_id))
	# Path of Shadow must remain reachable in both forms after promotion.
	if result.has("archer_path_of_shadow"):
		result.erase("archer_path_of_shadow")
		result.push_front("archer_path_of_shadow")
	return result
