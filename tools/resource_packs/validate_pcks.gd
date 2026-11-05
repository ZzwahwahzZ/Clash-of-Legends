extends SceneTree

const MODEL_CATEGORIES := ["characters", "monsters", "mounts", "equipment"]

func _initialize() -> void:
	call_deferred("_validate_packages")

func _validate_packages() -> void:
	var directory := DirAccess.open("res://build/pcks")
	if directory == null:
		_fail("build/pcks directory is missing.")
		return
	var pack_files := directory.get_files()
	var loaded_count := 0
	for filename in pack_files:
		if not filename.to_lower().ends_with(".pck"):
			continue
		var pack_path := "res://build/pcks/" + filename
		if not ProjectSettings.load_resource_pack(pack_path, true):
			_fail("Godot rejected " + filename)
			return
		loaded_count += 1
	if loaded_count < 11:
		_fail("Expected eleven non-empty category packages; loaded %d." % loaded_count)
		return

	var catalog_path := "res://resource_stage/world/resource_catalog.json"
	if not FileAccess.file_exists(catalog_path):
		_fail("Runtime resource catalog is missing from world PCK.")
		return
	var catalog_file := FileAccess.open(catalog_path, FileAccess.READ)
	var parser := JSON.new()
	if catalog_file == null or parser.parse(catalog_file.get_as_text()) != OK:
		_fail("Runtime catalog cannot be parsed.")
		return
	catalog_file.close()
	var catalog: Dictionary = parser.data
	var assets: Dictionary = catalog.get("assets", {})
	for required_category in ["characters", "monsters", "maps", "equipment", "mounts", "effects", "animations", "interface", "audio", "models", "world"]:
		var entries: Array = assets.get(required_category, [])
		if entries.is_empty():
			_fail("Category is empty: " + required_category)
			return
		print("PCK category OK: ", required_category, " (", entries.size(), " entries)")

	# Inspect every supported model scene, not just the first entry in each category.
	var total_models := 0
	var valid_models := 0
	var animated_models := 0
	var invalid_models: Array[String] = []
	for model_category in MODEL_CATEGORIES:
		var category_entries: Array = []
		for entry in assets.get(model_category, []):
			var ext := str(entry.get("extension", "")).to_lower()
			if ext == ".glb" or ext == ".gltf":
				category_entries.append(entry)
		if category_entries.is_empty():
			_fail("No GLB/glTF models in " + model_category)
			return

		var category_valid := 0
		for entry in category_entries:
			total_models += 1
			var relative_path := str(entry.get("path", ""))
			var model_path := "res://" + relative_path
			var packed_model := ResourceLoader.load(model_path) as PackedScene
			if packed_model == null:
				invalid_models.append(model_category + ":" + relative_path + " (not a PackedScene)")
				continue
			var instance := packed_model.instantiate()
			var mesh_nodes := _collect_mesh_instances(instance)
			var model_ok := not mesh_nodes.is_empty()
			var surface_total := 0
			for mesh_node in mesh_nodes:
				var mesh_instance := mesh_node as MeshInstance3D
				if mesh_instance == null or mesh_instance.mesh == null:
					model_ok = false
					continue
				var surfaces := mesh_instance.mesh.get_surface_count()
				if surfaces <= 0:
					model_ok = false
					continue
				surface_total += surfaces
				var bounds := mesh_instance.get_aabb()
				if not _valid_vector3(bounds.position) or not _valid_vector3(bounds.size):
					model_ok = false
				if bounds.size.x <= 0.0001 or bounds.size.y <= 0.0001 or bounds.size.z <= 0.0001:
					model_ok = false
			var animation_player := instance.find_child("*", "AnimationPlayer", true, false)
			var animation_count := 0
			if animation_player is AnimationPlayer:
				animation_count = animation_player.get_animation_list().size()
				if animation_count > 0:
					animated_models += 1
			if model_ok:
				category_valid += 1
				valid_models += 1
				print("MODEL VISUAL OK: ", model_category, " | ", relative_path, " | mesh_nodes=", mesh_nodes.size(), " | surfaces=", surface_total, " | animations=", animation_count)
			else:
				invalid_models.append(model_category + ":" + relative_path + " (empty mesh, surface, or invalid bounds)")
			instance.free()

		print("MODEL CATEGORY SUMMARY: ", model_category, " | valid=", category_valid, "/", category_entries.size())
		if category_valid == 0:
			_fail("No renderable GLB/glTF models passed visual geometry checks in " + model_category)
			return

	print("MODEL VISUAL SUMMARY: ", valid_models, "/", total_models, " valid scenes; ", invalid_models.size(), " rejected.")
	for issue in invalid_models:
		push_warning("MODEL VISUAL REJECTED: " + issue)

	# Confirm at least one real original C3 source file is retained for future conversion.
	var c3_found := false
	for entry in assets.get("models", []):
		if str(entry.get("extension", "")).to_lower() == ".c3":
			var c3_path := "res://" + str(entry.get("path", ""))
			if FileAccess.file_exists(c3_path):
				c3_found = true
				print("PCK original C3 source retained: ", c3_path)
				break
	if not c3_found:
		_fail("Extracted original C3 model files are missing.")
		return

	var audio_path := ""
	for entry in assets.get("audio", []):
		if str(entry.get("extension", "")).to_lower() == ".ogg":
			audio_path = "res://" + str(entry.get("path", ""))
			if FileAccess.file_exists(audio_path):
				break
			audio_path = ""
	if audio_path.is_empty():
		_fail("Playable OGG audio source file is missing.")
		return
	print("PCK audio source OK: ", audio_path)
	if animated_models == 0:
		_fail("No supported GLB/glTF model exposes an imported animation track.")
		return
	print("PCK ANIMATION SUMMARY: ", animated_models, "/", total_models, " model scenes expose imported animation tracks.")
	print("PCK VALIDATION PASSED: ", loaded_count, " packages; ", valid_models, "/", total_models, " supported model scenes have renderable geometry.")
	quit(0)

func _collect_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		found.append(root as MeshInstance3D)
	for child in root.get_children():
		found.append_array(_collect_mesh_instances(child))
	return found

func _valid_vector3(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

func _fail(message: String) -> void:
	push_error("PCK VISUAL VALIDATION FAILED: " + message)
	quit(1)
