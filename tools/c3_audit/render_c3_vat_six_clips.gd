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
# These C3 helper/socket meshes are preserved in GLB for attachment points, not body surfaces.
const HIDDEN_C3_HELPERS := ["v_zero", "v_slot", "v_l_slot01", "v_l_slot02", "v_r_slot01", "v_r_slot02"]

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
	var clip_proofs: Array[Dictionary] = []
	var audit_data = JSON.parse_string(FileAccess.get_file_as_string("res://reports/c3-model-audit.json"))
	if not (audit_data is Dictionary):
		push_error("C3 six-clip visual proof: model audit report is missing.")
		quit(1)
		return
	var clip_reports: Dictionary = {}
	for row in audit_data.get("vat_motion_poc", []):
		clip_reports[str(row.get("clip_id", ""))] = row
	for clip in CLIPS:
		var clip_id := str(clip["id"])
		if not clip_reports.has(clip_id):
			push_error("C3 six-clip visual proof: audit report is missing " + clip_id)
			all_passed = false
			continue
		var clip_report: Dictionary = clip_reports[clip_id]
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
		var expected_mesh_count := int(clip_report.get("source_renderable_mesh_count", -1))
		if expected_mesh_count < 1 or mesh_nodes.size() != expected_mesh_count:
			push_error("C3 six-clip visual proof: imported full-character mesh count differs from source for " + clip_id + " count=" + str(mesh_nodes.size()))
			character.queue_free()
			await process_frame
			all_passed = false
			continue
		var hidden_helpers: Array[String] = []
		for helper_node in mesh_nodes:
			var helper_mesh := helper_node as MeshInstance3D
			if HIDDEN_C3_HELPERS.has(helper_mesh.name):
				# Presence is checked here; C3VatPlayer must hide them at runtime.
				hidden_helpers.append(helper_mesh.name)
		if hidden_helpers.size() != HIDDEN_C3_HELPERS.size():
			push_error("C3 six-clip visual proof: expected all six C3 helper/socket meshes in GLB for " + clip_id)
			all_passed = false

		var bounds := AABB()
		var first_bounds := true
		for mesh_node in mesh_nodes:
			var mesh_instance := mesh_node as MeshInstance3D
			if HIDDEN_C3_HELPERS.has(mesh_instance.name):
				continue
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
		var applied_mesh_names: Dictionary = {}
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
			if target_mesh.skin != null or not target_mesh.skeleton.is_empty():
				push_error("C3 six-clip visual proof: baked VAT mesh is still linked to a glTF skin/skeleton: " + mesh_name)
				all_passed = false
			vat_player.pause()
			vat_player.set_frame(0.0)
			vat_players.append({"player":vat_player,"middle_frame":float(maxi(1, int(int(metadata_value.get("height", 2)) / 2)))})
			applied_mesh_names[mesh_name] = true
			vat_mesh_count += 1
		var static_parts: Array = clip_report.get("static_meshes_retained_without_vat", [])
		var hidden_attachment_socket_count := 0
		for static_part in static_parts:
			var static_name := str(static_part.get("mesh_name", ""))
			if static_name.is_empty() or not mesh_by_name.has(static_name) or applied_mesh_names.has(static_name) or not HIDDEN_C3_HELPERS.has(static_name):
				push_error("C3 six-clip visual proof: static helper/socket part missing, animated, or unclassified: " + static_name)
				all_passed = false
				continue
			if str(static_part.get("render_role", "")) == "attachment_socket_helper":
				var helper_mesh := mesh_by_name[static_name] as MeshInstance3D
				if helper_mesh.visible:
					push_error("C3 six-clip visual proof: attachment socket marker is still visible: " + static_name)
					all_passed = false
				else:
					hidden_attachment_socket_count += 1
		if vat_mesh_count != int(clip_report.get("mesh_count", 0)):
			push_error("C3 six-clip visual proof: VAT part count differs from audit report for " + clip_id)
			all_passed = false
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
		var changed_sampled_pixels := 0
		var sampled_pixel_count := 0
		if bytes_a.size() == bytes_b.size():
			# Scan the complete one-in-four pixel sample; never stop at an arbitrary success cap.
			for pixel_offset in range(0, bytes_a.size(), 16):
				sampled_pixel_count += 1
				var pixel_changed := false
				for channel in range(4):
					if bytes_a[pixel_offset + channel] != bytes_b[pixel_offset + channel]:
						pixel_changed = true
						break
				if pixel_changed:
					changed_sampled_pixels += 1
		else:
			push_error("C3 six-clip visual proof: frame buffers have different sizes for " + clip_id)
			all_passed = false

		# Measure the rendered character against the uniform background sample.
		var background_color := image_a.get_pixel(0, 0)
		var background_vector := Vector3(background_color.r, background_color.g, background_color.b)
		var foreground_min := Vector2i(image_a.get_width(), image_a.get_height())
		var foreground_max := Vector2i(-1, -1)
		var foreground_pixel_count := 0
		for y in range(image_a.get_height()):
			for x in range(image_a.get_width()):
				var color := image_a.get_pixel(x, y)
				var color_vector := Vector3(color.r, color.g, color.b)
				if color_vector.distance_to(background_vector) > 0.12:
					foreground_pixel_count += 1
					foreground_min.x = mini(foreground_min.x, x)
					foreground_min.y = mini(foreground_min.y, y)
					foreground_max.x = maxi(foreground_max.x, x)
					foreground_max.y = maxi(foreground_max.y, y)
		var foreground_size := foreground_max - foreground_min + Vector2i.ONE
		var foreground_height_ratio := float(foreground_size.y) / float(image_a.get_height())
		var foreground_width_ratio := float(foreground_size.x) / float(image_a.get_width())
		if foreground_pixel_count < 500 or foreground_height_ratio < 0.25 or foreground_width_ratio < 0.05:
			push_error("C3 six-clip visual proof: character silhouette is absent, too small, or clipped for " + clip_id)
			all_passed = false
		if foreground_min.x <= 2 or foreground_min.y <= 2 or foreground_max.x >= image_a.get_width() - 3 or foreground_max.y >= image_a.get_height() - 3:
			push_error("C3 six-clip visual proof: character silhouette touches the render boundary for " + clip_id)
			all_passed = false
		if changed_sampled_pixels < 100 or sampled_pixel_count == 0 or float(changed_sampled_pixels) / float(sampled_pixel_count) < 0.0001:
			push_error("C3 six-clip visual proof: rendered animation difference is below threshold for " + clip_id)
			all_passed = false
		if hidden_attachment_socket_count != static_parts.size():
			push_error("C3 six-clip visual proof: not every retained static helper is confirmed hidden for " + clip_id)
			all_passed = false
		print("C3 SIX-CLIP VISUAL: ", clip["look"], " ", clip["action"], " | full_meshes=", mesh_nodes.size(), " | VAT_moving_meshes=", vat_mesh_count, " | static_hidden=", hidden_attachment_socket_count, " | changed_sampled_pixels=", changed_sampled_pixels, "/", sampled_pixel_count, " | silhouette=", foreground_size)
		clip_proofs.append({
			"clip_id": clip_id,
			"look": clip["look"],
			"action": clip["action"],
			"full_character_mesh_count": mesh_nodes.size(),
			"vat_mesh_count": vat_mesh_count,
			"static_mesh_count": static_parts.size(),
			"hidden_helper_meshes": hidden_helpers,
			"visible_character_mesh_count": mesh_nodes.size() - hidden_helpers.size(),
			"hidden_attachment_socket_count": hidden_attachment_socket_count,
			"changed_sampled_pixels": changed_sampled_pixels,
			"sampled_pixel_count": sampled_pixel_count,
			"foreground_pixel_count": foreground_pixel_count,
			"foreground_bounds": {"min": [foreground_min.x, foreground_min.y], "max": [foreground_max.x, foreground_max.y]},
			"foreground_height_ratio": foreground_height_ratio,
			"foreground_width_ratio": foreground_width_ratio,
			"frame_a": OUTPUT_DIR.path_join(file_stem + "_frame_a.png"),
			"frame_b": OUTPUT_DIR.path_join(file_stem + "_frame_b.png"),
			"status": "FULL_CHARACTER_VISUAL_MOTION_CONFIRMED"
		})
		for vat_entry in vat_players:
			vat_entry["player"].queue_free()
		character.queue_free()
		await process_frame

	if not all_passed or clip_proofs.size() != 6:
		push_error("C3 six-clip visual proof failed. Inspect reports/" + OUTPUT_DIR)
		quit(1)
		return
	var contact_before := Image.create(3840, 1440, false, Image.FORMAT_RGBA8)
	var contact_after := Image.create(3840, 1440, false, Image.FORMAT_RGBA8)
	for image_index in range(clip_proofs.size()):
		var frame_a_path := ProjectSettings.globalize_path("res://" + str(clip_proofs[image_index]["frame_a"]))
		var frame_b_path := ProjectSettings.globalize_path("res://" + str(clip_proofs[image_index]["frame_b"]))
		var frame_a_image := Image.load_from_file(frame_a_path)
		var frame_b_image := Image.load_from_file(frame_b_path)
		if frame_a_image == null or frame_b_image == null or frame_a_image.get_width() != 1280 or frame_a_image.get_height() != 720 or frame_b_image.get_width() != 1280 or frame_b_image.get_height() != 720:
			push_error("C3 six-clip visual proof: screenshot pair is missing or has invalid dimensions.")
			quit(1)
			return
		var destination := Vector2i((image_index % 3) * 1280, int(image_index / 3) * 720)
		contact_before.blit_rect(frame_a_image, Rect2i(0, 0, 1280, 720), destination)
		contact_after.blit_rect(frame_b_image, Rect2i(0, 0, 1280, 720), destination)
	if contact_before.save_png("reports/c3-vat-poc-frame-a.png") != OK or contact_after.save_png("reports/c3-vat-poc-frame-b.png") != OK:
		push_error("C3 six-clip visual proof: could not save contact sheets.")
		quit(1)
		return
	var proof_report := {
		"expected_clip_count": 6,
		"validated_clip_count": clip_proofs.size(),
		"layout": "male/female; Idle, Walk, Run; individual before/after PNGs",
		"artifact_directory": OUTPUT_DIR,
		"before_contact_sheet": "reports/c3-vat-poc-frame-a.png",
		"after_contact_sheet": "reports/c3-vat-poc-frame-b.png",
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
		push_error("C3 six-clip visual proof: could not write combined validation report.")
		quit(1)
		return
	proof_file.store_string(JSON.stringify(existing_report, "\t") + "\n")
	proof_file.close()
	print("C3 SIX-CLIP VISUAL PROOF PASSED: ", JSON.stringify(proof_report))
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
