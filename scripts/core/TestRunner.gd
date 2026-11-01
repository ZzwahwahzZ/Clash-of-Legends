extends Node

const PlayerInventoryScript = preload("res://scripts/player/PlayerInventory.gd")
const QuestNavigationAgentScript = preload("res://scripts/automation/QuestNavigationAgent.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var test_log: Array[String] = []

func _ready() -> void:
	print("\n=======================================================")
	print("   CLASH OF LEGENDS — AUTOMATED SUITE AUDIT & TEST RUNNER   ")
	print("=======================================================\n")
	run_all_tests()

func run_all_tests() -> Dictionary:
	total_tests = 0
	passed_tests = 0
	failed_tests = 0
	test_log.clear()
	
	test_autoload_presence()
	test_class_and_skill_database()
	test_gold_only_economy()
	test_arabic_localization_integrity()
	test_inventory_and_equipment_refinement()
	test_local_save_and_backup_recovery()
	test_quest_progression_lifecycle()
	test_auto_hunt_and_loot_systems()
	test_combat_damage_calculations()
	
	print("\n-------------------------------------------------------")
	print("TEST RESULTS SUMMARY: %d Total | %d PASSED | %d FAILED" % [total_tests, passed_tests, failed_tests])
	print("-------------------------------------------------------\n")
	
	return {
		"total": total_tests,
		"passed": passed_tests,
		"failed": failed_tests,
		"log": test_log
	}

func assert_true(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		var line = "[PASS] " + test_name
		test_log.append(line)
		print(line)
	else:
		failed_tests += 1
		var line = "[FAIL] " + test_name
		test_log.append(line)
		push_error(line)

func test_autoload_presence() -> void:
	assert_true(GameManager != null, "Autoload: GameManager is loaded and active")
	assert_true(LocalSaveEngine != null, "Autoload: LocalSaveEngine is loaded and active")
	assert_true(CombatEngine != null, "Autoload: CombatEngine is loaded and active")
	assert_true(AutoHuntManager != null, "Autoload: AutoHuntManager is loaded and active")
	assert_true(AutoLootManager != null, "Autoload: AutoLootManager is loaded and active")

func test_class_and_skill_database() -> void:
	var classes = ["Trojan", "Warrior", "Archer", "Taoist", "Ninja", "Monk", "Pirate"]
	for c in classes:
		var skills = CombatEngine.get_class_skills(c)
		assert_true(skills.size() > 0, "Class Verification: %s has functional combat skills" % c)

func test_gold_only_economy() -> void:
	GameManager.current_gold = 1000
	GameManager.add_gold(500)
	assert_true(GameManager.current_gold == 1500, "Economy: Add gold updates locally")
	var spent = GameManager.spend_gold(600)
	assert_true(spent and GameManager.current_gold == 900, "Economy: Spend gold enforces local balance")
	var overspend = GameManager.spend_gold(50000)
	assert_true(not overspend, "Economy: Overspending is correctly blocked")

func test_arabic_localization_integrity() -> void:
	GameManager.set_language("ar")
	assert_true(GameManager.current_language == "ar", "Localization: Arabic is active language")
	var title_ar = GameManager.get_translated_text("game_title")
	assert_true(title_ar == "صراع الأساطير", "Localization: Arabic title matches 'صراع الأساطير'")
	GameManager.set_language("en")
	var title_en = GameManager.get_translated_text("game_title")
	assert_true(title_en == "Clash of Legends", "Localization: English fallback functions")
	GameManager.set_language("ar")

func test_inventory_and_equipment_refinement() -> void:
	var inv = PlayerInventoryScript.new()
	add_child(inv)
	assert_true(inv.slots.size() == PlayerInventoryScript.MAX_SLOTS, "Inventory: 40 slots initialized")
	var test_item = {
		"id": "meteor_stone",
		"name_ar": "حجر النيزك",
		"name_en": "Meteor",
		"type": "material",
		"quantity": 10,
		"max_stack": 99,
		"sell_price": 150
	}
	var added = inv.add_item(test_item)
	assert_true(added, "Inventory: Item addition succeeds")
	inv.queue_free()

func test_local_save_and_backup_recovery() -> void:
	var dummy_data = {
		"level": 45,
		"hp": 980,
		"gold": 12500,
		"class": "Trojan"
	}
	var save_res = LocalSaveEngine.save_game(dummy_data)
	assert_true(save_res, "Save Engine: Local offline save succeeds")
	var loaded = LocalSaveEngine.load_game()
	assert_true(loaded.get("level", 0) == 45, "Save Engine: Loaded level matches saved state")
	assert_true(loaded.get("gold", 0) == 12500, "Save Engine: Loaded gold matches saved state")

func test_quest_progression_lifecycle() -> void:
	var qa = QuestNavigationAgentScript.new()
	add_child(qa)
	qa.active_quest_id = "quest_wolves"
	qa.quest_progress = 0
	qa.on_enemy_killed("wolf")
	assert_true(qa.quest_progress == 1, "Quest: Enemy kill registers in quest progression")
	qa.queue_free()

func test_auto_hunt_and_loot_systems() -> void:
	assert_true(AutoHuntManager.is_enabled == false, "Auto-Hunt: Initially disabled until user toggles")
	AutoHuntManager.toggle_auto_hunt()
	assert_true(AutoHuntManager.is_enabled == true, "Auto-Hunt: Toggle switches state to true")
	AutoHuntManager.toggle_auto_hunt()
	
	assert_true(AutoLootManager.is_enabled == true, "Auto-Loot: Default enabled for smooth mobile UX")

func test_combat_damage_calculations() -> void:
	assert_true(CombatEngine.skill_database.has("trojan_cyclone"), "Combat: Trojan Cyclone skill exists")
	var skill = CombatEngine.skill_database["trojan_cyclone"]
	assert_true(skill["damage_multiplier"] > 1.0, "Combat: Skill multiplier is greater than basic attack")
