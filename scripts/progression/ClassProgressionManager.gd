extends Node

signal progression_unlocked(path_id: String)
signal weapon_style_changed(style_id: String)
signal branch_changed(branch_id: String)

const ARCHER_FAMILY := "Archer"
const ARCHER_UNLOCK_LEVEL := 40
const STYLE_BOW := "bow"
const STYLE_THROWING_KNIVES := "throwing_knives"
const TAOIST_FAMILY := "Taoist"
const TAOIST_BRANCHES := ["WaterTaoist", "FireTaoist"]
const WINDWALKER_FAMILY := "Windwalker"
const WINDWALKER_BRANCHES := ["Stomper", "Chaser"]
const TROJAN_TRAIT_WINDIGO := "Windigo"

var character_class_id: String = ""
var progression_family: String = ""
var combat_form: String = ""
var selected_weapon_style: String = ""
var unlocked_weapon_styles: Array[String] = []
var selected_branch: String = ""
var unlocked_branches: Array[String] = []
var unlocked_traits: Array[String] = []
var last_unlock_message_ar: String = ""
var last_unlock_message_en: String = ""

func configure_for_character(class_id: String) -> void:
	character_class_id = class_id
	progression_family = class_id
	combat_form = class_id
	selected_weapon_style = ""
	selected_branch = ""
	unlocked_weapon_styles.clear()
	unlocked_branches.clear()
	unlocked_traits.clear()
	last_unlock_message_ar = ""
	last_unlock_message_en = ""
	match class_id:
		ARCHER_FAMILY:
			selected_weapon_style = STYLE_BOW
			unlocked_weapon_styles.append(STYLE_BOW)
		"WaterTaoist", "FireTaoist":
			progression_family = TAOIST_FAMILY
			selected_branch = class_id
			combat_form = class_id
			unlocked_branches.append(class_id)
		TAOIST_FAMILY:
			progression_family = TAOIST_FAMILY
		WINDWALKER_FAMILY:
			unlocked_branches.assign(WINDWALKER_BRANCHES)
			selected_branch = "Stomper"
			combat_form = selected_branch
	refresh_level_unlocks(_get_player_level())

func refresh_level_unlocks(level: int) -> bool:
	if level < ARCHER_UNLOCK_LEVEL:
		return false
	var unlocked_any := false
	var messages_ar: Array[String] = []
	var messages_en: Array[String] = []
	if progression_family == ARCHER_FAMILY and not unlocked_weapon_styles.has(STYLE_THROWING_KNIVES):
		unlocked_weapon_styles.append(STYLE_THROWING_KNIVES)
		combat_form = "OrientalAssassin"
		progression_unlocked.emit(STYLE_THROWING_KNIVES)
		messages_ar.append("فُتح مسار الرامي الشرقي: الخناجر الرامية")
		messages_en.append("Oriental Assassin path unlocked: Throwing Knives")
		unlocked_any = true
	if progression_family == TAOIST_FAMILY:
		var added_taoist_branch := false
		for branch_id in TAOIST_BRANCHES:
			if not unlocked_branches.has(branch_id):
				unlocked_branches.append(branch_id)
				added_taoist_branch = true
		if added_taoist_branch:
			progression_unlocked.emit("taoist_branches")
			messages_ar.append("فُتح مسارا طاوي الماء وطاوي النار")
			messages_en.append("Water and Fire Taoist branches unlocked")
			unlocked_any = true
	if progression_family == "Trojan" and not unlocked_traits.has(TROJAN_TRAIT_WINDIGO):
		unlocked_traits.append(TROJAN_TRAIT_WINDIGO)
		progression_unlocked.emit(TROJAN_TRAIT_WINDIGO)
		messages_ar.append("اكتسب التروجان مهارة وينديجو")
		messages_en.append("Trojan unlocked the Windigo skill")
		unlocked_any = true
	if unlocked_any:
		last_unlock_message_ar = " — ".join(messages_ar)
		last_unlock_message_en = " — ".join(messages_en)
	return unlocked_any

func is_class_compatible(required_class: String) -> bool:
	if required_class.is_empty():
		return true
	return required_class == character_class_id or required_class == progression_family or required_class == selected_branch

func is_skill_compatible(skill_definition: Dictionary) -> bool:
	if not is_class_compatible(str(skill_definition.get("class_req", ""))):
		return false
	var required_style := _normalize_style_id(str(skill_definition.get("weapon_style", "")))
	if not required_style.is_empty() and required_style != selected_weapon_style:
		return false
	var required_branch := str(skill_definition.get("required_branch", ""))
	if not required_branch.is_empty() and required_branch != selected_branch:
		return false
	var required_trait := str(skill_definition.get("required_trait", ""))
	if not required_trait.is_empty() and not unlocked_traits.has(required_trait):
		return false
	return true

func select_weapon_style(style_id: String) -> bool:
	var normalized_style := _normalize_style_id(style_id)
	if progression_family != ARCHER_FAMILY or not unlocked_weapon_styles.has(normalized_style):
		return false
	if normalized_style != STYLE_BOW and normalized_style != STYLE_THROWING_KNIVES:
		return false
	selected_weapon_style = normalized_style
	combat_form = "OrientalAssassin" if unlocked_weapon_styles.has(STYLE_THROWING_KNIVES) else ARCHER_FAMILY
	weapon_style_changed.emit(normalized_style)
	return true

func select_branch(branch_id: String) -> bool:
	if progression_family not in [TAOIST_FAMILY, WINDWALKER_FAMILY]:
		return false
	if not unlocked_branches.has(branch_id):
		return false
	if selected_branch == branch_id:
		return true
	selected_branch = branch_id
	combat_form = branch_id
	branch_changed.emit(branch_id)
	return true

func select_progression_choice(choice_id: String) -> bool:
	if progression_family == ARCHER_FAMILY:
		return select_weapon_style(choice_id)
	return select_branch(choice_id)

func get_available_weapon_styles() -> Array[String]:
	return unlocked_weapon_styles.duplicate()

func get_available_branches() -> Array[String]:
	return unlocked_branches.duplicate()

func get_available_progression_choices() -> Array[String]:
	if progression_family == ARCHER_FAMILY:
		return get_available_weapon_styles()
	if progression_family in [TAOIST_FAMILY, WINDWALKER_FAMILY]:
		return get_available_branches()
	return []

func get_selected_progression_choice() -> String:
	if progression_family == ARCHER_FAMILY:
		return selected_weapon_style
	return selected_branch

func get_unlocked_traits() -> Array[String]:
	return unlocked_traits.duplicate()

func has_unlocked_trait(trait_id: String) -> bool:
	return unlocked_traits.has(trait_id)

func get_last_unlock_message(language: String = "ar") -> String:
	return last_unlock_message_ar if language == "ar" else last_unlock_message_en

func get_selection_message(choice_id: String, language: String = "ar") -> String:
	var labels := {
		"bow": ["تم اختيار أسلوب القوس", "Bow combat style selected"],
		"throwing_knives": ["تم اختيار أسلوب الخناجر الرامية", "Throwing Knives combat style selected"],
		"WaterTaoist": ["تم اختيار مسار طاوي الماء", "Water Taoist branch selected"],
		"FireTaoist": ["تم اختيار مسار طاوي النار", "Fire Taoist branch selected"],
		"Stomper": ["تم اختيار مسار ستومبر القتالي", "Stomper combat branch selected"],
		"Chaser": ["تم اختيار مسار تشيسر القتالي", "Chaser combat branch selected"]
	}
	if not labels.has(choice_id):
		return ""
	return labels[choice_id][0] if language == "ar" else labels[choice_id][1]

func get_form_id() -> String:
	return combat_form

func serialize() -> Dictionary:
	return {
		"character_class_id": character_class_id,
		"progression_family": progression_family,
		"combat_form": combat_form,
		"selected_weapon_style": selected_weapon_style,
		"unlocked_weapon_styles": unlocked_weapon_styles.duplicate(),
		"selected_branch": selected_branch,
		"unlocked_branches": unlocked_branches.duplicate(),
		"unlocked_traits": unlocked_traits.duplicate()
	}

func deserialize(data: Dictionary) -> void:
	var saved_class := str(data.get("character_class_id", data.get("progression_family", "")))
	configure_for_character(saved_class)
	var saved_styles: Array = data.get("unlocked_weapon_styles", [])
	for raw_style in saved_styles:
		var style_id := _normalize_style_id(str(raw_style))
		if style_id in [STYLE_BOW, STYLE_THROWING_KNIVES] and not unlocked_weapon_styles.has(style_id):
			unlocked_weapon_styles.append(style_id)
	var saved_branches: Array = data.get("unlocked_branches", [])
	for raw_branch in saved_branches:
		var branch_id := str(raw_branch)
		if branch_id in TAOIST_BRANCHES + WINDWALKER_BRANCHES and not unlocked_branches.has(branch_id):
			unlocked_branches.append(branch_id)
	var saved_traits: Array = data.get("unlocked_traits", [])
	for raw_trait in saved_traits:
		var trait_id := str(raw_trait)
		if trait_id == TROJAN_TRAIT_WINDIGO and not unlocked_traits.has(trait_id):
			unlocked_traits.append(trait_id)
	var saved_style := _normalize_style_id(str(data.get("selected_weapon_style", selected_weapon_style)))
	if unlocked_weapon_styles.has(saved_style):
		selected_weapon_style = saved_style
	var saved_branch := str(data.get("selected_branch", selected_branch))
	if unlocked_branches.has(saved_branch):
		selected_branch = saved_branch
	if not selected_branch.is_empty():
		combat_form = selected_branch
	elif progression_family == ARCHER_FAMILY and unlocked_weapon_styles.has(STYLE_THROWING_KNIVES):
		combat_form = "OrientalAssassin"
	refresh_level_unlocks(_get_player_level())

func _normalize_style_id(style_id: String) -> String:
	return STYLE_THROWING_KNIVES if style_id == "flying_daggers" else style_id

func _get_player_level() -> int:
	if GameManager and is_instance_valid(GameManager.player_reference):
		return int(GameManager.player_reference.get("current_level"))
	return 1
