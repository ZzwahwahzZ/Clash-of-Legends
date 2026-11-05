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

	# Render all six real male/female Idle, Walk and Run clips on complete textured characters.
	# VAT is attached only to deforming meshes; static parts remain visible from the full GLB.
	var expected_clips := [
		"look7_model7130000_weapon500_action100", "look7_model7130000_weapon500_action110", "look7_model7130000_weapon500_action120",
		"look8_model8133010_weapon500_action100", "look8_model8133010_weapon500_action110", "look8_model8133010_weapon500_action120"
	]
	var audit_data = JSON.parse_string(FileAccess.get_file_as_string("res://reports/c3-model-audit.json"))
	if not (audit_data is Dictionary):
		push_error("C3 VAT visual proof: C3 model audit report is missing or invalid.")
		quit(1)
		return
	var clip_reports: Dictionary = {}
	for row in audit_data.get("vat_motion_poc", []):
		clip_reports[str(row.get("clip_id", ""))] = row
	var vat_directory := DirAccess.open("res://build/c3-glb/motion-poc-vat")
	if vat_directory == null:
		push_error("C3 VAT visual proof: VAT metadata directory is missing.")
		quit(1)
		return
	var vat_metadata_files := vat_directory.get_files()
	vat_metadata_files.sort()
	var before_images: Array[Image] = []
	var after_images: Array[Image] = []
	var clip_proofs: Array[Dictionary] = []
	var processed_metadata_count := 0
	for clip_id in expected_clips:
		if not clip_reports.has(clip_id):
			push_error("C3 VAT visual proof: audit report does not contain " + clip_id)
			quit(1)
			return
		var clip_report: Dictionary = clip_reports[clip_id]
		var model_path := "res://build/c3-glb/motion-poc".path_join(clip_id + ".glb")
		var full_character_scene := ResourceLoader.load(model_path) as PackedScene
		if full_character_scene == null:
			push_error("C3 VAT visual proof: full character GLB failed to load: " + model_path)
			quit(1)
			return
		var full_character := full_character_scene.instantiate()
		stage.add_child(full_character)
		await process_frame
		await process_frame
		var all_mesh_nodes := full_character.find_children("*", "MeshInstance3D", true, false)
		var expected_mesh_count := int(clip_report.get("source_renderable_mesh_count", -1))
		if expected_mesh_count < 1 or all_mesh_nodes.size() != expected_mesh_count:
			push_error("C3 VAT visual proof: full character mesh count differs from source report for " + clip_id)
			quit(1)
			return
		var mesh_by_name: Dictionary = {}
		var bounds_full := AABB()
		var first_full_bounds := true
		for mesh_candidate in all_mesh_nodes:
			var mesh_instance := mesh_candidate as MeshInstance3D
			if mesh_by_name.has(mesh_instance.name):
				push_error("C3 VAT visual proof: duplicate imported mesh node name: " + mesh_instance.name)
				quit(1)
				return
			mesh_by_name[mesh_instance.name] = mesh_instance
			if mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() <= 0:
				push_error("C3 VAT visual proof: empty imported body part: " + mesh_instance.name)
				quit(1)
				return
			var part_bounds := _transform_aabb(mesh_instance.get_aabb(), mesh_instance.global_transform)
			if first_full_bounds:
				bounds_full = part_bounds
				first_full_bounds = false
			else:
				bounds_full = bounds_full.merge(part_bounds)
		if first_full_bounds or bounds_full.size.length() < 0.01:
			push_error("C3 VAT visual proof: complete character bounds are invalid: " + clip_id)
			quit(1)
			return
		var full_center := bounds_full.get_center()
		var full_extent := maxf(bounds_full.size.x, maxf(bounds_full.size.y, bounds_full.size.z))
		camera.position = full_center + Vector3(full_extent * 0.55, full_extent * 0.25, full_extent * 2.6)
		camera.far = maxf(100.0, full_extent * 20.0)
		camera.look_at(full_center + Vector3(0.0, full_extent * 0.08, 0.0), Vector3.UP)
		key_light.position = full_center + Vector3(full_extent, full_extent * 1.5, full_extent)
		fill_light.position = full_center + Vector3(-full_extent, full_extent * 0.8, full_extent * 0.6)
		var applied_mesh_names: Dictionary = {}
		var vat_players_for_clip: Array[Dictionary] = []
		for metadata_name in vat_metadata_files:
			if not metadata_name.ends_with(".json"):
				continue
			var metadata_path := "res://build/c3-glb/motion-poc-vat".path_join(metadata_name)
			var metadata_file := FileAccess.open(metadata_path, FileAccess.READ)
			if metadata_file == null:
				continue
			var metadata_value = JSON.parse_string(metadata_file.get_as_text())
			metadata_file.close()
			if not (metadata_value is Dictionary) or str(metadata_value.get("clip_id", "")) != clip_id:
				continue
			processed_metadata_count += 1
			var target_name := str(metadata_value.get("mesh_name", ""))
			if target_name.is_empty() or not mesh_by_name.has(target_name) or applied_mesh_names.has(target_name):
				push_error("C3 VAT visual proof: exact VAT-to-GLB mesh mapping failed for " + target_name)
				quit(1)
				return
			var target_mesh := mesh_by_name[target_name] as MeshInstance3D
			var target_material := target_mesh.get_active_material(0) as StandardMaterial3D
			var target_albedo: Texture2D = target_material.albedo_texture if target_material != null else null
			var player_script = load("res://scripts/animation/C3VatPlayer.gd")
			if player_script == null:
				push_error("C3 VAT visual proof: VAT player script failed to load.")
				quit(1)
				return
			var vat_player = player_script.new()
			stage.add_child(vat_player)
			var binary_path := metadata_path.trim_suffix(".json") + ".rgba32f"
			if not vat_player.configure(target_mesh, metadata_path, binary_path, target_albedo):
				push_error("C3 VAT visual proof: per-mesh VAT setup failed for " + target_name)
				quit(1)
				return
			vat_player.pause()
			vat_player.set_frame(0.0)
			vat_players_for_clip.append({"player":vat_player,"middle_frame":int((int(metadata_value.get("height", 1)) - 1) / 2)})
			applied_mesh_names[target_name] = true
		if vat_players_for_clip.size() != int(clip_report.get("mesh_count", 0)):
			push_error("C3 VAT visual proof: exported VAT mesh count mismatch for " + clip_id)
			quit(1)
			return
		for static_part in clip_report.get("static_meshes_retained_without_vat", []):
			var static_name := str(static_part.get("mesh_name", ""))
			if static_name.is_empty() or not mesh_by_name.has(static_name) or applied_mesh_names.has(static_name):
				push_error("C3 VAT visual proof: static part missing or incorrectly given VAT: " + static_name)
				quit(1)
				return
		if vat_players_for_clip.is_empty():
			push_error("C3 VAT visual proof: clip has no deforming VAT mesh: " + clip_id)
			quit(1)
			return
		await process_frame
		await process_frame
		var before_image := get_root().get_texture().get_image()
		for vat_entry in vat_players_for_clip:
			var player = vat_entry["player"]
			player.set_frame(float(vat_entry["middle_frame"]))
		await process_frame
		await process_frame
		var after_image := get_root().get_texture().get_image()
		var changed_bytes := 0
		var before_data := before_image.get_data()
		var after_data := after_image.get_data()
		if before_data.size() == after_data.size():
			for byte_index in range(before_data.size()):
				if before_data[byte_index] != after_data[byte_index]:
					changed_bytes += 1
		if changed_bytes < 100:
			push_error("C3 VAT visual proof: before/after frames show no meaningful movement for " + clip_id)
			quit(1)
			return
		before_images.append(before_image.duplicate())
		after_images.append(after_image.duplicate())
		clip_proofs.append({
			"clip_id": clip_id,
			"full_character_mesh_count": all_mesh_nodes.size(),
			"vat_mesh_count": vat_players_for_clip.size(),
			"static_mesh_count": clip_report.get("static_meshes_retained_without_vat", []).size(),
			"changed_pixel_bytes": changed_bytes,
			"status": "FULL_CHARACTER_VISUAL_MOTION_CONFIRMED"
		})
		print("C3 VAT FULL CHARACTER VISUAL PROOF: ", JSON.stringify(clip_proofs[clip_proofs.size() - 1]))
		for vat_entry in vat_players_for_clip:
			vat_entry["player"].queue_free()
		full_character.queue_free()
		await process_frame
	if before_images.size() != 6 or after_images.size() != 6 or processed_metadata_count < 6:
		push_error("C3 VAT visual proof: expected six complete before/after clip pairs.")
		quit(1)
		return
	var contact_before := Image.create(3840, 1440, false, Image.FORMAT_RGBA8)
	var contact_after := Image.create(3840, 1440, false, Image.FORMAT_RGBA8)
	for image_index in range(6):
		var destination := Vector2i((image_index % 3) * 1280, int(image_index / 3) * 720)
		contact_before.blit_rect(before_images[image_index], Rect2i(0, 0, 1280, 720), destination)
		contact_after.blit_rect(after_images[image_index], Rect2i(0, 0, 1280, 720), destination)
	if contact_before.save_png("reports/c3-vat-poc-frame-a.png") != OK or contact_after.save_png("reports/c3-vat-poc-frame-b.png") != OK:
		push_error("C3 VAT visual proof: failed to save the six-clip contact sheets.")
		quit(1)
		return
	var proof_report := {
		"expected_clip_count": 6,
		"validated_clip_count": clip_proofs.size(),
		"layout": "3 columns x 2 rows; male Idle/Walk/Run then female Idle/Walk/Run",
		"before_image": "reports/c3-vat-poc-frame-a.png",
		"after_image": "reports/c3-vat-poc-frame-b.png",
		"clips": clip_proofs,
		"status": "PASSED"
	}
	var poc_path := "res://reports/c3-motion-poc-validation.json"
	var existing_report = JSON.parse_string(FileAccess.get_file_as_string(poc_path)) if FileAccess.file_exists(poc_path) else {}
	if not (existing_report is Dictionary):
		existing_report = {}
	existing_report["vat_visual_proof"] = proof_report
	var proof_file := FileAccess.open(poc_path, FileAccess.WRITE)
	if proof_file == null:
		push_error("C3 VAT visual proof: could not update the combined validation report.")
		quit(1)
		return
	proof_file.store_string(JSON.stringify(existing_report, "\t") + "\n")
	proof_file.close()
	print("C3 VAT SIX-CLIP VISUAL PROOF: ", JSON.stringify(proof_report))
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
