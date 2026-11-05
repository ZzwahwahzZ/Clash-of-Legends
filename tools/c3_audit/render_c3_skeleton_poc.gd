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

	animation_player.stop()
	character.queue_free()
	await process_frame

	# The dedicated six-clip renderer runs after this representative skeletal POC.
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
