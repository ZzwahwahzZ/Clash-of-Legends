extends SceneTree

const MODEL_PATH := "res://build/c3-glb/motion-poc-skinned/look7_model7130000_weapon500_action100.glb"

func _initialize() -> void:
	call_deferred("_render")

func _render() -> void:
	get_root().size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports"))

	var packed := ResourceLoader.load(MODEL_PATH) as PackedScene
	if packed == null:
		push_error("C3 visual proof: skinned GLB could not be loaded: " + MODEL_PATH)
		quit(1)
		return

	var stage := Node3D.new()
	stage.name = "C3_Skeletal_Visual_Proof"
	get_root().add_child(stage)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.055, 0.065, 0.09)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.76, 0.86)
	environment.ambient_light_energy = 0.85
	environment_node.environment = environment
	stage.add_child(environment_node)

	var character := packed.instantiate()
	character.name = "Source_C3_Character"
	stage.add_child(character)
	await process_frame
	await process_frame

	var mesh_nodes := character.find_children("*", "MeshInstance3D", true, false)
	if mesh_nodes.is_empty():
		push_error("C3 visual proof: imported character contains no MeshInstance3D.")
		quit(1)
		return

	var bounds := AABB()
	var first_bounds := true
	for node in mesh_nodes:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		var world_bounds: AABB = _transform_aabb(mesh_node.get_aabb(), mesh_node.global_transform)
		if first_bounds:
			bounds = world_bounds
			first_bounds = false
		else:
			bounds = bounds.merge(world_bounds)
	if first_bounds or bounds.size.length() < 0.01:
		push_error("C3 visual proof: character bounds are empty or degenerate.")
		quit(1)
		return

	var center := bounds.get_center()
	# The skeletal exporter bakes the C3 centimetre/Z-up basis into vertex data,
	# so imported bounds are already in metres and Godot's Y-up convention.
	var extent := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	var camera := Camera3D.new()
	camera.name = "Proof_Camera"
	camera.fov = 38.0
	camera.near = 0.01
	camera.far = maxf(100.0, extent * 20.0)
	camera.position = center + Vector3(extent * 0.55, extent * 0.25, extent * 2.6)
	camera.look_at(center + Vector3(0.0, extent * 0.08, 0.0), Vector3.UP)
	stage.add_child(camera)
	camera.make_current()

	var key_light := DirectionalLight3D.new()
	key_light.name = "Key_Light"
	key_light.light_energy = 1.5
	key_light.rotation_degrees = Vector3(-35.0, 25.0, 0.0)
	stage.add_child(key_light)

	var fill_light := OmniLight3D.new()
	fill_light.name = "Fill_Light"
	fill_light.light_energy = 0.65
	fill_light.omni_range = maxf(5.0, extent * 5.0)
	fill_light.position = center + Vector3(-extent, extent * 0.8, extent * 0.6)
	stage.add_child(fill_light)

	var players := character.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_error("C3 visual proof: no AnimationPlayer was imported.")
		quit(1)
		return
	var animation_player := players[0] as AnimationPlayer
	var animation_name := ""
	for candidate in animation_player.get_animation_list():
		if candidate != "RESET":
			animation_name = candidate
			break
	if animation_name.is_empty():
		push_error("C3 visual proof: no playable skeletal animation was imported.")
		quit(1)
		return

	animation_player.play(animation_name)
	await process_frame
	await create_timer(0.35).timeout
	await process_frame
	var first_image := get_root().get_texture().get_image()
	var first_error := first_image.save_png("reports/c3-skeletal-poc-frame-a.png")
	if first_error != OK:
		push_error("C3 visual proof: could not save first frame.")
		quit(1)
		return

	await create_timer(0.45).timeout
	await process_frame
	var second_image := get_root().get_texture().get_image()
	var second_error := second_image.save_png("reports/c3-skeletal-poc-frame-b.png")
	if second_error != OK:
		push_error("C3 visual proof: could not save second frame.")
		quit(1)
		return

	print("C3 VISUAL PROOF: model=", MODEL_PATH,
		" meshes=", mesh_nodes.size(),
		" animation=", animation_name,
		" bones=", _count_bones(character),
		" screenshots=reports/c3-skeletal-poc-frame-a.png,reports/c3-skeletal-poc-frame-b.png")

	# VAT is tested against the full imported character scene, not the v_body-only skeletal POC.
	animation_player.stop()
	character.queue_free()
	await process_frame
	const FULL_VAT_MODEL := "res://build/c3-glb/motion-poc/look7_model7130000_weapon500_action110.glb"
	var vat_packed := ResourceLoader.load(FULL_VAT_MODEL) as PackedScene
	if vat_packed == null:
		push_error("C3 VAT visual proof: full multi-mesh character GLB failed to load: " + FULL_VAT_MODEL)
		quit(1)
		return
	var vat_character := vat_packed.instantiate()
	stage.add_child(vat_character)
	await process_frame
	await process_frame
	var vat_mesh_nodes := vat_character.find_children("*", "MeshInstance3D", true, false)
	var vat_mesh_by_name: Dictionary = {}
	for candidate in vat_mesh_nodes:
		var candidate_mesh := candidate as MeshInstance3D
		if vat_mesh_by_name.has(candidate_mesh.name):
			push_error("C3 VAT visual proof: duplicate imported mesh node name prevents exact mapping: " + candidate_mesh.name)
			quit(1)
			return
		vat_mesh_by_name[candidate_mesh.name] = candidate_mesh
	var vat_clip_id := "look7_model7130000_weapon500_action110"
	var vat_directory := DirAccess.open("res://build/c3-glb/motion-poc-vat")
	if vat_directory == null:
		push_error("C3 VAT visual proof: VAT metadata directory is missing.")
		quit(1)
		return
	var vat_metadata_files := vat_directory.get_files()
	vat_metadata_files.sort()
	var vat_applied_meshes := 0
	var vat_expected_meshes := 0
	var vat_players: Array = []
	for metadata_name in vat_metadata_files:
		if not metadata_name.ends_with(".json"):
			continue
		var metadata_path := "res://build/c3-glb/motion-poc-vat".path_join(metadata_name)
		var metadata_file := FileAccess.open(metadata_path, FileAccess.READ)
		if metadata_file == null:
			continue
		var metadata_value = JSON.parse_string(metadata_file.get_as_text())
		metadata_file.close()
		if not (metadata_value is Dictionary) or str(metadata_value.get("clip_id", "")) != vat_clip_id:
			continue
		vat_expected_meshes += 1
		var target_name := str(metadata_value.get("mesh_name", ""))
		if not vat_mesh_by_name.has(target_name):
			push_error("C3 VAT visual proof: imported full character is missing VAT mesh " + target_name)
			quit(1)
			return
		var target_mesh := vat_mesh_by_name[target_name] as MeshInstance3D
		var target_material := target_mesh.get_active_material(0) as StandardMaterial3D
		var target_albedo: Texture2D = target_material.albedo_texture if target_material != null else null
		var player_script = load("res://scripts/animation/C3VatPlayer.gd")
		var vat_player = player_script.new()
		stage.add_child(vat_player)
		var binary_path := metadata_path.trim_suffix(".json") + ".rgba32f"
		if not vat_player.configure(target_mesh, metadata_path, binary_path, target_albedo):
			push_error("C3 VAT visual proof: per-mesh VAT setup failed for " + target_name)
			quit(1)
			return
		vat_player.pause()
		vat_player.set_frame(0.0)
		vat_players.append(vat_player)
		vat_applied_meshes += 1
	if vat_expected_meshes == 0 or vat_applied_meshes != vat_expected_meshes:
		push_error("C3 VAT visual proof: incomplete multi-mesh mapping.")
		quit(1)
		return
	await process_frame
	await process_frame
	var vat_first := get_root().get_texture().get_image()
	if vat_first.save_png("reports/c3-vat-poc-frame-a.png") != OK:
		push_error("C3 VAT visual proof: could not save first VAT frame.")
		quit(1)
		return
	for vat_player in vat_players:
		vat_player.set_frame(14.0)
	await process_frame
	await process_frame
	var vat_second := get_root().get_texture().get_image()
	if vat_second.save_png("reports/c3-vat-poc-frame-b.png") != OK:
		push_error("C3 VAT visual proof: could not save second VAT frame.")
		quit(1)
		return
	var first_pixels := vat_first.get_data()
	var second_pixels := vat_second.get_data()
	var changed_pixels := 0
	if first_pixels.size() == second_pixels.size():
		for pixel_byte in range(first_pixels.size()):
			if first_pixels[pixel_byte] != second_pixels[pixel_byte]:
				changed_pixels += 1
	if changed_pixels < 100:
		push_error("C3 VAT visual proof: rendered full-character frames did not show meaningful movement.")
		quit(1)
		return
	print("C3 VAT FULL CHARACTER VISUAL PROOF: clip=", vat_clip_id,
		" imported_meshes=", vat_mesh_nodes.size(), " VAT_meshes=", vat_applied_meshes,
		" changed_pixel_bytes=", changed_pixels,
		" screenshots=reports/c3-vat-poc-frame-a.png,reports/c3-vat-poc-frame-b.png")
	vat_character.queue_free()
	stage.queue_free()
	quit(0)
	return

func _count_bones(root: Node) -> int:
	var total := 0
	for node in root.find_children("*", "Skeleton3D", true, false):
		total += (node as Skeleton3D).get_bone_count()
	return total

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
