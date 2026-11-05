extends Node

const PlayerInventoryScript = preload("res://scripts/player/PlayerInventory.gd")
const QuestNavigationAgentScript = preload("res://scripts/automation/QuestNavigationAgent.gd")
const SimulatedPlayerScript = preload("res://scripts/ai/SimulatedPlayer.gd")

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
	test_archer_advancement_path()
	test_arabic_ui_direction()
	test_gold_only_economy()
	test_offline_social_and_population_rules()
	test_arabic_localization_integrity()
	test_inventory_and_equipment_refinement()
	test_local_save_and_backup_recovery()
	test_quest_progression_lifecycle()
	test_auto_hunt_and_loot_systems()
	test_combat_damage_calculations()
	print("\n-------------------------------------------------------")
	print("TEST RESULTS SUMMARY: %d Total | %d PASSED | %d FAILED" % [total_tests, passed_tests, failed_tests])
	print("-------------------------------------------------------\n")
	return {"total":total_tests,"passed":passed_tests,"failed":failed_tests,"log":test_log}

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
	assert_true(ClassProgressionManager != null, "Autoload: ClassProgressionManager is loaded and active")
	assert_true(LocalSaveEngine != null, "Autoload: LocalSaveEngine is loaded and active")
	assert_true(CombatEngine != null, "Autoload: CombatEngine is loaded and active")
	assert_true(AutoHuntManager != null, "Autoload: AutoHuntManager is loaded and active")
	assert_true(AutoLootManager != null, "Autoload: AutoLootManager is loaded and active")

func test_class_and_skill_database() -> void:
	var classes = ["Trojan", "Warrior", "Archer", "Taoist", "Ninja", "Monk", "Pirate"]
	for c in classes:
		var skills = CombatEngine.get_class_skills(c)
		assert_true(skills.size() > 0, "Class Verification: %s has functional combat skills" % c)

func test_archer_advancement_path() -> void:
	ClassProgressionManager.configure_for_character("Archer")
	assert_true(ClassProgressionManager.selected_weapon_style == "bow", "Archer: starts with bow combat style")
	assert_true(not ClassProgressionManager.refresh_level_unlocks(39), "Archer: Oriental Assassin path remains locked below level 40")
	assert_true(not ClassProgressionManager.get_available_weapon_styles().has("flying_daggers"), "Archer: flying daggers unavailable before level 40")
	assert_true(ClassProgressionManager.refresh_level_unlocks(40), "Archer: Oriental Assassin path unlocks at level 40")
	assert_true(ClassProgressionManager.get_form_id() == "OrientalAssassin", "Archer: advancement keeps one character progression family")
	assert_true(ClassProgressionManager.select_weapon_style("flying_daggers"), "Archer: can select flying daggers after advancement")
	assert_true(not CombatEngine.is_skill_compatible(CombatEngine.skill_database["archer_rapid_arrow"]), "Archer: bow skill is not cast while flying daggers are selected")
	assert_true(ClassProgressionManager.select_weapon_style("bow"), "Archer: can return to bow after advancement")
	assert_true(CombatEngine.is_skill_compatible(CombatEngine.skill_database["archer_rapid_arrow"]), "Archer: bow skill becomes available again with bow selected")
	var saved_path = ClassProgressionManager.serialize()
	ClassProgressionManager.configure_for_character("Trojan")
	ClassProgressionManager.deserialize(saved_path)
	assert_true(ClassProgressionManager.get_form_id() == "OrientalAssassin" and ClassProgressionManager.selected_weapon_style == "bow", "Archer: advancement and selected weapon style survive serialization")
	ClassProgressionManager.configure_for_character("Trojan")
	assert_true(not ClassProgressionManager.select_weapon_style("flying_daggers"), "Other classes cannot select Archer weapon paths")

func test_arabic_ui_direction() -> void:
	var root := Control.new()
	var label := Label.new()
	label.text = "الحقيبة والإعدادات"
	root.add_child(label)
	FeatureGuidanceManager._apply_rtl_tree(root)
	var audit := ArabicUiAudit.audit_tree(root)
	assert_true(audit["controls"] == 2, "Arabic UI: audit detects all test controls")
	assert_true(audit["rtl_controls"] == 2, "Arabic UI: every control receives RTL layout and text direction")
	assert_true(audit["arabic_text_controls"] == 1 and audit["bad_direction"].is_empty(), "Arabic UI: Arabic text is flagged only when direction is incorrect")
	root.free()

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
	assert_true(GameManager.get_translated_text("game_title") == "صراع الأساطير", "Localization: Arabic title matches 'صراع الأساطير'")
	GameManager.set_language("en")
	assert_true(GameManager.get_translated_text("game_title") == "Clash of Legends", "Localization: English fallback functions")
	GameManager.set_language("ar")

func test_inventory_and_equipment_refinement() -> void:
	var inv = PlayerInventoryScript.new()
	add_child(inv)
	assert_true(inv.slots.size() == PlayerInventoryScript.MAX_SLOTS, "Inventory: 40 slots initialized")
	var test_item = {"id":"meteor_stone","name_ar":"حجر النيزك","name_en":"Meteor","type":"material","quantity":10,"max_stack":99,"sell_price":150}
	assert_true(inv.add_item(test_item), "Inventory: Item addition succeeds")
	inv.queue_free()

func test_local_save_and_backup_recovery() -> void:
	var dummy_data = {"level":45,"hp":980,"gold":12500,"class":"Trojan"}
	var save_res = LocalSaveEngine.save_game(dummy_data)
	assert_true(save_res, "Save Engine: Local offline save succeeds")
	var loaded = LocalSaveEngine.load_game()
	assert_true(loaded.get("level", 0) == 45, "Save Engine: Loaded level matches saved level")
	assert_true(loaded.get("gold", 0) == 12500, "Save Engine: Loaded gold matches saved balance")

func test_quest_progression_lifecycle() -> void:
	var qa = QuestNavigationAgentScript.new()
	add_child(qa)
	qa.add_to_group("quest_agents")
	qa.active_quest_id = "quest_wolves"
	qa.quest_progress = 0
	qa.on_enemy_killed("dragon")
	assert_true(qa.quest_progress == 0, "Quest: Unrelated enemy does not advance objective")
	qa.on_enemy_killed("wolf")
	assert_true(qa.quest_progress == 1, "Quest: Matching enemy kill registers in progression")
	assert_true(qa.quest_database.has("quest_wolf_alpha") and qa.quest_database.has("quest_guardian"), "Quest: Expanded offline quest chain is registered")
	var saved_quest = qa.serialize()
	var restored_quest = QuestNavigationAgentScript.new()
	add_child(restored_quest)
	restored_quest.deserialize(saved_quest)
	assert_true(restored_quest.active_quest_id == qa.active_quest_id and restored_quest.quest_progress == qa.quest_progress, "Quest: Progress survives serialization round-trip")
	var quest_states = LocalSaveEngine.capture_quest_states()
	assert_true(quest_states.has("QuestNavigationAgent") or quest_states.has(str(qa.name)), "Quest: Active agent state is captured by local save engine")
	var persisted = LocalSaveEngine.save_game({"quest_agents":quest_states})
	var loaded_state = LocalSaveEngine.load_game()
	assert_true(persisted and LocalSaveEngine.restore_quest_states(loaded_state.get("quest_agents", {})) >= 1, "Quest: Agent state restores from local save payload")
	qa.queue_free()
	restored_quest.queue_free()

func test_auto_hunt_and_loot_systems() -> void:
	assert_true(AutoHuntManager.is_enabled == false, "Auto-Hunt: Initially disabled until user toggles")
	AutoHuntManager.toggle_auto_hunt()
	assert_true(AutoHuntManager.is_enabled == true, "Auto-Hunt: Toggle switches state to true")
	AutoHuntManager.toggle_auto_hunt()
	assert_true(AutoLootManager.is_enabled == true, "Auto-Loot: Default enabled for smooth mobile UX")

func test_combat_damage_calculations() -> void:
	assert_true(CombatEngine.skill_database.has("trojan_cyclone"), "Combat: Trojan Cyclone prototype exists")
	assert_true(CombatEngine.skill_database["trojan_cyclone"]["damage_multiplier"] > 1.0, "Combat: Skill multiplier exceeds basic attack")

func test_offline_social_and_population_rules() -> void:
	assert_true(not GameManager.has_signal("chat_message_received"), "Offline Social: no chat signal or simulated chat feed")
	var simulated = SimulatedPlayerScript.new()
	add_child(simulated)
	assert_true(not simulated.movement_commanded, "Simulated Population: characters are stationary by default")
	simulated.command_move_to(Vector3(5.0, 0.0, 0.0))
	assert_true(simulated.movement_commanded, "Simulated Population: movement requires an explicit command")
	simulated.stop_commanded_movement()
	assert_true(not simulated.movement_commanded, "Simulated Population: commanded movement can be stopped")
	simulated.queue_free()
