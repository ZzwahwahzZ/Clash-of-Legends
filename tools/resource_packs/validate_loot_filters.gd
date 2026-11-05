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
	manager.loot_gems = true
	if not manager._category_enabled_for(drop):
		failures.append("gem filter must be independent of general materials")
	manager.loot_gems = false
	if manager._category_enabled_for(drop):
		failures.append("gem filter did not reject gems when disabled")

	drop.setup_loot({"gold": 0, "has_item": true, "item_data": {"id":"test_quest","type":"quest","rarity":"normal"}})
	manager.loot_materials = true
	manager.loot_quest_items = false
	if manager._category_enabled_for(drop):
		failures.append("quest-item filter did not reject quest items independently")
	manager.loot_quest_items = true
	if not manager._category_enabled_for(drop):
		failures.append("quest-item filter rejected enabled quest items")

	var category_cases := [
		{"type":"consumable","flag":"consumables"},
		{"type":"refinement_material","flag":"refinement_materials"},
		{"type":"crafting_material","flag":"crafting_materials"},
		{"type":"cosmetic","flag":"cosmetics"}
	]
	for test_case in category_cases:
		drop.setup_loot({"gold":0,"has_item":true,"item_data":{"id":"filter_test","type":test_case.type}})
		manager.set_category_enabled(test_case.flag, false)
		if manager._category_enabled_for(drop):
			failures.append("%s filter did not reject its own category" % test_case.flag)
		manager.set_category_enabled(test_case.flag, true)
		if not manager._category_enabled_for(drop):
			failures.append("%s filter rejected its enabled category" % test_case.flag)

	drop.setup_loot({"gold":0,"has_item":true,"item_data":{"id":"unknown_relic","type":"unclassified_relic"}})
	if manager._category_enabled_for(drop):
		failures.append("unknown loot category must default to disabled")

	var saved_filters: Dictionary = manager.get_filter_settings()
	manager.set_category_enabled("gems", false)
	manager.apply_filter_settings(saved_filters)
	if not manager.loot_gems:
		failures.append("loot filter settings did not restore saved gem preference")

	if failures.is_empty():
		print("LOOT FILTER AUDIT PASSED: independent category toggles, unknown-item safety and settings persistence verified")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("LOOT FILTER AUDIT FAILED: %d issue(s)" % failures.size())
		quit(1)
