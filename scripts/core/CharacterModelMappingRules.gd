extends RefCounted

static func find_verified_character_model_index(entries: Array, requested_class: String, requested_gender: String = "") -> int:
	for index in range(entries.size()):
		var entry: Variant = entries[index]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if str(entry.get("asset_role", "")) != "complete_character":
			continue
		if str(entry.get("mapping_status", "")).to_lower() != "verified":
			continue
		if str(entry.get("character_class", "")) != requested_class:
			continue
		var entry_gender := str(entry.get("gender", ""))
		if not requested_gender.is_empty() and entry_gender != requested_gender:
			continue
		return index
	return -1
