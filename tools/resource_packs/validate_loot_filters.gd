extends Node

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager_script = load("res://scripts/automation/AutoLootManager.gd")
	var drop_scene = load("res://scenes/world/LootDrop3D.tscn")
	var manager = manager_script.new()
	var drop = drop_scene.instantiate()
	get_tree().root.add_child(manager)
	get_tree().root.add_child(drop)
	var failures: Array[String] = []

	var settings_scene = load("res://scenes/ui/SettingsUI.tscn")
	var settings_ui = settings_scene.instantiate()
	get_tree().root.add_child(settings_ui)
	await get_tree().process_frame
	var filter_grid: GridContainer = settings_ui.get_node_or_null("Panel/LootFiltersGrid")
	if filter_grid == null or filter_grid.get_child_count() != 9:
		failures.append("settings UI must expose all nine independent loot filters")
	else:
		var gem_checkbox: CheckBox = filter_grid.get_node_or_null("gems")
		if gem_checkbox == null:
			failures.append("settings UI is missing the stable Gems filter control")
		else:
			var previous_gem_setting: bool = AutoLootManager.loot_gems
			gem_checkbox.toggled.emit(not previous_gem_setting)
			if AutoLootManager.loot_gems == previous_gem_setting:
				failures.append("settings Gems checkbox did not update the live AutoLootManager")
			AutoLootManager.set_category_enabled("gems", previous_gem_setting)

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

	# Capture a known enabled preference, change it, then restore it.
	# Earlier category-isolation checks intentionally leave gems disabled.
	manager.set_category_enabled("gems", true)
	var saved_filters: Dictionary = manager.get_filter_settings()
	manager.set_category_enabled("gems", false)
	manager.apply_filter_settings(saved_filters)
	if not manager.loot_gems:
		failures.append("loot filter settings did not restore saved gem preference")

	if failures.is_empty():
		print("LOOT FILTER AUDIT PASSED: independent category toggles, unknown-item safety and settings persistence verified")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("LOOT FILTER AUDIT FAILED: %d issue(s)" % failures.size())
		get_tree().quit(1)
