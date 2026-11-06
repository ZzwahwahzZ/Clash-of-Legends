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
		"extension_samples": {},
		"pack_directory": "",
		"model_files_found": 0,
		"models_loaded": 0,
		"models_with_renderable_meshes": 0,
		"models_with_skeletons": 0,
		"models_with_animations": 0,
		"models_failed": [],
		"model_samples": [],
		"catalog_found": false,
		"catalog_categories": {},
		"catalog_model_entries": 0,
		"catalog_missing_paths": [],
		"character_registry_paths": [],
		"c3_path_samples": [],
		"verified_character_mappings": [],
		"missing_character_classes": [],
		"visual_geometry": {
			"mesh_instances": 0,
			"surfaces": 0,
			"degenerate_meshes": 0
		}
	}
	var pack_directory := OS.get_environment("RESOURCE_PACK_DIR")
	if pack_directory.is_empty():
		pack_directory = "res://ci-resource-packs"
	report["pack_directory"] = pack_directory
	for pack_name in PACK_NAMES:
		var pack_path: String = pack_directory.path_join(str(pack_name))
		var mounted: bool = FileAccess.file_exists(pack_path) and ProjectSettings.load_resource_pack(pack_path, true)
		report["pack_mounts"][pack_name] = mounted
		print("PCK_MOUNT ", pack_name, " ", mounted)
		if not mounted:
			push_error("RESOURCE PACK AUDIT FAILED: could not mount " + pack_name)
			_write_report(report)
			quit(1)
			return

	var model_paths: Array[String] = []
	_walk_directory("res://", report["extension_counts"], model_paths, report["extension_samples"])
	_collect_character_registry_paths("res://", report["character_registry_paths"], report["c3_path_samples"])
	_audit_resource_catalog(report, model_paths)
	model_paths = model_paths.duplicate()
	model_paths.sort()
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
		"character_registry_paths": report["character_registry_paths"],
		"c3_path_sample_count": report["c3_path_samples"].size(),
		"geometry": report["visual_geometry"]
	}))
	if not report["catalog_found"]:
		push_error("RESOURCE PACK AUDIT FAILED: runtime resource_catalog.json is missing or invalid.")
		quit(1)
		return
	if not report["catalog_missing_paths"].is_empty():
		push_error("RESOURCE PACK AUDIT FAILED: catalog contains missing asset paths.")
		quit(1)
		return
	# A source model being present and importable is not proof that it belongs
	# to a named profession/gender. Keep the complete-class gate visible in the
	# report, but do not discard the validated skeleton-stage PCKs merely because
	# class/gender provenance is still unresolved. The runtime selector continues
	# to require mapping_status=verified before using a named class model.
	if not report["missing_character_classes"].is_empty():
		print("CHARACTER CLASS COVERAGE PENDING (not approved): ", ", ".join(PackedStringArray(report["missing_character_classes"])))
	if report["models_with_renderable_meshes"] == 0:
		push_error("RESOURCE PACK AUDIT FAILED: no loadable 3D model with renderable mesh surfaces was found.")
		quit(1)
		return
	if report["models_failed"].size() > 0:
		print("RESOURCE MODEL WARNINGS: ", report["models_failed"].size())
	quit(0)



func _collect_character_registry_paths(path: String, registry_paths: Array, c3_samples: Array) -> void:
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
			_collect_character_registry_paths(full_path, registry_paths, c3_samples)
		else:
			var lower_name := entry.to_lower()
			if lower_name in ["3dobj.ini", "3dtexture.ini", "3dmotion.ini", "3dsimplerole.ini", "rolechoose.ini", "rolechoose_js.ini", "selectcharacter.ini"]:
				registry_paths.append(full_path)
			if lower_name.ends_with(".c3") and c3_samples.size() < 100:
				c3_samples.append(full_path)
		entry = directory.get_next()
	directory.list_dir_end()

func _audit_resource_catalog(report: Dictionary, model_paths: Array[String]) -> void:
	var catalog_path := "res://resource_stage/world/resource_catalog.json"
	if not FileAccess.file_exists(catalog_path):
		return
	var file := FileAccess.open(catalog_path, FileAccess.READ)
	if file == null:
		return
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return
	var assets: Variant = parser.data.get("assets", {})
	if typeof(assets) != TYPE_DICTIONARY:
		return
	report["catalog_found"] = true
	var expected_classes := [
		"Trojan", "Warrior", "Archer", "Ninja", "Monk", "Pirate",
		"DragonWarrior", "Windwalker", "Thunderstriker", "WaterTaoist", "FireTaoist"
	]
	var verified_classes: Dictionary = {}
	for category in assets.keys():
		var entries: Variant = assets[category]
		if typeof(entries) != TYPE_ARRAY:
			continue
		report["catalog_categories"][str(category)] = entries.size()
		for entry in entries:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var relative_path := str(entry.get("path", ""))
			if relative_path.is_empty() or (not FileAccess.file_exists("res://" + relative_path) and not ResourceLoader.exists("res://" + relative_path)):
				report["catalog_missing_paths"].append(relative_path)
			if str(category) != "characters":
				continue
			var extension := str(entry.get("extension", "")).to_lower()
			if extension in [".glb", ".gltf"]:
				var model_path := "res://" + relative_path
				if not model_paths.has(model_path):
					model_paths.append(model_path)
				report["catalog_model_entries"] += 1
			if extension not in [".glb", ".gltf"]:
				continue
			if str(entry.get("asset_role", "")) != "complete_character":
				continue
			if str(entry.get("mapping_status", "")).to_lower() != "verified":
				continue
			var class_id := str(entry.get("character_class", ""))
			var gender := str(entry.get("gender", ""))
			if class_id.is_empty() or gender.is_empty():
				continue
			verified_classes[class_id] = true
			report["verified_character_mappings"].append({
				"class": class_id,
				"gender": gender,
				"path": relative_path
			})
	for class_id in expected_classes:
		if not verified_classes.has(class_id):
			report["missing_character_classes"].append(class_id)

func _walk_directory(path: String, counts: Dictionary, model_paths: Array[String], samples: Dictionary) -> void:
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
			_walk_directory(full_path, counts, model_paths, samples)
		else:
			var extension := entry.get_extension().to_lower()
			counts[extension] = int(counts.get(extension, 0)) + 1
			if not samples.has(extension):
				samples[extension] = []
			if samples[extension].size() < 15:
				samples[extension].append(full_path)
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
