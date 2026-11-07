extends Node

const CharacterModelMappingRules = preload("res://scripts/core/CharacterModelMappingRules.gd")
const MountModelMappingRules = preload("res://scripts/core/MountModelMappingRules.gd")
## Runtime index for verified resource PCK contents.

signal catalog_loaded(asset_count: int)

var assets_by_category: Dictionary = {}
var catalog_version: int = 0
var character_vat_clips: Dictionary = {}

func _ready() -> void:
	if ResourcePackManager:
		ResourcePackManager.package_installed.connect(_on_package_installed)
	call_deferred("_reload_catalog")

func _on_package_installed(_package_id: String, _path: String) -> void:
	_reload_catalog()

func _reload_catalog() -> bool:
	var catalog_path := "res://resource_stage/world/resource_catalog.json"
	if not FileAccess.file_exists(catalog_path):
		return false
	var file := FileAccess.open(catalog_path, FileAccess.READ)
	if file == null:
		return false
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	if error != OK or typeof(parser.data) != TYPE_DICTIONARY:
		push_error("Resource catalog JSON is invalid.")
		return false
	var candidate: Dictionary = parser.data
	var assets: Variant = candidate.get("assets", {})
	if typeof(assets) != TYPE_DICTIONARY:
		return false
	assets_by_category = assets
	character_vat_clips = candidate.get("character_vat_clips", {}) if candidate.get("character_vat_clips", {}) is Dictionary else {}
	catalog_version = int(candidate.get("catalog_version", 0))
	var count := 0
	for category in assets_by_category:
		if assets_by_category[category] is Array:
			count += assets_by_category[category].size()
	catalog_loaded.emit(count)
	return true

func get_asset_entries(category: String, extension_filter: Array[String] = []) -> Array:
	var entries: Variant = assets_by_category.get(category, [])
	if typeof(entries) != TYPE_ARRAY:
		return []
	if extension_filter.is_empty():
		return entries.duplicate(true)
	var filtered: Array = []
	for entry in entries:
		var ext := str(entry.get("extension", "")).to_lower()
		if extension_filter.has(ext):
			filtered.append(entry.duplicate(true))
	return filtered

func get_asset_path(category: String, index: int) -> String:
	var entries: Array = get_asset_entries(category)
	if index < 0 or index >= entries.size():
		return ""
	return "res://" + str(entries[index].get("path", ""))

func load_model_scene(category: String, index: int) -> PackedScene:
	var model_extensions: Array[String] = [".glb", ".gltf"]
	var entries := get_asset_entries(category, model_extensions)
	if index < 0 or index >= entries.size():
		return null
	var path := "res://" + str(entries[index].get("path", ""))
	if path.is_empty():
		return null
	var resource := ResourceLoader.load(path)
	if resource is PackedScene:
		return resource
	return null

func instantiate_fitted_model(category: String, index: int, parent: Node3D, target_height: float = 1.7, node_name: String = "ImportedModel") -> Node3D:
	if parent == null or target_height <= 0.0:
		return null
	var packed_model := load_model_scene(category, index)
	if packed_model == null:
		return null
	var root := Node3D.new()
	root.name = node_name
	parent.add_child(root)
	var instance := packed_model.instantiate()
	root.add_child(instance)
	var combined_bounds := AABB()
	var has_bounds := false
	for mesh_node in instance.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance and mesh_instance.mesh:
			var relative_transform := _relative_transform_to_root(root, mesh_instance)
			var mesh_bounds: AABB = _transform_aabb(mesh_instance.mesh.get_aabb(), relative_transform)
			combined_bounds = mesh_bounds if not has_bounds else combined_bounds.merge(mesh_bounds)
			has_bounds = true
	if has_bounds and combined_bounds.size.y > 0.001:
		var fit_scale := target_height / combined_bounds.size.y
		root.scale = Vector3.ONE * fit_scale
		root.position = Vector3(
			-(combined_bounds.position.x + combined_bounds.size.x * 0.5) * fit_scale,
			-combined_bounds.position.y * fit_scale,
			-(combined_bounds.position.z + combined_bounds.size.z * 0.5) * fit_scale
		)
	return root

func _relative_transform_to_root(root: Node3D, node: Node3D) -> Transform3D:
	var relative := Transform3D.IDENTITY
	var cursor: Node = node
	while cursor != null and cursor != root:
		if cursor is Node3D:
			relative = (cursor as Node3D).transform * relative
		cursor = cursor.get_parent()
	if cursor != root:
		return Transform3D.IDENTITY
	return relative

func _transform_aabb(bounds: AABB, transform: Transform3D) -> AABB:
	var corners := [
		bounds.position,
		bounds.position + Vector3(bounds.size.x, 0.0, 0.0),
		bounds.position + Vector3(0.0, bounds.size.y, 0.0),
		bounds.position + Vector3(0.0, 0.0, bounds.size.z),
		bounds.position + Vector3(bounds.size.x, bounds.size.y, 0.0),
		bounds.position + Vector3(bounds.size.x, 0.0, bounds.size.z),
		bounds.position + Vector3(0.0, bounds.size.y, bounds.size.z),
		bounds.position + bounds.size
	]
	var first_point: Vector3 = transform * corners[0]
	var minimum := first_point
	var maximum := first_point
	for index in range(1, corners.size()):
		var point: Vector3 = transform * corners[index]
		minimum = Vector3(minf(minimum.x, point.x), minf(minimum.y, point.y), minf(minimum.z, point.z))
		maximum = Vector3(maxf(maximum.x, point.x), maxf(maximum.y, point.y), maxf(maximum.z, point.z))
	return AABB(minimum, maximum - minimum)

func has_category(category: String) -> bool:
	return assets_by_category.has(category) and assets_by_category[category] is Array and not assets_by_category[category].is_empty()

func get_category_counts() -> Dictionary:
	var counts: Dictionary = {}
	for category in assets_by_category:
		counts[category] = assets_by_category[category].size() if assets_by_category[category] is Array else 0
	return counts

func get_character_vat_base_model_path(model_id: int) -> String:
	var record: Variant = character_vat_clips.get(str(model_id), {})
	if not (record is Dictionary):
		return ""
	var path := str(record.get("base_model_path", ""))
	return "res://" + path if not path.is_empty() else ""

func get_character_vat_clip(model_id: int, state: String) -> Dictionary:
	var record: Variant = character_vat_clips.get(str(model_id), {})
	if not (record is Dictionary):
		return {}
	var states: Variant = record.get("states", {})
	if not (states is Dictionary):
		return {}
	var clip: Variant = states.get(state.to_lower(), {})
	if not (clip is Dictionary):
		return {}
	var result: Dictionary = clip.duplicate(true)
	var paths: Array[String] = []
	for relative_path in result.get("metadata_paths", []):
		var relative := str(relative_path)
		paths.append("res://" + relative if not relative.is_empty() else "")
	result["metadata_paths"] = paths
	return result

func has_character_vat_animation(model_id: int) -> bool:
	var record: Variant = character_vat_clips.get(str(model_id), {})
	return record is Dictionary and record.get("states", {}) is Dictionary and (record.get("states", {}) as Dictionary).size() >= 3

func get_verified_character_model_index(requested_class: String, requested_gender: String = "") -> int:
	var entries := get_asset_entries("characters", [".glb", ".gltf"])
	return CharacterModelMappingRules.find_verified_character_model_index(entries, requested_class, requested_gender)

func get_verified_mount_model_index(requested_item_id: String) -> int:
	var entries := get_asset_entries("mounts", [".glb", ".gltf"])
	return MountModelMappingRules.find_verified_mount_model_index(entries, requested_item_id)

func get_verified_weapon_model_index(item_id: String) -> int:
	if item_id.is_empty():
		return -1
	var entries := get_asset_entries("equipment", [".glb", ".gltf"])
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		if str(entry.get("asset_role", "")) != "weapon_visual_candidate":
			continue
		if str(entry.get("mapping_status", "")) != "source_join_verified":
			continue
		var item_ids: Variant = entry.get("source_item_ids", [])
		if item_ids is Array and item_ids.has(item_id):
			return index
	return -1

func instantiate_fitted_weapon_model(item_id: String, parent: Node3D, target_height: float = 1.0) -> Node3D:
	if parent == null or target_height <= 0.0:
		return null
	var index := get_verified_weapon_model_index(item_id)
	if index < 0:
		return null
	var packed_model := load_model_scene("equipment", index)
	if packed_model == null:
		return null
	var root := Node3D.new()
	root.name = "WeaponCandidate"
	# Converted C3 weapon meshes use Z as their long axis; rotate Z-up into Godot Y-up.
	root.rotation.x = PI * 0.5
	parent.add_child(root)
	var instance := packed_model.instantiate()
	root.add_child(instance)
	var combined_bounds := AABB()
	var has_bounds := false
	for mesh_node in instance.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var relative_transform := _relative_transform_to_root(root, mesh_instance)
		var mesh_bounds := _transform_aabb(mesh_instance.mesh.get_aabb(), relative_transform)
		combined_bounds = mesh_bounds if not has_bounds else combined_bounds.merge(mesh_bounds)
		has_bounds = true
	if not has_bounds or combined_bounds.size.y <= 0.001:
		root.queue_free()
		return null
	var fit_scale := target_height / combined_bounds.size.y
	root.scale = Vector3.ONE * fit_scale
	root.position = Vector3(
		-(combined_bounds.position.x + combined_bounds.size.x * 0.5) * fit_scale,
		-combined_bounds.position.y * fit_scale,
		-(combined_bounds.position.z + combined_bounds.size.z * 0.5) * fit_scale
	)
	return root
