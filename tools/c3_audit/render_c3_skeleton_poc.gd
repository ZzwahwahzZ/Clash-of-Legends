extends SceneTree

const MODEL_PATH := "res://build/c3-glb/motion-poc-skinned/look7_model7130000_weapon500_action100.glb"
const REPORT_PATH := "res://reports/c3-skeletal-poc-validation.json"
const FRAME_A_PATH := "res://reports/c3-skeletal-poc-frame-a.png"
const FRAME_B_PATH := "res://reports/c3-skeletal-poc-frame-b.png"

func _initialize() -> void:
	call_deferred("_render")

func _fail(reason: String, details: Dictionary = {}) -> void:
	var report := {
		"schema_version": 1,
		"status": "FAILED",
		"model": MODEL_PATH,
		"reason": reason,
		"details": details
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports"))
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
		file.close()
	push_error("C3 skeletal proof FAILED: " + reason)
	quit(1)

func _render() -> void:
	get_root().size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports"))

	var packed := ResourceLoader.load(MODEL_PATH) as PackedScene
	if packed == null:
		_fail("SKINNED_GLB_LOAD_FAILED")
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
		_fail("NO_IMPORTED_MESHES")
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
		_fail("EMPTY_OR_DEGENERATE_CHARACTER_BOUNDS", {"mesh_nodes": mesh_nodes.size()})
		return

	var skeleton_nodes := character.find_children("*", "Skeleton3D", true, false)
	var bone_count := _count_bones(character)
	if skeleton_nodes.is_empty() or bone_count <= 0:
		_fail("SKELETON_OR_BONES_MISSING", {"skeleton_nodes": skeleton_nodes.size(), "bone_count": bone_count})
		return

	var center := bounds.get_center()
	var extent := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	var camera := Camera3D.new()
	camera.name = "Proof_Camera"
	camera.fov = 38.0
	camera.near = 0.01
	camera.far = maxf(100.0, extent * 20.0)
	stage.add_child(camera)
	camera.position = center + Vector3(extent * 0.55, extent * 0.25, extent * 2.6)
	camera.look_at(center + Vector3(0.0, extent * 0.08, 0.0), Vector3.UP)
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
		_fail("ANIMATION_PLAYER_MISSING", {"bone_count": bone_count})
		return
	var animation_player := players[0] as AnimationPlayer
	var animation_name := ""
	for candidate in animation_player.get_animation_list():
		if candidate != "RESET":
			animation_name = candidate
			break
	if animation_name.is_empty():
		_fail("NO_NON_RESET_ANIMATION_IMPORTED", {"bone_count": bone_count})
		return

	var animation := animation_player.get_animation(animation_name)
	if animation == null or animation.get_track_count() <= 0:
		_fail("ANIMATION_HAS_NO_TRACKS", {"animation": animation_name})
		return

	var skeleton_track_count := 0
	for track_index in range(animation.get_track_count()):
		var track_path := str(animation.track_get_path(track_index)).to_lower()
		if "skeleton" in track_path or "bone" in track_path:
			skeleton_track_count += 1
	if skeleton_track_count <= 0:
		_fail("NO_SKELETAL_ANIMATION_TRACKS", {
			"animation": animation_name,
			"track_count": animation.get_track_count(),
			"track_paths": _track_paths(animation)
		})
		return

	animation_player.play(animation_name)
	await process_frame
	await create_timer(0.35).timeout
	await process_frame
	if not animation_player.is_playing():
		_fail("ANIMATION_DID_NOT_START", {"animation": animation_name})
		return
	var first_image := get_root().get_texture().get_image()
	if first_image == null or first_image.is_empty():
		_fail("FIRST_FRAME_CAPTURE_FAILED")
		return
	var first_error := first_image.save_png(FRAME_A_PATH)
	if first_error != OK:
		_fail("FIRST_FRAME_SAVE_FAILED", {"error_code": first_error})
		return

	await create_timer(0.45).timeout
	await process_frame
	var second_image := get_root().get_texture().get_image()
	if second_image == null or second_image.is_empty():
		_fail("SECOND_FRAME_CAPTURE_FAILED")
		return
	var second_error := second_image.save_png(FRAME_B_PATH)
	if second_error != OK:
		_fail("SECOND_FRAME_SAVE_FAILED", {"error_code": second_error})
		return

	var changed_pixels := _count_changed_pixels(first_image, second_image)
	var total_pixels := first_image.get_width() * first_image.get_height()
	var changed_ratio := float(changed_pixels) / float(maxi(1, total_pixels))
	if changed_pixels <= 0 or changed_ratio < 0.0005:
		_fail("ANIMATION_VISUAL_CHANGE_NOT_PROVEN", {
			"changed_pixels": changed_pixels,
			"changed_ratio": changed_ratio,
			"animation": animation_name,
			"bone_count": bone_count
		})
		return

	var report := {
		"schema_version": 1,
		"status": "PASSED",
		"model": MODEL_PATH,
		"mesh_nodes": mesh_nodes.size(),
		"skeleton_nodes": skeleton_nodes.size(),
		"bone_count": bone_count,
		"animation": animation_name,
		"animation_track_count": animation.get_track_count(),
		"skeleton_track_count": skeleton_track_count,
		"changed_pixels": changed_pixels,
		"changed_pixel_ratio": changed_ratio,
		"screenshots": [FRAME_A_PATH, FRAME_B_PATH]
	}
	var report_file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if report_file == null:
		_fail("REPORT_WRITE_FAILED")
		return
	report_file.store_string(JSON.stringify(report, "\t") + "\n")
	report_file.close()

	print("C3 SKELETAL VISUAL PROOF PASSED: ", JSON.stringify(report))
	animation_player.stop()
	character.queue_free()
	await process_frame
	stage.queue_free()
	quit(0)

func _count_bones(root: Node) -> int:
	var total := 0
	for node in root.find_children("*", "Skeleton3D", true, false):
		total += (node as Skeleton3D).get_bone_count()
	return total

func _track_paths(animation: Animation) -> Array[String]:
	var paths: Array[String] = []
	for index in range(animation.get_track_count()):
		paths.append(str(animation.track_get_path(index)))
	return paths

func _count_changed_pixels(first: Image, second: Image) -> int:
	if first.get_width() != second.get_width() or first.get_height() != second.get_height():
		return first.get_width() * first.get_height()
	var a := first.get_data()
	var b := second.get_data()
	var changed := 0
	for offset in range(0, mini(a.size(), b.size()), 4):
		var difference := absi(int(a[offset]) - int(b[offset]))
		difference += absi(int(a[offset + 1]) - int(b[offset + 1]))
		difference += absi(int(a[offset + 2]) - int(b[offset + 2]))
		if difference > 24:
			changed += 1
	return changed

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
