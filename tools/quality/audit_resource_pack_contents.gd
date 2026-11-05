extends SceneTree

const PACK_NAMES := [
	"animations.pck", "audio.pck", "characters.pck", "effects.pck",
	"equipment.pck", "interface.pck", "maps.pck", "models.pck",
	"monsters.pck", "mounts.pck", "world.pck"
]
const MODEL_EXTENSIONS := ["glb", "gltf"]
const MAX_MODEL_INSPECTIONS := 2000

func _initialize() -> void:
	call_deferred("_run_audit")

func _run_audit() -> void:
	var report: Dictionary = {
		"engine": Engine.get_version_info(),
		"pack_mounts": {},
		"extension_counts": {},
		"model_files_found": 0,
		"models_loaded": 0,
		"models_with_renderable_meshes": 0,
		"models_with_skeletons": 0,
		"models_with_animations": 0,
		"models_failed": [],
		"model_samples": [],
		"visual_geometry": {
			"mesh_instances": 0,
			"surfaces": 0,
			"degenerate_meshes": 0
		}
	}
	for pack_name in PACK_NAMES:
		var pack_path := "res://ci-resource-packs/" + pack_name
		var mounted := FileAccess.file_exists(pack_path) and ProjectSettings.load_resource_pack(pack_path, true)
		report["pack_mounts"][pack_name] = mounted
		print("PCK_MOUNT ", pack_name, " ", mounted)
		if not mounted:
			push_error("RESOURCE PACK AUDIT FAILED: could not mount " + pack_name)
			_write_report(report)
			quit(1)
			return

	var model_paths: Array[String] = []
	_walk_directory("res://", report["extension_counts"], model_paths)
	report["model_files_found"] = model_paths.size()
	model_paths.sort()
	var inspect_count := mini(model_paths.size(), MAX_MODEL_INSPECTIONS)
	for index in range(inspect_count):
		var path := model_paths[index]
		var resource := ResourceLoader.load(path)
		if not resource is PackedScene:
			report["models_failed"].append({"path": path, "reason": "not a PackedScene"})
			continue
		var instance := (resource as PackedScene).instantiate()
		if instance == null:
			report["models_failed"].append({"path": path, "reason": "instantiate returned null"})
			continue
		report["models_loaded"] += 1
		var metrics := _inspect_node(instance)
		report["visual_geometry"]["mesh_instances"] += metrics["mesh_instances"]
		report["visual_geometry"]["surfaces"] += metrics["surfaces"]
		report["visual_geometry"]["degenerate_meshes"] += metrics["degenerate_meshes"]
		if metrics["mesh_instances"] > 0 and metrics["surfaces"] > 0:
			report["models_with_renderable_meshes"] += 1
		else:
			report["models_failed"].append({"path": path, "reason": "no renderable mesh surfaces"})
		if metrics["skeletons"] > 0:
			report["models_with_skeletons"] += 1
		if metrics["animations"] > 0:
			report["models_with_animations"] += 1
		if report["model_samples"].size() < 100:
			report["model_samples"].append({"path": path, "metrics": metrics})
		instance.free()

	report["model_inspection_limit"] = MAX_MODEL_INSPECTIONS
	report["model_inspection_truncated"] = model_paths.size() > MAX_MODEL_INSPECTIONS
	_write_report(report)
	print("RESOURCE PACK CONTENT AUDIT: ", JSON.stringify({
		"packs_mounted": report["pack_mounts"].size(),
		"model_files_found": report["model_files_found"],
		"models_loaded": report["models_loaded"],
		"models_with_renderable_meshes": report["models_with_renderable_meshes"],
		"models_with_skeletons": report["models_with_skeletons"],
		"models_with_animations": report["models_with_animations"],
		"extension_counts": report["extension_counts"],
		"geometry": report["visual_geometry"]
	}))
	if report["models_with_renderable_meshes"] == 0:
		push_error("RESOURCE PACK AUDIT FAILED: no loadable 3D model with renderable mesh surfaces was found.")
		quit(1)
		return
	if report["models_failed"].size() > 0:
		print("RESOURCE MODEL WARNINGS: ", report["models_failed"].size())
	quit(0)

func _walk_directory(path: String, counts: Dictionary, model_paths: Array[String]) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry.begins_with(".") or entry == "ci-resource-packs":
			entry = directory.get_next()
			continue
		var full_path := path.path_join(entry)
		if directory.current_is_dir():
			_walk_directory(full_path, counts, model_paths)
		else:
			var extension := entry.get_extension().to_lower()
			counts[extension] = int(counts.get(extension, 0)) + 1
			if extension in MODEL_EXTENSIONS:
				model_paths.append(full_path)
		entry = directory.get_next()
	directory.list_dir_end()

func _inspect_node(root: Node) -> Dictionary:
	var result: Dictionary = {
		"mesh_instances": 0,
		"surfaces": 0,
		"degenerate_meshes": 0,
		"skeletons": 0,
		"animations": 0
	}
	_inspect_node_recursive(root, result)
	return result

func _inspect_node_recursive(node: Node, result: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			result["mesh_instances"] += 1
			var surface_count := mesh_instance.mesh.get_surface_count()
			result["surfaces"] += surface_count
			var bounds := mesh_instance.mesh.get_aabb()
			if surface_count == 0 or bounds.size.length() < 0.0001:
				result["degenerate_meshes"] += 1
	if node is Skeleton3D:
		result["skeletons"] += 1
	if node is AnimationPlayer:
		var player := node as AnimationPlayer
		result["animations"] += player.get_animation_list().size()
	for child in node.get_children():
		_inspect_node_recursive(child, result)

func _write_report(report: Dictionary) -> void:
	var file := FileAccess.open("res://resource-pack-audit.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
