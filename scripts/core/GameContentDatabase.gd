extends Node
## Canonical offline content registry. Systems consume the same IDs and data
## instead of maintaining conflicting class, weapon, and skill lists.

const CLASSES := {
	"Trojan": {
		"name_ar":"تروجان", "name_en":"Trojan",
		"weapons":["dual_wield", "cross_saber"], "armor":"heavy",
		"source_family":"Trojan", "source_version":"1.1.2.3",
		"source_reference":"selectcharacter.ini:info1",
		"combat_styles":["dual_wield", "windigo"],
		"reference_mechanics":["dual_weapon_wielding", "cross_saber_epic_weapon", "windigo_level_40"]
	},
	"Warrior": {
		"name_ar":"محارب", "name_en":"Warrior",
		"weapons":["blade", "shield"], "armor":"heavy",
		"source_family":"Warrior", "source_version":"1.1.2.3",
		"source_reference":"selectcharacter.ini:info3",
		"combat_styles":["tank", "shield_defense", "xp_burst"],
		"reference_mechanics":["shield_defense", "high_defense", "xp_skill_burst"]
	},
	"Archer": {
		"name_ar":"رامٍ", "name_en":"Archer",
		"weapons":["bow", "throwing_knives"], "armor":"light",
		"source_family":"Archer", "source_version":"1.1.2.3",
		"source_reference":"selectcharacter.ini:info2",
		"combat_styles":["ranged", "flight", "oriental_assassin"],
		"reference_mechanics":["ranged_bow", "flight_evasion", "throwing_knives_assassin_path"]
	},
	"Ninja": {
		"name_ar":"نينجا", "name_en":"Ninja",
		"weapons":["katana", "scythe", "nobunaga_claw"], "armor":"light",
		"source_family":"Ninja", "source_version":"1.1.2.3",
		"source_reference":"selectcharacter.ini:info4",
		"combat_styles":["dual_katana", "single_target", "area_attack"],
		"reference_mechanics":["dual_katana", "scythe_area_damage", "nobunaga_claw_epic_weapon"]
	},
	"Monk": {
		"name_ar":"راهب", "name_en":"Monk",
		"weapons":[], "armor":"medium",
		"source_family":"Monk/Saint", "source_version":"1.1.2.3",
		"source_reference":"selectcharacter.ini:info5",
		"combat_styles":["martial", "spiritual", "ally_buffs"],
		"reference_mechanics":["physical_martial_skills", "spiritual_skills", "team_buffs"],
		"weapon_reference_status":"No specific weapon family is established by the inspected class-selection text."
	},
	"Pirate": {
		"name_ar":"قرصان", "name_en":"Pirate",
		"weapons":["rapier", "pistol"], "armor":"medium",
		"source_family":"Pirate", "source_version":"1.1.2.3",
		"source_reference":"selectcharacter.ini:info6",
		"combat_styles":["ranged_lock_on", "loot_bonus"],
		"reference_mechanics":["rapier_and_pistol", "increased_item_drops", "half_pk_points"]
	},
	"DragonWarrior": {
		"name_ar":"محارب التنين", "name_en":"Dragon Warrior",
		"weapons":["nunchaku"], "armor":"heavy",
		"source_family":"Dragon-Warrior", "source_version":"1.1.2.3",
		"source_reference":"selectcharacter.ini:info7",
		"combat_styles":["free_style", "flash_shift", "chain_hits"],
		"reference_mechanics":["nunchaku", "flash_shifting", "instant_striking", "range_sweeping", "chain_hits"]
	},
	"Windwalker": {
		"name_ar":"سائر الرياح", "name_en":"Windwalker",
		"weapons":["stomper", "chaser"], "armor":"light",
		"source_family":"Windwalker", "source_version":"1.1.2.3",
		"source_reference":"selectcharacter.ini:info8",
		"combat_styles":["stomper", "chaser"],
		"reference_mechanics":["stomper_melee_branch", "chaser_ranged_branch", "thundercloud_summoning"]
	},
	"Thunderstriker": {
		"name_ar":"صاعق الرعد", "name_en":"Thunderstriker",
		"weapons":["thunder_gauntlets", "storm_staff"], "armor":"medium",
		"source_family":"Original project class", "source_version":"project-original",
		"source_reference":"not present in supplied mobile 1.1.2.3 role-selection list",
		"combat_styles":["chain_lightning", "storm_melee"],
		"reference_mechanics":["original_class_identity", "requires_original_rig_and_skill_design"]
	},
	"WaterTaoist": {
		"name_ar":"طاوي الماء", "name_en":"Water Taoist",
		"weapons":["hossu", "polar_backsword"], "armor":"cloth",
		"source_family":"Taoist", "source_version":"1.1.2.3",
		"source_reference":"selectcharacter.ini:info0/infoII0",
		"combat_styles":["healing", "support"],
		"reference_mechanics":["water_branch_at_level_40", "healing_spells", "ally_buffs"]
	},
	"FireTaoist": {
		"name_ar":"طاوي النار", "name_en":"Fire Taoist",
		"weapons":["hossu", "polar_backsword"], "armor":"cloth",
		"source_family":"Taoist", "source_version":"1.1.2.3",
		"source_reference":"selectcharacter.ini:info0/infoII0",
		"combat_styles":["ranged_magic", "area_damage"],
		"reference_mechanics":["fire_branch_at_level_40", "destructive_spells", "ranged_area_attacks"]
	},
	"Taoist": {
		"name_ar":"طاوي", "name_en":"Taoist", "selectable":false,
		"weapons":["hossu", "polar_backsword"], "armor":"cloth",
		"source_family":"Taoist", "source_version":"1.1.2.3",
		"source_reference":"selectcharacter.ini:info0",
		"combat_styles":["magic", "level_40_branch_choice"],
		"reference_mechanics":["choose_water_or_fire_at_level_40"]
	}
}

const SOURCE_PROFESSION_ID_BY_CLASS := {
	"Taoist": "0",
	"WaterTaoist": "0",
	"FireTaoist": "0",
	"Trojan": "2",
	"Archer": "4",
	"Warrior": "6",
	"Ninja": "8",
	"Monk": "10",
	"Pirate": "12",
	"DragonWarrior": "14",
	"Windwalker": "16",
	# Thunderstriker has two distinct source creation records (20 and 22).
	# They remain unresolved rather than being silently collapsed.
}

func get_source_profession_id(class_id: String) -> String:
	return str(SOURCE_PROFESSION_ID_BY_CLASS.get(class_id, ""))

const SKILLS := {
 "archer_shadow_dagger":{"name_ar":"خنجر الظل","name_en":"Shadow Dagger","class_req":"Archer","weapon_style":"throwing_knives","cooldown":2.5,"mp_cost":18,"damage_multiplier":1.8,"range":4.0,"is_aoe":false,"effect":"damage"},
 "archer_eastern_tempest":{"name_ar":"عاصفة الشرق","name_en":"Eastern Tempest","class_req":"Archer","weapon_style":"throwing_knives","cooldown":7.0,"mp_cost":38,"damage_multiplier":2.0,"range":5.0,"is_aoe":true,"aoe_radius":5.5,"effect":"damage"},
 "dragon_warrior_dragon_surge":{"name_ar":"اندفاع التنين","name_en":"Dragon Surge","class_req":"DragonWarrior","cooldown":5.0,"mp_cost":32,"damage_multiplier":2.25,"range":5.0,"is_aoe":true,"aoe_radius":4.5,"effect":"damage"},
 "dragon_warrior_scale_guard":{"name_ar":"درع الحراشف","name_en":"Scale Guard","class_req":"DragonWarrior","cooldown":12.0,"mp_cost":24,"damage_multiplier":0.0,"range":0.0,"effect":"buff_defense"},
 "windwalker_gale_step":{"name_ar":"خطوة العاصفة","name_en":"Gale Step","class_req":"Windwalker","cooldown":4.0,"mp_cost":18,"damage_multiplier":1.7,"range":8.0,"is_aoe":false,"effect":"damage"},
 "windwalker_tempest":{"name_ar":"إعصار الرياح","name_en":"Tempest","class_req":"Windwalker","cooldown":8.0,"mp_cost":38,"damage_multiplier":2.0,"range":12.0,"is_aoe":true,"aoe_radius":6.0,"effect":"damage"},
 "thunderstriker_chain_lightning":{"name_ar":"سلسلة البرق","name_en":"Chain Lightning","class_req":"Thunderstriker","cooldown":6.0,"mp_cost":34,"damage_multiplier":2.1,"range":13.0,"is_aoe":true,"aoe_radius":5.0,"effect":"damage"},
 "thunderstriker_storm_fist":{"name_ar":"قبضة العاصفة","name_en":"Storm Fist","class_req":"Thunderstriker","cooldown":3.0,"mp_cost":16,"damage_multiplier":1.6,"range":3.5,"is_aoe":false,"effect":"damage"},
 "water_taoist_healing_rain":{"name_ar":"مطر الشفاء","name_en":"Healing Rain","class_req":"WaterTaoist","required_branch":"WaterTaoist","cooldown":5.0,"mp_cost":36,"damage_multiplier":0.0,"range":10.0,"heal_amount":360,"effect":"heal"},
 "water_taoist_jade_barrier":{"name_ar":"حاجز اليشم","name_en":"Jade Barrier","class_req":"WaterTaoist","required_branch":"WaterTaoist","cooldown":12.0,"mp_cost":30,"damage_multiplier":0.0,"range":0.0,"effect":"buff_defense"},
 "fire_taoist_flame_burst":{"name_ar":"انفجار اللهب","name_en":"Flame Burst","class_req":"FireTaoist","required_branch":"FireTaoist","cooldown":4.0,"mp_cost":28,"damage_multiplier":2.2,"range":12.0,"is_aoe":true,"aoe_radius":5.5,"effect":"damage"},
 "fire_taoist_meteor_fall":{"name_ar":"سقوط النيازك","name_en":"Meteor Fall","class_req":"FireTaoist","required_branch":"FireTaoist","cooldown":9.0,"mp_cost":48,"damage_multiplier":2.8,"range":14.0,"is_aoe":true,"aoe_radius":7.0,"effect":"damage"},
 "trojan_windigo":{"name_ar":"وينديجو","name_en":"Windigo","class_req":"Trojan","required_trait":"Windigo","cooldown":10.0,"mp_cost":50,"damage_multiplier":2.7,"range":4.5,"is_aoe":true,"aoe_radius":5.5,"effect":"damage"},
 "windwalker_stomper_crush":{"name_ar":"سحق ستومبر","name_en":"Stomper Crush","class_req":"Windwalker","required_branch":"Stomper","cooldown":5.0,"mp_cost":28,"damage_multiplier":2.25,"range":4.0,"is_aoe":true,"aoe_radius":4.5,"effect":"damage"},
 "windwalker_chaser_thundercloud":{"name_ar":"سحابة تشيسر الرعدية","name_en":"Chaser Thundercloud","class_req":"Windwalker","required_branch":"Chaser","cooldown":7.0,"mp_cost":36,"damage_multiplier":2.1,"range":12.0,"is_aoe":true,"aoe_radius":6.0,"effect":"damage"}
}

func get_class_ids() -> Array[String]:
 var result: Array[String] = []
 for id in CLASSES.keys():
  result.append(str(id))
 return result

func get_selectable_class_ids() -> Array[String]:
 var result: Array[String] = []
 for id in CLASSES.keys():
  if bool(CLASSES[id].get("selectable", true)):
   result.append(str(id))
 return result

func get_class_definition(class_id: String) -> Dictionary:
 return CLASSES.get(class_id, {}).duplicate(true)

func get_skill_database() -> Dictionary:
 return SKILLS.duplicate(true)

func validate_registry() -> bool:
 for class_id in CLASSES:
  var definition: Dictionary = CLASSES[class_id]
  if definition.get("weapons", []).is_empty() and definition.get("combat_styles", []).is_empty(): return false
  if str(definition.get("source_family", "")).is_empty() or str(definition.get("source_reference", "")).is_empty(): return false
 for skill_id in SKILLS:
  var class_id := str(SKILLS[skill_id].get("class_req", ""))
  if not CLASSES.has(class_id): return false
  if float(SKILLS[skill_id].get("cooldown", -1.0)) < 0.0: return false
  if int(SKILLS[skill_id].get("mp_cost", -1)) < 0: return false
 return true
