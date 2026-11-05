extends SceneTree

const AssetCatalogScript = preload("res://scripts/core/AssetCatalog.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var entries := [
		{"asset_role": "body_part", "character_class": "Trojan", "mapping_status": "verified", "gender": "male"},
		{"asset_role": "complete_character", "character_class": "Trojan", "mapping_status": "candidate", "gender": "male"},
		{"asset_role": "complete_character", "character_class": "Trojan", "mapping_status": "verified", "gender": "male"},
		{"asset_role": "complete_character", "character_class": "Warrior", "mapping_status": "verified", "gender": "female"}
	]
	var male_trojan := AssetCatalogScript.find_verified_character_model_index(entries, "Trojan", "male")
	var female_warrior := AssetCatalogScript.find_verified_character_model_index(entries, "Warrior", "female")
	var unknown := AssetCatalogScript.find_verified_character_model_index(entries, "Thunderstriker", "male")
	var wrong_gender := AssetCatalogScript.find_verified_character_model_index(entries, "Trojan", "female")
	if male_trojan != 2 or female_warrior != 3 or unknown != -1 or wrong_gender != -1:
		push_error("CHARACTER MODEL MAPPING AUDIT FAILED: got %s, %s, %s, %s" % [male_trojan, female_warrior, unknown, wrong_gender])
		quit(1)
		return
	print("CHARACTER MODEL MAPPING AUDIT PASSED: only verified complete-character metadata is eligible")
	quit(0)
