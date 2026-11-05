extends Node

signal progression_unlocked(style_id: String)
signal weapon_style_changed(style_id: String)

# A character keeps one progression family. Archer -> Oriental Assassin is a
# level-gated combat-path unlock, not the creation of a second unrelated class.
const ARCHER_FAMILY := "Archer"
const ARCHER_UNLOCK_LEVEL := 40
const STYLE_BOW := "bow"
const STYLE_FLYING_DAGGERS := "flying_daggers"

var progression_family: String = ""
var combat_form: String = ""
var selected_weapon_style: String = ""
var unlocked_weapon_styles: Array[String] = []

func configure_for_character(class_id: String) -> void:
	progression_family = class_id
	combat_form = class_id
	selected_weapon_style = ""
	unlocked_weapon_styles.clear()
	if class_id == ARCHER_FAMILY:
		selected_weapon_style = STYLE_BOW
		unlocked_weapon_styles.append(STYLE_BOW)
		refresh_level_unlocks(_get_player_level())

func refresh_level_unlocks(level: int) -> bool:
	if progression_family != ARCHER_FAMILY or level < ARCHER_UNLOCK_LEVEL:
		return false
	if unlocked_weapon_styles.has(STYLE_FLYING_DAGGERS):
		return false
	unlocked_weapon_styles.append(STYLE_FLYING_DAGGERS)
	combat_form = "OrientalAssassin"
	emit_signal("progression_unlocked", STYLE_FLYING_DAGGERS)
	return true

func select_weapon_style(style_id: String) -> bool:
	if progression_family != ARCHER_FAMILY:
		return false
	if not unlocked_weapon_styles.has(style_id):
		return false
	if style_id != STYLE_BOW and style_id != STYLE_FLYING_DAGGERS:
		return false
	selected_weapon_style = style_id
	# The advancement remains unlocked even when the player switches back to bow.
	combat_form = "OrientalAssassin" if unlocked_weapon_styles.has(STYLE_FLYING_DAGGERS) else ARCHER_FAMILY
	emit_signal("weapon_style_changed", style_id)
	return true

func is_skill_compatible(skill_definition: Dictionary) -> bool:
	var required_class := str(skill_definition.get("class_req", ""))
	if required_class != "" and required_class != progression_family:
		return false
	var required_style := str(skill_definition.get("weapon_style", ""))
	return required_style == "" or required_style == selected_weapon_style

func get_available_weapon_styles() -> Array[String]:
	return unlocked_weapon_styles.duplicate()

func get_form_id() -> String:
	return combat_form

func serialize() -> Dictionary:
	return {
		"progression_family": progression_family,
		"combat_form": combat_form,
		"selected_weapon_style": selected_weapon_style,
		"unlocked_weapon_styles": unlocked_weapon_styles.duplicate()
	}

func deserialize(data: Dictionary) -> void:
	var family := str(data.get("progression_family", ""))
	configure_for_character(family)
	var saved_styles: Array = data.get("unlocked_weapon_styles", [])
	if family == ARCHER_FAMILY and saved_styles.has(STYLE_FLYING_DAGGERS):
		unlocked_weapon_styles.append(STYLE_FLYING_DAGGERS)
		combat_form = "OrientalAssassin"
	var saved_style := str(data.get("selected_weapon_style", STYLE_BOW if family == ARCHER_FAMILY else ""))
	if unlocked_weapon_styles.has(saved_style):
		selected_weapon_style = saved_style

func _get_player_level() -> int:
	if is_instance_valid(GameManager.player_reference):
		return int(GameManager.player_reference.get("current_level"))
	return 1
