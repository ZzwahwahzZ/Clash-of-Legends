extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager_script = load("res://scripts/automation/AutoLootManager.gd")
	var drop_scene = load("res://scenes/world/LootDrop3D.tscn")
	var manager = manager_script.new()
	var drop = drop_scene.instantiate()
	root.add_child(manager)
	root.add_child(drop)
	var failures: Array[String] = []

	drop.setup_loot({"gold": 10, "has_item": false, "item_data": null})
	manager.loot_gold = false
	if manager._category_enabled_for(drop):
		failures.append("gold filter did not reject gold-only drop")
	manager.loot_gold = true
	if not manager._category_enabled_for(drop):
		failures.append("gold filter rejected enabled gold")

	drop.setup_loot({"gold": 0, "has_item": true, "item_data": {"id":"test_weapon","type":"equipment","rarity":"rare"}})
	manager.loot_equipment = false
	if manager._category_enabled_for(drop):
		failures.append("equipment filter did not reject equipment")
	manager.loot_equipment = true
	if not manager._category_enabled_for(drop):
		failures.append("equipment filter rejected enabled equipment")

	drop.setup_loot({"gold": 0, "has_item": true, "item_data": {"id":"test_gem","type":"gem","rarity":"elite"}})
	manager.loot_materials = false
	if manager._category_enabled_for(drop):
		failures.append("material filter did not reject gems")
	manager.loot_materials = true
	if not manager._category_enabled_for(drop):
		failures.append("material filter rejected enabled gems")

	drop.setup_loot({"gold": 0, "has_item": true, "item_data": {"id":"test_quest","type":"quest","rarity":"normal"}})
	manager.loot_materials = false
	if manager._category_enabled_for(drop):
		failures.append("material filter did not reject quest items")

	if failures.is_empty():
		print("LOOT FILTER AUDIT PASSED: gold, equipment, gem and quest category toggles verified")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("LOOT FILTER AUDIT FAILED: %d issue(s)" % failures.size())
		quit(1)
