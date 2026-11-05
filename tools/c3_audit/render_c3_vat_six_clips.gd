extends SceneTree

const CLIPS := [
	{"id": "look7_model7130000_weapon500_action100", "look": "male", "action": "100 Idle"},
	{"id": "look7_model7130000_weapon500_action110", "look": "male", "action": "110 Walk"},
	{"id": "look7_model7130000_weapon500_action120", "look": "male", "action": "120 Run"},
	{"id": "look8_model8133010_weapon500_action100", "look": "female", "action": "100 Idle"},
	{"id": "look8_model8133010_weapon500_action110", "look": "female", "action": "110 Walk"},
	{"id": "look8_model8133010_weapon500_action120", "look": "female", "action": "120 Run"}
]
const VAT_DIR := "res://build/c3-glb/motion-poc-vat"
const OUTPUT_DIR := "reports/c3-vat-six-clips"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	get_root().size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + OUTPUT_DIR))
	var stage := Node3D.new()
	stage.name = "C3_VAT_Six_Clip_Visual_Proof"
	get_root().add_child(stage)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.055, 0.065, 0.09)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.76, 0.86)
	environment.ambient_light_energy = 0.9
	environment_node.environment = environment
	stage.add_child(environment_node)
	var key_light := DirectionalLight3D.new()
	key_light.light_energy = 1.5
	key_light.rotation_degrees = Vector3(-35.0, 25.0, 0.0)
	stage.add_child(key_light)
	var fill_light := OmniLight3D.new()
	fill_light.light_energy = 0.7
	fill_light.omni_range = 20.0
	stage.add_child(fill_light)
	var camera := Camera3D.new()
	camera.fov = 38.0
	camera.near = 0.01
	camera.far = 100.0
	stage.add_child(camera)
	camera.make_current()

	var all_passed := true
	for clip in CLIPS:
		var clip_id := str(clip["id"])
		var model_path := "res://build/c3-glb/motion-poc".path_join(clip_id + ".glb")
		var packed := ResourceLoader.load(model_path) as PackedScene
		if packed == null:
			push_error("C3 six-clip visual proof: missing full-character GLB " + model_path)
			all_passed = false
			continue
		var character := packed.instantiate()
		stage.add_child(character)
		await process_frame
		await process_frame
		for player_node in character.find_children("*", "AnimationPlayer", true, false):
			(player_node as AnimationPlayer).stop()
		var mesh_nodes := character.find_children("*", "MeshInstance3D", true, false)
		if mesh_nodes.size() < 10:
			push_error("C3 six-clip visual proof: incomplete character mesh set for " + clip_id + " count=" + str(mesh_nodes.size()))
			character.queue_free()
			await process_frame
			all_passed = false
			continue

		var bounds := AABB()
		var first_bounds := true
		for mesh_node in mesh_nodes:
			var mesh_instance := mesh_node as MeshInstance3D
			if mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() == 0:
				continue
			var world_bounds := _transform_aabb(mesh_instance.get_aabb(), mesh_instance.global_transform)
			if first_bounds:
				bounds = world_bounds
				first_bounds = false
			else:
				bounds = bounds.merge(world_bounds)
		if first_bounds or bounds.size.length() < 0.01:
			push_error("C3 six-clip visual proof: invalid full-character bounds for " + clip_id)
			character.queue_free()
			await process_frame
			all_passed = false
			continue
		var center := bounds.get_center()
		var extent := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
		camera.far = maxf(100.0, extent * 20.0)
		camera.position = center + Vector3(extent * 0.55, extent * 0.25, extent * 2.6)
		camera.look_at(center + Vector3(0.0, extent * 0.08, 0.0), Vector3.UP)
		fill_light.omni_range = maxf(5.0, extent * 5.0)
		fill_light.position = center + Vector3(-extent, extent * 0.8, extent * 0.6)

		var mesh_by_name: Dictionary = {}
		for mesh_node in mesh_nodes:
			var mesh_instance := mesh_node as MeshInstance3D
			if mesh_by_name.has(mesh_instance.name):
				push_error("C3 six-clip visual proof: ambiguous mesh name " + mesh_instance.name + " in " + clip_id)
				all_passed = false
			mesh_by_name[mesh_instance.name] = mesh_instance

		var metadata_files := DirAccess.get_files_at(VAT_DIR)
		metadata_files.sort()
		var vat_players: Array = []
		var vat_mesh_count := 0
		for metadata_name in metadata_files:
			if not metadata_name.ends_with(".json"):
				continue
			var metadata_path := VAT_DIR.path_join(metadata_name)
			var metadata_file := FileAccess.open(metadata_path, FileAccess.READ)
			if metadata_file == null:
				continue
			var metadata_value = JSON.parse_string(metadata_file.get_as_text())
			metadata_file.close()
			if not (metadata_value is Dictionary) or str(metadata_value.get("clip_id", "")) != clip_id:
				continue
			var mesh_name := str(metadata_value.get("mesh_name", ""))
			if not mesh_by_name.has(mesh_name):
				push_error("C3 six-clip visual proof: missing source mesh " + mesh_name + " for " + clip_id)
				all_passed = false
				continue
			var target_mesh := mesh_by_name[mesh_name] as MeshInstance3D
			var target_material := target_mesh.get_active_material(0) as StandardMaterial3D
			var albedo: Texture2D = target_material.albedo_texture if target_material != null else null
			var vat_player = load("res://scripts/animation/C3VatPlayer.gd").new()
			stage.add_child(vat_player)
			var binary_path := metadata_path.trim_suffix(".json") + ".rgba32f"
			if not vat_player.configure(target_mesh, metadata_path, binary_path, albedo):
				push_error("C3 six-clip visual proof: VAT could not be applied to " + mesh_name + " for " + clip_id)
				all_passed = false
				vat_player.queue_free()
				continue
			vat_player.pause()
			vat_player.set_frame(0.0)
			vat_players.append({"player":vat_player,"middle_frame":float(maxi(1, int(int(metadata_value.get("height", 2)) / 2)))})
			vat_mesh_count += 1
		if vat_mesh_count == 0:
			push_error("C3 six-clip visual proof: no moving VAT meshes for " + clip_id)
			character.queue_free()
			await process_frame
			all_passed = false
			continue
		await process_frame
		await process_frame
		var image_a := get_root().get_texture().get_image()
		var file_stem := str(clip["look"]) + "_action" + clip_id.get_slice("_action", 1)
		if image_a.save_png(OUTPUT_DIR.path_join(file_stem + "_frame_a.png")) != OK:
			push_error("C3 six-clip visual proof: failed to save frame A for " + clip_id)
			all_passed = false
		for vat_entry in vat_players:
			vat_entry["player"].set_frame(float(vat_entry["middle_frame"]))
		await process_frame
		await process_frame
		var image_b := get_root().get_texture().get_image()
		if image_b.save_png(OUTPUT_DIR.path_join(file_stem + "_frame_b.png")) != OK:
			push_error("C3 six-clip visual proof: failed to save frame B for " + clip_id)
			all_passed = false
		var bytes_a := image_a.get_data()
		var bytes_b := image_b.get_data()
		var changed_bytes := 0
		if bytes_a.size() == bytes_b.size():
			for index in range(bytes_a.size()):
				if bytes_a[index] != bytes_b[index]:
					changed_bytes += 1
		if changed_bytes < 100:
			push_error("C3 six-clip visual proof: no meaningful rendered change for " + clip_id)
			all_passed = false
		print("C3 SIX-CLIP VISUAL: ", clip["look"], " ", clip["action"], " | full_meshes=", mesh_nodes.size(), " | VAT_moving_meshes=", vat_mesh_count, " | changed_pixel_bytes=", changed_bytes)
		for vat_player in vat_players:
			vat_player.queue_free()
		character.queue_free()
		await process_frame

	if not all_passed:
		push_error("C3 six-clip visual proof failed. Inspect reports/" + OUTPUT_DIR)
		quit(1)
		return
	print("C3 SIX-CLIP VISUAL PROOF PASSED: male/female Idle, Walk, Run; 12 before/after screenshots saved.")
	stage.queue_free()
	quit(0)

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
