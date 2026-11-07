extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var progression = ClassProgressionManager
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
	if not progression.apply_archer_promotion_result(verified_result, 40):
		_fail("A verified, completed, claimed level-40 promotion should unlock the alternate form.")
		return
	if progression.selected_weapon_style != "bow" or progression.get_form_id() != "Archer":
		_fail("Unlocking Oriental Assassin must preserve the active Archer/Bow form.")
		return
	if not progression.get_available_weapon_styles().has("throwing_knives"):
		_fail("Verified promotion did not unlock Throwing Knives.")
		return

	var inventory := PlayerInventory.new()
	root.add_child(inventory)
	await process_frame
	# The starter prototype weapon is not part of this focused fixture.
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

	if not progression.select_weapon_style("throwing_knives"):
		_fail("Could not switch to the unlocked Throwing Knives form.")
		return
	if inventory.equipment.get("weapon", null) != null:
		_fail("Switching form did not safely clear the incompatible active Bow.")
		return
	if str(inventory.weapon_loadouts["bow"].get("id", "")) != "test_archer_bow":
		_fail("Switching form did not preserve the Bow in its own loadout.")
		return
	var knife_index := _find_item_index(inventory, "test_oriental_throwing_knife")
	if knife_index < 0 or not inventory.equip_item_from_slot(knife_index):
		_fail("Could not equip the Oriental Assassin Throwing Knife fixture.")
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
	inventory.queue_free()
	quit(0)

func _find_item_index(inventory: PlayerInventory, item_id: String) -> int:
	for index in range(inventory.slots.size()):
		var item: Variant = inventory.slots[index]
		if item is Dictionary and str(item.get("id", "")) == item_id:
			return index
	return -1

func _fail(message: String) -> void:
	push_error("ARCHER PROGRESSION FAILED: " + message)
	quit(1)
