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
	test_reference_class_progression_paths()
	test_arabic_ui_direction()
	test_gold_only_economy()
	test_offline_social_and_population_rules()
	test_arabic_localization_integrity()
	test_inventory_and_equipment_refinement()
	test_inventory_capacity_is_transactional()
	test_local_save_and_backup_recovery()
	test_quest_progression_lifecycle()
	test_auto_hunt_and_loot_systems()
	test_combat_damage_calculations()
	print("
-------------------------------------------------------")
	print("TEST RESULTS SUMMARY: %d Total | %d PASSED | %d FAILED" % [total_tests, passed_tests, failed_tests])
	print("-------------------------------------------------------
")
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
	assert_true(GameContentDatabase != null, "Autoload: shared content database is loaded and active")
	assert_true(AssetCatalog != null, "Autoload: runtime resource catalog is loaded")
	assert_true(AssetCatalog.get_asset_entries("missing_category").is_empty(), "Asset Catalog: missing categories return safe empty lists")
	assert_true(FeatureGuidanceManager != null, "Autoload: FeatureGuidanceManager is loaded and active")
	assert_true(LocalSaveEngine != null, "Autoload: LocalSaveEngine is loaded and active")
	assert_true(CombatEngine != null, "Autoload: CombatEngine is loaded and active")
	assert_true(AutoHuntManager != null, "Autoload: AutoHuntManager is loaded and active")
	assert_true(AutoLootManager != null, "Autoload: AutoLootManager is loaded and active")

func test_class_and_skill_database() -> void:
	var classes = ["Trojan", "Warrior", "Archer", "Ninja", "Monk", "Pirate", "DragonWarrior", "Windwalker", "Thunderstriker", "WaterTaoist", "FireTaoist", "Taoist"]
	assert_true(GameContentDatabase.validate_registry(), "Content DB: class and skill references are internally valid")
	assert_true(GameContentDatabase.get_class_ids().size() == 12, "Content DB: all 11 canonical classes plus legacy Taoist alias are registered")
	for c in classes:
		var skills = CombatEngine.get_class_skills(c)
		assert_true(skills.size() > 0, "Class Verification: %s has functional combat skills" % c)

func test_archer_advancement_path() -> void:
	ClassProgressionManager.configure_for_character("Archer")
	assert_true(ClassProgressionManager.selected_weapon_style == "bow", "Archer: starts with bow combat style")
	assert_true(not ClassProgressionManager.refresh_level_unlocks(39), "Archer: Oriental Assassin path remains locked below level 40")
	assert_true(not ClassProgressionManager.get_available_weapon_styles().has("throwing_knives"), "Archer: flying daggers unavailable before level 40")
	assert_true(ClassProgressionManager.refresh_level_unlocks(40), "Archer: Oriental Assassin path unlocks at level 40")
	assert_true(ClassProgressionManager.get_form_id() == "OrientalAssassin", "Archer: advancement keeps one character progression family")
	assert_true(ClassProgressionManager.select_weapon_style("throwing_knives"), "Archer: can select flying daggers after advancement")
	assert_true(not CombatEngine.is_skill_compatible(CombatEngine.skill_database["archer_rapid_arrow"]), "Archer: bow skill is not cast while flying daggers are selected")
	assert_true(CombatEngine.is_skill_compatible(CombatEngine.skill_database["archer_shadow_dagger"]), "Archer: flying dagger skill is available after level-40 advancement")
	assert_true(ClassProgressionManager.select_weapon_style("bow"), "Archer: can return to bow after advancement")
	assert_true(CombatEngine.is_skill_compatible(CombatEngine.skill_database["archer_rapid_arrow"]), "Archer: bow skill becomes available again with bow selected")
	assert_true(not CombatEngine.is_skill_compatible(CombatEngine.skill_database["archer_shadow_dagger"]), "Archer: dagger skills are disabled when switching back to bow")
	var saved_path = ClassProgressionManager.serialize()
	ClassProgressionManager.configure_for_character("Trojan")
	ClassProgressionManager.deserialize(saved_path)
	assert_true(ClassProgressionManager.get_form_id() == "OrientalAssassin" and ClassProgressionManager.selected_weapon_style == "bow", "Archer: advancement and selected weapon style survive serialization")
	ClassProgressionManager.configure_for_character("Trojan")
	assert_true(not ClassProgressionManager.select_weapon_style("throwing_knives"), "Other classes cannot select Archer weapon paths")

func test_reference_class_progression_paths() -> void:
	ClassProgressionManager.configure_for_character("Trojan")
	assert_true(not ClassProgressionManager.has_unlocked_trait("Windigo"), "Trojan: Windigo remains locked before level 40")
	assert_true(not ClassProgressionManager.refresh_level_unlocks(39), "Trojan: level-40 Windigo gate is enforced")
	assert_true(ClassProgressionManager.refresh_level_unlocks(40), "Trojan: Windigo unlocks at level 40")
	assert_true(ClassProgressionManager.has_unlocked_trait("Windigo"), "Trojan: Windigo trait is persisted in progression state")
	var windigo_skill: Dictionary = GameContentDatabase.get_skill_database().get("trojan_windigo", {})
	assert_true(ClassProgressionManager.is_skill_compatible(windigo_skill), "Trojan: Windigo skill is available after its trait unlock")

	ClassProgressionManager.configure_for_character("Taoist")
	assert_true(not ClassProgressionManager.refresh_level_unlocks(39), "Taoist: Water/Fire branches remain locked below level 40")
	assert_true(ClassProgressionManager.refresh_level_unlocks(40), "Taoist: Water/Fire branches unlock at level 40")
	assert_true(ClassProgressionManager.get_available_branches().has("WaterTaoist") and ClassProgressionManager.get_available_branches().has("FireTaoist"), "Taoist: both source branches are available at level 40")
	assert_true(ClassProgressionManager.select_branch("WaterTaoist"), "Taoist: Water branch can be selected")
	var water_skill: Dictionary = GameContentDatabase.get_skill_database()["water_taoist_healing_rain"]
	var fire_skill: Dictionary = GameContentDatabase.get_skill_database()["fire_taoist_flame_burst"]
	assert_true(ClassProgressionManager.is_skill_compatible(water_skill), "Taoist: Water skills require and accept the Water branch")
	assert_true(not ClassProgressionManager.is_skill_compatible(fire_skill), "Taoist: Fire skills are blocked while Water is selected")
	assert_true(ClassProgressionManager.select_branch("FireTaoist"), "Taoist: Fire branch can be selected")
	assert_true(ClassProgressionManager.is_skill_compatible(fire_skill) and not ClassProgressionManager.is_skill_compatible(water_skill), "Taoist: branch switching changes skill access")

	ClassProgressionManager.configure_for_character("WaterTaoist")
	assert_true(ClassProgressionManager.get_selected_progression_choice() == "WaterTaoist", "Water Taoist: selected class initializes its shared-family branch")
	assert_true(ClassProgressionManager.refresh_level_unlocks(40) and ClassProgressionManager.get_available_branches().has("FireTaoist"), "Water Taoist: alternate branch becomes available at level 40")

	ClassProgressionManager.configure_for_character("Windwalker")
	assert_true(ClassProgressionManager.get_available_branches().has("Stomper") and ClassProgressionManager.get_available_branches().has("Chaser"), "Windwalker: both source combat branches are available")
	assert_true(ClassProgressionManager.select_branch("Chaser"), "Windwalker: Chaser branch can be selected")
	var chaser_skill: Dictionary = GameContentDatabase.get_skill_database()["windwalker_chaser_thundercloud"]
	var stomper_skill: Dictionary = GameContentDatabase.get_skill_database()["windwalker_stomper_crush"]
	assert_true(ClassProgressionManager.is_skill_compatible(chaser_skill), "Windwalker: Chaser skill is available in Chaser form")
	assert_true(not ClassProgressionManager.is_skill_compatible(stomper_skill), "Windwalker: Stomper skill is blocked in Chaser form")
	var saved_progression := ClassProgressionManager.serialize()
	ClassProgressionManager.configure_for_character("Trojan")
	ClassProgressionManager.deserialize(saved_progression)
	assert_true(ClassProgressionManager.get_form_id() == "Chaser" and ClassProgressionManager.selected_branch == "Chaser", "Progression: selected Windwalker branch survives save/load")
	ClassProgressionManager.configure_for_character("Trojan")

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
	assert_true(not inv.remove_item_at(0, -1), "Inventory: negative removal quantities are rejected")
	inv.equipment["weapon"] = {"id":"test_blade","slot":"weapon","type":"equipment","attack_bonus":20,"defense_bonus":5,"refine_level":0,"sockets":1,"name_ar":"سيف الاختبار"}
	GameManager.current_gold = 10000
	var preview := inv.get_refine_preview("weapon")
	assert_true(not preview.is_empty() and int(preview.gold_cost) == 200 and is_equal_approx(float(preview.success_chance), 1.0), "Refinement: shared preview defines first-tier cost and guaranteed success")
	assert_true(inv.refine_equipment("weapon"), "Refinement: first tier succeeds with valid Meteor and Gold")
	assert_true(int(inv.equipment["weapon"].refine_level) == 1 and int(inv.equipment["weapon"].attack_bonus) == 32, "Refinement: +1 applies deterministic attack progression")
	var gem := {"id":"ruby_test","name_ar":"ياقوتة اختبار","name_en":"Test Ruby","type":"gem","quantity":1,"max_stack":1,"attack_bonus":7,"defense_bonus":3}
	assert_true(inv.add_item(gem), "Sockets: gem can be stored in inventory")
	var gem_index := -1
	for i in range(inv.MAX_SLOTS):
		if inv.slots[i] != null and str(inv.slots[i].get("id", "")) == "ruby_test":
			gem_index = i
			break
	assert_true(gem_index >= 0 and inv.insert_gem("weapon", gem_index, 0), "Sockets: valid gem insertion consumes inventory item")
	assert_true(inv.equipment["weapon"].socket_gems[0].id == "ruby_test", "Sockets: inserted gem is attached to equipment")
	assert_true(not inv.insert_gem("weapon", gem_index, 0), "Sockets: occupied socket rejects duplicate insertion")
	assert_true(inv.remove_gem("weapon", 0, 100), "Sockets: gem can be safely removed for Gold")
	assert_true(inv.equipment["weapon"].socket_gems[0] == null, "Sockets: removed gem leaves empty socket")
	for material_id in ["perfection_stone", "blessing_stone", "enchant_scroll", "purification_stone", "anima_core"]:
		assert_true(inv.add_item({"id":material_id,"type":"material","quantity":1,"max_stack":99}), "Equipment Progression: %s material is available" % material_id)
	assert_true(inv.apply_equipment_upgrade("weapon", "perfection"), "Perfection: consumes material and upgrades equipment")
	assert_true(int(inv.equipment["weapon"].perfection_level) == 1, "Perfection: level is persisted on the item")
	assert_true(inv.apply_equipment_upgrade("weapon", "blessing"), "Blessing: consumes material and upgrades equipment")
	assert_true(is_equal_approx(inv.get_total_blessing_reduction(), 0.02), "Blessing: adds two percent incoming damage reduction")
	assert_true(inv.apply_equipment_upgrade("weapon", "enchant", "attack"), "Enchant: attack enchant is applied")
	assert_true(int(inv.equipment["weapon"].enchant_attack_bonus) == 5, "Enchant: attack bonus is reflected in item data")
	assert_true(inv.apply_equipment_upgrade("weapon", "purification", "defense"), "Purification: selected defensive attribute is applied")
	assert_true(inv.equipment["weapon"].purification.stat == "defense", "Purification: selected attribute is stored")
	assert_true(inv.apply_equipment_upgrade("weapon", "anima"), "Anima: consumes core and upgrades equipment")
	assert_true(int(inv.equipment["weapon"].anima_level) == 1, "Anima: level is stored on equipment")
	inv.equipment["weapon"]["refine_level"] = 12
	assert_true(bool(inv.get_refine_preview("weapon").get("maxed", false)), "Refinement: +12 cap is enforced")
	assert_true(not inv.refine_equipment("weapon"), "Refinement: cannot exceed +12")
	inv.deserialize({"slots": [], "equipment": {"weapon": {"id":"legacy_weapon","slot":"weapon","type":"equipment"}}})
	assert_true(inv.equipment.has("mount") and inv.equipment.has("garment") and inv.slots.size() == PlayerInventoryScript.MAX_SLOTS, "Inventory: legacy saves migrate to the expanded equipment layout")
	inv.queue_free()


func test_inventory_capacity_is_transactional() -> void:
	var test_player := CharacterBody3D.new()
	test_player.name = "InventoryCapacityTestPlayer"
	add_child(test_player)
	var full_inventory := PlayerInventoryScript.new()
	full_inventory.name = "PlayerInventory"
	test_player.add_child(full_inventory)

	var meteor_index := -1
	for i in range(full_inventory.MAX_SLOTS):
		if full_inventory.slots[i] != null and str(full_inventory.slots[i].get("id", "")) == "meteor_stone":
			meteor_index = i
			break
	assert_true(meteor_index >= 0, "Inventory Capacity: starter material stack is available")
	if meteor_index < 0:
		test_player.queue_free()
		return

	full_inventory.slots[meteor_index]["quantity"] = 98
	for i in range(full_inventory.MAX_SLOTS):
		if full_inventory.slots[i] == null:
			full_inventory.slots[i] = {"id": "capacity_filler_%d" % i, "quantity": 1, "max_stack": 1}

	var before_quantity := int(full_inventory.slots[meteor_index].get("quantity", 0))
	var accepted := full_inventory.add_item({"id": "meteor_stone", "type": "material", "quantity": 3, "max_stack": 99})
	assert_true(not accepted and int(full_inventory.slots[meteor_index].get("quantity", 0)) == before_quantity, "Inventory Capacity: failed stack insertion makes no partial changes")

	var drop_scene := load("res://scenes/world/LootDrop3D.tscn") as PackedScene
	var drop := drop_scene.instantiate() as LootDrop3D if drop_scene else null
	var gold_before := GameManager.current_gold
	if drop:
		add_child(drop)
		drop.setup_loot({"gold": 25, "has_item": true, "item_data": {"id": "meteor_stone", "type": "material", "quantity": 3, "max_stack": 99}})
		drop.collect_by_player(test_player)
		assert_true(not drop.is_collected and not drop.is_queued_for_deletion() and GameManager.current_gold == gold_before, "Loot: full inventory preserves the drop and does not grant its gold")
		drop.queue_free()
	else:
		assert_true(false, "Loot: test drop scene is available")
	test_player.queue_free()

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
	var event_quest = QuestNavigationAgentScript.new()
	add_child(event_quest)
	event_quest.add_to_group("quest_agents")
	assert_true(event_quest._validate_quest_database(), "Quest: expanded objective catalogue has valid links and targets")
	event_quest.active_quest_id = "quest_meteor_gather"
	event_quest.on_enemy_killed("wolf")
	assert_true(event_quest.quest_progress == 0, "Quest: kill event cannot advance a collection objective")
	event_quest.on_item_collected("meteor_stone", 2)
	assert_true(event_quest.quest_progress == 2, "Quest: collected item quantity advances the objective")
	event_quest.on_item_collected("meteor_stone", 1)
	assert_true(event_quest.active_quest_id == "quest_meteor_gather" and event_quest.is_quest_completed, "Quest: collection completion waits for NPC turn-in")
	var gold_before_turnin := GameManager.current_gold
	event_quest.on_npc_talked("npc_blacksmith")
	assert_true(event_quest.active_quest_id == "quest_meteor_gather" and GameManager.current_gold == gold_before_turnin, "Quest: wrong turn-in NPC cannot grant collection reward")
	event_quest.on_npc_talked("npc_sage")
	assert_true(event_quest.active_quest_id == "quest_blacksmith_visit" and event_quest.completed_quest_ids.has("quest_meteor_gather"), "Quest: correct turn-in NPC grants reward and advances chain")
	event_quest.on_npc_talked("npc_merchant")
	assert_true(event_quest.quest_progress == 0, "Quest: wrong NPC cannot complete dialogue objective")
	event_quest.on_npc_talked("npc_blacksmith")
	assert_true(event_quest.active_quest_id == "quest_blacksmith_visit" and event_quest.is_quest_completed, "Quest: dialogue objective becomes ready for turn-in")
	event_quest.on_npc_talked("npc_sage")
	assert_true(event_quest.active_quest_id == "quest_blacksmith_visit", "Quest: wrong turn-in NPC cannot claim blacksmith reward")
	event_quest.on_npc_talked("npc_blacksmith")
	assert_true(event_quest.active_quest_id == "quest_guardian", "Quest: blacksmith turn-in grants reward and advances chain")
	event_quest.active_quest_id = "quest_level_10"
	event_quest.quest_progress = 0
	event_quest.is_quest_completed = false
	event_quest.on_level_reached(9)
	assert_true(event_quest.quest_progress == 0, "Quest: level gate remains locked below target")
	event_quest.on_level_reached(10)
	assert_true(event_quest.is_quest_completed and event_quest.active_quest_id == "quest_level_10", "Quest: reaching required level waits for sage turn-in")
	event_quest.on_npc_talked("npc_sage")
	assert_true(event_quest.active_quest_id == "quest_dragon", "Quest: sage turn-in grants level quest reward and advances chain")
	event_quest.queue_free()
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
