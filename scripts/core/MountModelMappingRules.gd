extends RefCounted

static func find_verified_mount_model_index(entries: Array, requested_item_id: String) -> int:
	if requested_item_id.is_empty():
		return -1
	for index in range(entries.size()):
		var entry: Variant = entries[index]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if str(entry.get("asset_role", "")) != "complete_mount":
			continue
		if str(entry.get("mapping_status", "")).to_lower() != "verified":
			continue
		if str(entry.get("mount_item_id", "")) != requested_item_id:
			continue
		return index
	return -1
