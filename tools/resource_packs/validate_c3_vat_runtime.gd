extends SceneTree

const MODELS := [
	{"id": 7130000, "gender": "male"},
	{"id": 8133010, "gender": "female"}
]
const STATES := ["idle", "walk", "run"]
const HELPERS := ["v_zero", "v_slot", "v_l_slot01", "v_l_slot02", "v_r_slot01", "v_r_slot02"]
const OUTPUT_DIR := "reports/c3-vat-runtime-switch"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	get_root().size = Vector2i(1280, 720)
	for _frame in range(3):
		await process_frame
	if not is_instance_valid(AssetCatalog) or AssetCatalog.character_vat_clips.size() != 2:
		push_error("C3 VAT runtime validation: runtime catalog has not exposed both validated character VAT models.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + OUTPUT_DIR))
	var stage := Node3D.new()
	stage.name = "C3_VAT_Runtime_Switch_Validation"
	get_root().add_child(stage)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.13, 0.15, 0.18)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.8, 0.82, 0.9)
	environment.ambient_light_energy = 0.9
	environment_node.environment = environment
	stage.add_child(environment_node)
	var key_light := DirectionalLight3D.new()
	key_light.light_energy = 1.7
	key_light.rotation_degrees = Vector3(-35.0, 25.0, 0.0)
	stage.add_child(key_light)
	var fill_light := OmniLight3D.new()
	fill_light.light_energy = 0.75
	fill_light.omni_range = 20.0
	stage.add_child(fill_light)
	var camera := Camera3D.new()
	camera.fov = 38.0
	camera.near = 0.01
	camera.far = 100.0
	stage.add_child(camera)
	camera.make_current()

	var all_passed := true
	var clip_results: Array[Dictionary] = []
	for model in MODELS:
		var model_id := int(model["id"])
		var model_path := _find_character_model_path(model_id)
		if model_path.is_empty():
			push_error("C3 VAT runtime validation: merged character body GLB is missing for model " + str(model_id))
			all_passed = false
			continue
		var packed := ResourceLoader.load(model_path) as PackedScene
		if packed == null:
			push_error("C3 VAT runtime validation: could not load " + model_path)
			all_passed = false
			continue
		var character := packed.instantiate()
		stage.add_child(character)
		await process_frame
		var mesh_nodes := character.find_children("*", "MeshInstance3D", true, false)
		var mesh_by_name: Dictionary = {}
		for node in mesh_nodes:
			var mesh_instance := node as MeshInstance3D
			if mesh_by_name.has(mesh_instance.name):
				push_error("C3 VAT runtime validation: duplicate imported mesh name " + mesh_instance.name)
				all_passed = false
			mesh_by_name[mesh_instance.name] = mesh_instance
		if mesh_nodes.size() < 8:
			push_error("C3 VAT runtime validation: expected complete body and helper meshes, found " + str(mesh_nodes.size()))
			all_passed = false
			character.queue_free()
			await process_frame
			continue
		var bounds := AABB()
		var has_bounds := false
		for node in mesh_nodes:
			var mesh_instance := node as MeshInstance3D
			if HELPERS.has(mesh_instance.name.to_lower()) or mesh_instance.mesh == null:
				continue
			var world_bounds := _transform_aabb(mesh_instance.get_aabb(), mesh_instance.global_transform)
			bounds = world_bounds if not has_bounds else bounds.merge(world_bounds)
			has_bounds = true
		if not has_bounds or bounds.size.y <= 0.01:
			push_error("C3 VAT runtime validation: character bounds are invalid for " + str(model_id))
			all_passed = false
			character.queue_free()
			await process_frame
			continue
		var center := bounds.get_center()
		var extent := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
		camera.position = center + Vector3(extent * 0.35, extent * 0.15, extent * 2.1)
		camera.look_at(center + Vector3(0.0, extent * 0.08, 0.0), Vector3.UP)
		fill_light.omni_range = maxf(5.0, extent * 5.0)
		fill_light.position = center + Vector3(-extent, extent * 0.8, extent * 0.6)

		var animator := C3VatCharacterAnimator.new()
		stage.add_child(animator)
		if not animator.configure_character(character, model_id):
			push_error("C3 VAT runtime validation: controller could not configure model " + str(model_id))
			all_passed = false
			animator.queue_free()
			character.queue_free()
			await process_frame
			continue
		for state in STATES:
			if not animator.play_state(state):
				push_error("C3 VAT runtime validation: controller could not switch model %d to %s." % [model_id, state])
				all_passed = false
				continue
			var clip: Dictionary = AssetCatalog.get_character_vat_clip(model_id, state)
			var metadata_paths: Array = clip.get("metadata_paths", [])
			if metadata_paths.is_empty():
				push_error("C3 VAT runtime validation: no metadata paths for %d/%s." % [model_id, state])
				all_passed = false
				continue
			var metadata_file := FileAccess.open(str(metadata_paths[0]), FileAccess.READ)
			if metadata_file == null:
				all_passed = false
				continue
			var metadata = JSON.parse_string(metadata_file.get_as_text())
			metadata_file.close()
			if not (metadata is Dictionary):
				all_passed = false
				continue
			var frame_count := int(metadata.get("height", 0))
			if frame_count <= 1:
				all_passed = false
				continue
			animator.pause()
			animator.set_frame(0.0)
			for _frame in range(2):
				await process_frame
			var image_a := get_root().get_texture().get_image()
			var stem: String = str(model["gender"]) + "_" + state
			var frame_a_path := OUTPUT_DIR.path_join(stem + "_frame_a.png")
			if image_a.save_png(frame_a_path) != OK:
				push_error("C3 VAT runtime validation: failed to save frame A for " + stem)
				all_passed = false
			animator.set_frame(float(maxi(1, int(frame_count / 2))))
			for _frame in range(2):
				await process_frame
			var image_b := get_root().get_texture().get_image()
			var frame_b_path := OUTPUT_DIR.path_join(stem + "_frame_b.png")
			if image_b.save_png(frame_b_path) != OK:
				push_error("C3 VAT runtime validation: failed to save frame B for " + stem)
				all_passed = false
			var bytes_a := image_a.get_data()
			var bytes_b := image_b.get_data()
			var changed_pixels := 0
			var sampled_pixels := 0
			if bytes_a.size() == bytes_b.size():
				for offset in range(0, bytes_a.size(), 16):
					sampled_pixels += 1
					for channel in range(4):
						if bytes_a[offset + channel] != bytes_b[offset + channel]:
							changed_pixels += 1
							break
			var background := image_a.get_pixel(0, 0)
			var background_rgb := Vector3(background.r, background.g, background.b)
			var foreground_min := Vector2i(image_a.get_width(), image_a.get_height())
			var foreground_max := Vector2i(-1, -1)
			var foreground_count := 0
			for y in range(image_a.get_height()):
				for x in range(image_a.get_width()):
					var color := image_a.get_pixel(x, y)
					if Vector3(color.r, color.g, color.b).distance_to(background_rgb) > 0.12:
						foreground_count += 1
						foreground_min.x = mini(foreground_min.x, x)
						foreground_min.y = mini(foreground_min.y, y)
						foreground_max.x = maxi(foreground_max.x, x)
						foreground_max.y = maxi(foreground_max.y, y)
			var foreground_size := foreground_max - foreground_min + Vector2i.ONE
			var height_ratio := float(foreground_size.y) / float(image_a.get_height())
			var valid := changed_pixels >= 100 and sampled_pixels > 0 and float(changed_pixels) / float(sampled_pixels) >= 0.0001 and foreground_count >= 500 and height_ratio >= 0.35 and foreground_min.x > 2 and foreground_min.y > 2 and foreground_max.x < image_a.get_width() - 3 and foreground_max.y < image_a.get_height() - 3
			if not valid:
				push_error("C3 VAT runtime validation: visible motion/silhouette threshold failed for %s (%d changed / %d sampled, silhouette=%s)." % [stem, changed_pixels, sampled_pixels, str(foreground_size)])
				all_passed = false
			print("C3 VAT RUNTIME STATE: ", model["gender"], " ", state, " | meshes=", mesh_nodes.size(), " | changed=", changed_pixels, "/", sampled_pixels, " | silhouette=", foreground_size)
			clip_results.append({
				"model_id": model_id,
				"gender": model["gender"],
				"state": state,
				"clip_id": str(clip.get("clip_id", "")),
				"metadata_count": metadata_paths.size(),
				"mesh_count": mesh_nodes.size(),
				"frame_count": frame_count,
				"changed_pixels": changed_pixels,
				"sampled_pixels": sampled_pixels,
				"foreground_pixels": foreground_count,
				"foreground_bounds": {"min": [foreground_min.x, foreground_min.y], "max": [foreground_max.x, foreground_max.y]},
				"frame_a": frame_a_path,
				"frame_b": frame_b_path,
				"status": "RUNTIME_VAT_STATE_PASSED" if valid else "FAILED"
			})
		animator.queue_free()
		character.queue_free()
		await process_frame

	var report := {
		"expected_states": 6,
		"validated_states": clip_results.filter(func(row): return row.get("status") == "RUNTIME_VAT_STATE_PASSED").size(),
		"base_models": MODELS,
		"states": clip_results,
		"status": "PASSED" if all_passed and clip_results.size() == 6 else "FAILED",
		"note": "Runtime state-switching test uses the merged character body GLBs and the staged position/normal VAT resources from the animations PCK."
	}
	var report_path := "res://reports/c3-vat-runtime-validation.json"
	var report_file := FileAccess.open(report_path, FileAccess.WRITE)
	if report_file == null:
		push_error("C3 VAT runtime validation: could not write report.")
		quit(1)
		return
	report_file.store_string(JSON.stringify(report, "\t") + "\n")
	report_file.close()
	if not all_passed or clip_results.size() != 6:
		push_error("C3 VAT runtime state-switching validation failed.")
		quit(1)
		return
	print("C3 VAT RUNTIME VALIDATION PASSED: ", JSON.stringify(report))
	stage.queue_free()
	quit(0)

func _find_character_model_path(model_id: int) -> String:
	var entries := AssetCatalog.get_asset_entries("characters", [".glb", ".gltf"])
	for entry in entries:
		var path := str(entry.get("path", ""))
		if path.get_file().get_basename() == str(model_id) and path.contains("/body/"):
			return "res://" + path
	return ""

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
