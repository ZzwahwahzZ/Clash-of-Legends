extends SceneTree

func _initialize() -> void:
	call_deferred("_validate_packages")

func _validate_packages() -> void:
	var directory := DirAccess.open("res://build/pcks")
	if directory == null:
		push_error("PCK validation: build/pcks directory is missing.")
		quit(1)
		return
	var pack_files := directory.get_files()
	var loaded_count := 0
	for filename in pack_files:
		if not filename.to_lower().ends_with(".pck"):
			continue
		var pack_path := "res://build/pcks/" + filename
		if not ProjectSettings.load_resource_pack(pack_path, true):
			push_error("PCK validation: Godot rejected " + filename)
			quit(1)
			return
		loaded_count += 1
	if loaded_count < 6:
		push_error("PCK validation: expected at least six real category packages.")
		quit(1)
		return
	var catalog_path := "res://resource_stage/world/resource_catalog.json"
	if not FileAccess.file_exists(catalog_path):
		push_error("PCK validation: runtime resource catalog is missing from world PCK.")
		quit(1)
		return
	var catalog_file := FileAccess.open(catalog_path, FileAccess.READ)
	var parser := JSON.new()
	if catalog_file == null or parser.parse(catalog_file.get_as_text()) != OK:
		push_error("PCK validation: runtime catalog cannot be parsed.")
		quit(1)
		return
	catalog_file.close()
	var catalog: Dictionary = parser.data
	var assets: Dictionary = catalog.get("assets", {})
	for required_category in ["characters", "monsters", "maps", "equipment", "mounts", "effects", "animations", "interface", "audio", "world"]:
		var entries: Array = assets.get(required_category, [])
		if entries.is_empty():
			push_error("PCK validation: category is empty: " + required_category)
			quit(1)
			return
		print("PCK category OK: ", required_category, " (", entries.size(), " entries)")
	for model_category in ["characters", "monsters", "mounts", "equipment"]:
		var model_entries: Array = []
		for entry in assets.get(model_category, []):
			var ext := str(entry.get("extension", "")).to_lower()
			if ext == ".glb" or ext == ".gltf":
				model_entries.append(entry)
		if model_entries.is_empty():
			push_error("PCK validation: no GLB/glTF models in " + model_category)
			quit(1)
			return
		var model_path := "res://" + str(model_entries[0].get("path", ""))
		var model_resource := ResourceLoader.load(model_path) as PackedScene
		if model_resource == null:
			push_error("PCK validation: GLB model failed to load as PackedScene: " + model_path)
			quit(1)
			return
		var model_instance := model_resource.instantiate()
		var mesh_count := model_instance.find_children("*", "MeshInstance3D", true, false).size()
		if mesh_count < 1:
			push_error("PCK validation: model has no renderable meshes: " + model_path)
			quit(1)
			return
		print("PCK model OK: ", model_category, " -> ", model_path, " | meshes: ", mesh_count)
		model_instance.free()
	var audio_entries: Array = assets.get("audio", [])
	var audio_path := ""
	for entry in audio_entries:
		if str(entry.get("extension", "")).to_lower() == ".ogg":
			audio_path = "res://" + str(entry.get("path", ""))
			break
	if audio_path.is_empty() or not FileAccess.file_exists(audio_path):
		push_error("PCK validation: playable audio source file is missing.")
		quit(1)
		return
	print("PCK audio file OK: ", audio_path)
	print("PCK VALIDATION PASSED: ", loaded_count, " category packages loaded and indexed.")
	quit(0)
