extends Node
## Canonical offline content registry. Systems consume the same IDs and data
## instead of maintaining conflicting class, weapon, and skill lists.

const CLASSES := {
 "Trojan":{"name_ar":"تروجان","name_en":"Trojan","weapons":["dual_swords","halberd"],"armor":"heavy"},
 "Warrior":{"name_ar":"محارب","name_en":"Warrior","weapons":["blade","shield"],"armor":"heavy"},
 "Archer":{"name_ar":"رامٍ","name_en":"Archer","weapons":["bow","flying_daggers"],"armor":"light"},
 "Ninja":{"name_ar":"نينجا","name_en":"Ninja","weapons":["katana","claws"],"armor":"light"},
 "Monk":{"name_ar":"راهب","name_en":"Monk","weapons":["staff","beads"],"armor":"medium"},
 "Pirate":{"name_ar":"قرصان","name_en":"Pirate","weapons":["pistol","cutlass"],"armor":"medium"},
 "DragonWarrior":{"name_ar":"محارب التنين","name_en":"Dragon Warrior","weapons":["dragon_blade","dragon_lance"],"armor":"heavy"},
 "Windwalker":{"name_ar":"سائر الرياح","name_en":"Windwalker","weapons":["twin_blades","wind_bow"],"armor":"light"},
 "Thunderstriker":{"name_ar":"صاعق الرعد","name_en":"Thunderstriker","weapons":["thunder_gauntlets","storm_staff"],"armor":"medium"},
 "WaterTaoist":{"name_ar":"طاوي الماء","name_en":"Water Taoist","weapons":["water_fan","jade_wand"],"armor":"cloth"},
 "FireTaoist":{"name_ar":"طاوي النار","name_en":"Fire Taoist","weapons":["fire_staff","flame_orb"],"armor":"cloth"},
 "Taoist":{"name_ar":"طاوي","name_en":"Taoist","weapons":["staff","fan"],"armor":"cloth"}
}

const SKILLS := {
 "archer_shadow_dagger":{"name_ar":"خنجر الظل","name_en":"Shadow Dagger","class_req":"Archer","weapon_style":"flying_daggers","cooldown":2.5,"mp_cost":18,"damage_multiplier":1.8,"range":4.0,"is_aoe":false,"effect":"damage"},
 "archer_eastern_tempest":{"name_ar":"عاصفة الشرق","name_en":"Eastern Tempest","class_req":"Archer","weapon_style":"flying_daggers","cooldown":7.0,"mp_cost":38,"damage_multiplier":2.0,"range":5.0,"is_aoe":true,"aoe_radius":5.5,"effect":"damage"},
 "dragon_warrior_dragon_surge":{"name_ar":"اندفاع التنين","name_en":"Dragon Surge","class_req":"DragonWarrior","cooldown":5.0,"mp_cost":32,"damage_multiplier":2.25,"range":5.0,"is_aoe":true,"aoe_radius":4.5,"effect":"damage"},
 "dragon_warrior_scale_guard":{"name_ar":"درع الحراشف","name_en":"Scale Guard","class_req":"DragonWarrior","cooldown":12.0,"mp_cost":24,"damage_multiplier":0.0,"range":0.0,"effect":"buff_defense"},
 "windwalker_gale_step":{"name_ar":"خطوة العاصفة","name_en":"Gale Step","class_req":"Windwalker","cooldown":4.0,"mp_cost":18,"damage_multiplier":1.7,"range":8.0,"is_aoe":false,"effect":"damage"},
 "windwalker_tempest":{"name_ar":"إعصار الرياح","name_en":"Tempest","class_req":"Windwalker","cooldown":8.0,"mp_cost":38,"damage_multiplier":2.0,"range":12.0,"is_aoe":true,"aoe_radius":6.0,"effect":"damage"},
 "thunderstriker_chain_lightning":{"name_ar":"سلسلة البرق","name_en":"Chain Lightning","class_req":"Thunderstriker","cooldown":6.0,"mp_cost":34,"damage_multiplier":2.1,"range":13.0,"is_aoe":true,"aoe_radius":5.0,"effect":"damage"},
 "thunderstriker_storm_fist":{"name_ar":"قبضة العاصفة","name_en":"Storm Fist","class_req":"Thunderstriker","cooldown":3.0,"mp_cost":16,"damage_multiplier":1.6,"range":3.5,"is_aoe":false,"effect":"damage"},
 "water_taoist_healing_rain":{"name_ar":"مطر الشفاء","name_en":"Healing Rain","class_req":"WaterTaoist","cooldown":5.0,"mp_cost":36,"damage_multiplier":0.0,"range":10.0,"heal_amount":360,"effect":"heal"},
 "water_taoist_jade_barrier":{"name_ar":"حاجز اليشم","name_en":"Jade Barrier","class_req":"WaterTaoist","cooldown":12.0,"mp_cost":30,"damage_multiplier":0.0,"range":0.0,"effect":"buff_defense"},
 "fire_taoist_flame_burst":{"name_ar":"انفجار اللهب","name_en":"Flame Burst","class_req":"FireTaoist","cooldown":4.0,"mp_cost":28,"damage_multiplier":2.2,"range":12.0,"is_aoe":true,"aoe_radius":5.5,"effect":"damage"},
 "fire_taoist_meteor_fall":{"name_ar":"سقوط النيازك","name_en":"Meteor Fall","class_req":"FireTaoist","cooldown":9.0,"mp_cost":48,"damage_multiplier":2.8,"range":14.0,"is_aoe":true,"aoe_radius":7.0,"effect":"damage"}
}

func get_class_ids() -> Array[String]:
 var result: Array[String] = []
 for id in CLASSES.keys(): result.append(str(id))
 return result

func get_class_definition(class_id: String) -> Dictionary:
 return CLASSES.get(class_id, {}).duplicate(true)

func get_skill_database() -> Dictionary:
 return SKILLS.duplicate(true)

func validate_registry() -> bool:
 for class_id in CLASSES:
  if CLASSES[class_id].get("weapons", []).is_empty(): return false
 for skill_id in SKILLS:
  var class_id := str(SKILLS[skill_id].get("class_req", ""))
  if not CLASSES.has(class_id): return false
  if float(SKILLS[skill_id].get("cooldown", -1.0)) < 0.0: return false
  if int(SKILLS[skill_id].get("mp_cost", -1)) < 0: return false
 return true
