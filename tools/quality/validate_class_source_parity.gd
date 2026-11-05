extends SceneTree

const Database = preload("res://scripts/core/GameContentDatabase.gd")
const EXPECTED_CLASSES := [
	"Trojan", "Warrior", "Archer", "Ninja", "Monk", "Pirate",
	"DragonWarrior", "Windwalker", "Thunderstriker", "WaterTaoist", "FireTaoist"
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var database := Database.new()
	var class_ids := database.get_selectable_class_ids()
	if class_ids.size() != EXPECTED_CLASSES.size():
		push_error("CLASS SOURCE PARITY FAILED: expected 11 selectable classes, got %d: %s" % [class_ids.size(), str(class_ids)])
		quit(1)
		return
	for class_id in EXPECTED_CLASSES:
		if not class_ids.has(class_id):
			push_error("CLASS SOURCE PARITY FAILED: missing selectable class " + class_id)
			quit(1)
			return
		var definition: Dictionary = database.get_class_definition(class_id)
		if str(definition.get("source_family", "")).is_empty() or str(definition.get("source_reference", "")).is_empty():
			push_error("CLASS SOURCE PARITY FAILED: missing provenance for " + class_id)
			quit(1)
			return
	var ninja := database.get_class_definition("Ninja")
	var pirate := database.get_class_definition("Pirate")
	var dragon := database.get_class_definition("DragonWarrior")
	var taoist_water := database.get_class_definition("WaterTaoist")
	var taoist_fire := database.get_class_definition("FireTaoist")
	var monk := database.get_class_definition("Monk")
	var thunder := database.get_class_definition("Thunderstriker")
	if not ninja.weapons.has("scythe") or not ninja.weapons.has("nobunaga_claw"):
		push_error("CLASS SOURCE PARITY FAILED: Ninja source weapon family is incomplete.")
		quit(1)
		return
	if not pirate.weapons.has("rapier") or not pirate.weapons.has("pistol"):
		push_error("CLASS SOURCE PARITY FAILED: Pirate source weapon family is incomplete.")
		quit(1)
		return
	if not dragon.weapons.has("nunchaku"):
		push_error("CLASS SOURCE PARITY FAILED: Dragon-Warrior must use the source Nunchaku family.")
		quit(1)
		return
	if taoist_water.source_family != "Taoist" or taoist_fire.source_family != "Taoist":
		push_error("CLASS SOURCE PARITY FAILED: Water/Fire Taoist must share the Taoist source family.")
		quit(1)
		return
	if not monk.weapons.is_empty() or str(monk.weapon_reference_status).is_empty():
		push_error("CLASS SOURCE PARITY FAILED: Monk weapon uncertainty must remain explicit.")
		quit(1)
		return
	if thunder.source_version != "project-original":
		push_error("CLASS SOURCE PARITY FAILED: Thunderstriker must remain an original project class.")
		quit(1)
		return
	if database.get_class_definition("Taoist").is_empty() or class_ids.has("Taoist") or not database.get_class_ids().has("Taoist"):
		push_error("CLASS SOURCE PARITY FAILED: shared Taoist base family must remain registered but not selectable.")
		quit(1)
		return
	if not database.validate_registry():
		push_error("CLASS SOURCE PARITY FAILED: canonical content registry validation failed.")
		quit(1)
		return
	print("CLASS SOURCE PARITY PASSED: 11 selectable classes, source-backed weapon families, shared Taoist branches and explicit original Thunderstriker.")
	database.free()
	quit(0)
