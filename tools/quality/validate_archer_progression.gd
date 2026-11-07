extends Node

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if GameManager.selected_class != "Archer":
		_fail("Archer must be the default selected main character.")
		return
	var player_scene := load("res://scenes/characters/Player.tscn") as PackedScene
	if player_scene == null:
		_fail("Could not load the real Player scene for class-selection validation.")
		return
	var player := player_scene.instantiate() as PlayerController
	if player == null:
		_fail("Player scene did not instantiate a PlayerController.")
		return
	player.current_level = 40
	get_tree().root.add_child(player)
	await get_tree().process_frame
	var progression = ClassProgressionManager
	if player.get_character_class() != "Archer":
		_fail("The title-screen Archer selection did not reach the actual PlayerController.")
		return
	if not player.has_node("PlayerInventory"):
		_fail("The actual Player scene has no PlayerInventory child.")
		return
	progression.configure_for_character("Archer")

	if progression.selected_weapon_style != "bow" or progression.get_form_id() != "Archer":
		_fail("Archer must begin in Bow form.")
		return
	if progression.refresh_level_unlocks(39):
		_fail("Level 39 must not unlock the Archer promotion.")
		return
	if progression.refresh_level_unlocks(40):
		_fail("Level 40 alone must not complete the Archer promotion quest.")
		return
	if progression.get_available_weapon_styles() != ["bow"]:
		_fail("Throwing Knives became available before the promotion quest.")
		return
	if CombatEngine.get_class_skills("Archer").has("archer_path_of_shadow"):
		_fail("Path of Shadow appeared before the promotion unlock.")
		return
	if progression.select_weapon_style("throwing_knives"):
		_fail("Direct Assassin form selection succeeded before promotion.")
		return

	var incomplete_result := {
		"promotion_quest_id": "unverified_placeholder",
		"quest_completed": true,
		"promotion_reward_claimed": true,
		"promotion_source_verified": false
	}
	if progression.apply_archer_promotion_result(incomplete_result, 40):
		_fail("Unverified promotion data must not unlock Oriental Assassin.")
		return

	var verified_result := {
		"promotion_quest_id": "source_verified_test_fixture",
		"quest_completed": true,
		"promotion_reward_claimed": true,
		"promotion_source_verified": true
	}
	if progression.apply_archer_promotion_result(verified_result, 39):
		_fail("A level-39 character must not complete the level-40 promotion.")
		return
	if not progression.apply_archer_promotion_result(verified_result, 40):
		_fail("A verified, completed, claimed level-40 promotion should unlock the alternate form.")
		return
	if progression.selected_weapon_style != "bow" or progression.get_form_id() != "Archer":
		_fail("Unlocking Oriental Assassin must preserve the active Archer/Bow form.")
		return
	if not progression.get_available_weapon_styles().has("throwing_knives"):
		_fail("Verified promotion did not unlock Throwing Knives.")
		return

	var inventory := player.get_node("PlayerInventory") as PlayerInventory
	var starter_weapon: Variant = inventory.equipment.get("weapon", null)
	if not starter_weapon is Dictionary or str(starter_weapon.get("id", "")) != "500239" or str(starter_weapon.get("weapon_style", "")) != "bow":
		_fail("Archer character creation did not equip the pinned Mobile source weapon ID 500239 as a Bow.")
		return
	# Reset starter state before the isolated two-loadout switching fixture.
	inventory.equipment["weapon"] = null
	inventory.weapon_loadouts["bow"] = null
	inventory.weapon_loadouts["throwing_knives"] = null

	var bow_item := {
		"id":"test_archer_bow", "name_ar":"قوس اختبار", "name_en":"Test Bow",
		"type":"equipment", "slot":"weapon", "class_req":"Archer",
		"weapon_style":"bow", "attack_bonus":10
	}
	var knife_item := {
		"id":"test_oriental_throwing_knife", "name_ar":"خنجر اختبار", "name_en":"Test Throwing Knife",
		"type":"equipment", "slot":"weapon", "class_req":"Archer",
		"weapon_style":"throwing_knives", "attack_bonus":12
	}
	if not inventory.add_item(bow_item) or not inventory.add_item(knife_item):
		_fail("Could not seed isolated weapon-loadout fixtures.")
		return
	var bow_index := _find_item_index(inventory, "test_archer_bow")
	if bow_index < 0 or not inventory.equip_item_from_slot(bow_index):
		_fail("Could not equip the Archer Bow fixture.")
		return

	var bow_skill := {"class_req":"Archer", "weapon_style":"bow"}
	var assassin_skill := {"class_req":"Archer", "weapon_style":"throwing_knives"}
	if not progression.is_skill_compatible(bow_skill) or progression.is_skill_compatible(assassin_skill):
		_fail("Archer form skill compatibility is incorrect.")
		return

	if CombatEngine.can_cast_skill("archer_path_of_shadow", player):
		_fail("Path of Shadow must remain unavailable until the Throwing Knife is prepared.")
		return
	if CombatEngine.execute_skill("archer_path_of_shadow", player, null):
		_fail("Path of Shadow activated without a prepared Throwing Knife.")
		return
	var knife_index := _find_item_index(inventory, "test_oriental_throwing_knife")
	if knife_index < 0 or not inventory.equip_item_from_slot(knife_index):
		_fail("Could not equip the inactive Oriental Assassin weapon loadout.")
		return
	if str(inventory.equipment.get("weapon", {}).get("id", "")) != "test_archer_bow":
		_fail("Pre-equipping the Throwing Knife changed the active Archer weapon.")
		return
	if str(inventory.weapon_loadouts["throwing_knives"].get("id", "")) != "test_oriental_throwing_knife":
		_fail("The Throwing Knife was not stored in its separate loadout.")
		return
	var archer_skills := CombatEngine.get_class_skills("Archer")
	if archer_skills.is_empty() or archer_skills[0] != "archer_path_of_shadow":
		_fail("Path of Shadow is not exposed as the first available Archer form-toggle skill.")
		return
	if not CombatEngine.can_cast_skill("archer_path_of_shadow", player):
		_fail("Path of Shadow should be available after promotion with a Throwing Knife loadout.")
		return
	if not CombatEngine.execute_skill("archer_path_of_shadow", player, null):
		_fail("Path of Shadow failed to transform the Archer.")
		return
	if progression.get_form_id() != "OrientalAssassin" or str(inventory.equipment.get("weapon", {}).get("id", "")) != "test_oriental_throwing_knife":
		_fail("Path of Shadow did not activate Assassin form and its Throwing Knife.")
		return
	var assassin_skills := CombatEngine.get_class_skills("Archer")
	if assassin_skills.is_empty() or assassin_skills[0] != "archer_path_of_shadow" or assassin_skills.has("archer_rapid_arrow") or not assassin_skills.has("archer_shadow_dagger"):
		_fail("Assassin form did not filter the Archer skill set correctly.")
		return
	if not CombatEngine.execute_skill("archer_path_of_shadow", player, null):
		_fail("Path of Shadow failed to return to Archer form.")
		return
	if progression.get_form_id() != "Archer" or str(inventory.equipment.get("weapon", {}).get("id", "")) != "test_archer_bow":
		_fail("Path of Shadow did not restore Archer form and its Bow.")
		return
	var restored_bow_skills := CombatEngine.get_class_skills("Archer")
	if restored_bow_skills.is_empty() or restored_bow_skills[0] != "archer_path_of_shadow" or restored_bow_skills.has("archer_shadow_dagger") or not restored_bow_skills.has("archer_rapid_arrow"):
		_fail("Archer form did not restore the Bow-only skill set.")
		return
	if not CombatEngine.execute_skill("archer_path_of_shadow", player, null):
		_fail("Path of Shadow failed on the second Assassin activation.")
		return
	if progression.get_form_id() != "OrientalAssassin" or str(inventory.equipment.get("weapon", {}).get("id", "")) != "test_oriental_throwing_knife":
		_fail("Repeated Path of Shadow use did not restore the Assassin loadout.")
		return
	if str(inventory.weapon_loadouts["bow"].get("id", "")) != "test_archer_bow":
		_fail("Switching form did not preserve the Bow in its own loadout.")
		return
	if progression.get_form_id() != "OrientalAssassin":
		_fail("Throwing Knives selection did not activate Oriental Assassin form.")
		return
	if progression.is_skill_compatible(bow_skill) or not progression.is_skill_compatible(assassin_skill):
		_fail("Oriental Assassin form skill compatibility is incorrect.")
		return

	if not progression.select_weapon_style("bow"):
		_fail("Could not switch back to Archer/Bow form.")
		return
	if str(inventory.equipment.get("weapon", {}).get("id", "")) != "test_archer_bow":
		_fail("Returning to Archer did not restore the saved Bow.")
		return
	if not progression.select_weapon_style("throwing_knives"):
		_fail("Could not switch back to Oriental Assassin form.")
		return
	if str(inventory.equipment.get("weapon", {}).get("id", "")) != "test_oriental_throwing_knife":
		_fail("Returning to Oriental Assassin did not restore the saved Throwing Knife.")
		return

	var assassin_save: Dictionary = progression.serialize()
	var inventory_save: Dictionary = inventory.serialize()
	progression.select_weapon_style("bow")
	if progression.get_form_id() != "Archer":
		_fail("Switching back to Bow did not restore Archer form.")
		return
	progression.deserialize(assassin_save)
	inventory.deserialize(inventory_save)
	if progression.selected_weapon_style != "throwing_knives" or progression.get_form_id() != "OrientalAssassin":
		_fail("Save/load did not preserve the active Assassin form.")
		return
	if progression.character_class_id != "Archer" or progression.progression_family != "Archer":
		_fail("Form switching replaced the base character identity.")
		return
	if str(inventory.equipment.get("weapon", {}).get("id", "")) != "test_oriental_throwing_knife":
		_fail("Save/load did not preserve the Assassin weapon loadout.")
		return

	var bow_save: Dictionary = progression.serialize()
	progression.select_weapon_style("bow")
	progression.deserialize(bow_save)
	if progression.selected_weapon_style != "throwing_knives" or progression.get_form_id() != "OrientalAssassin":
		_fail("Deserialization changed the saved active form unexpectedly.")
		return

	print("ARCHER PROGRESSION PASSED: level gate, quest-gated unlock, one character identity, reversible forms, weapon loadouts, skill restrictions and save/load.")
	player.queue_free()
	GameManager.player_reference = null
	get_tree().quit(0)

func _find_item_index(inventory: PlayerInventory, item_id: String) -> int:
	for index in range(inventory.slots.size()):
		var item: Variant = inventory.slots[index]
		if item is Dictionary and str(item.get("id", "")) == item_id:
			return index
	return -1

func _fail(message: String) -> void:
	push_error("ARCHER PROGRESSION FAILED: " + message)
	get_tree().quit(1)
