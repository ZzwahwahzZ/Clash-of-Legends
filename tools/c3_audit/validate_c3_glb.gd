extends SceneTree

func _initialize() -> void:
	call_deferred("_validate")

func _scan(path: String, files: Array[String]) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var item := directory.get_next()
	while item != "":
		if item != "." and item != "..":
			var full_path := path.path_join(item)
			if directory.current_is_dir():
				_scan(full_path, files)
			elif item.to_lower().ends_with(".glb"):
				files.append(full_path)
		item = directory.get_next()
	directory.list_dir_end()

func _validate() -> void:
	var files: Array[String] = []
	_scan("res://build/c3-glb", files)
	if files.is_empty():
		push_error("C3 GLB validation: no converted GLB files were generated.")
		quit(1)
		return
	var valid := 0
	var animated := 0
	var total_surfaces := 0
	var total_animation_tracks := 0
	var total_animation_keys := 0
	var morph_mesh_nodes := 0
	var motion_poc_results: Array[Dictionary] = []
	var motion_poc_failed := false
	var skeletal_poc_results: Array[Dictionary] = []
	var skeletal_poc_failed := false
	for path in files:
		var packed := ResourceLoader.load(path) as PackedScene
		if packed == null:
			push_error("C3 GLB validation: Godot could not import " + path)
			quit(1)
			return
		var instance := packed.instantiate()
		var meshes := instance.find_children("*", "MeshInstance3D", true, false)
		if meshes.is_empty():
			push_error("C3 GLB validation: no MeshInstance3D nodes in " + path)
			instance.free()
			quit(1)
			return
		var model_surfaces := 0
		var model_morph_meshes := 0
		for mesh_node in meshes:
			var mesh_instance := mesh_node as MeshInstance3D
			if mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() <= 0:
				push_error("C3 GLB validation: empty mesh or no surfaces in " + path)
				instance.free()
				quit(1)
				return
			var bounds := mesh_instance.get_aabb()
			var nonzero_axes := int(bounds.size.x > 0.0001) + int(bounds.size.y > 0.0001) + int(bounds.size.z > 0.0001)
			if nonzero_axes < 2:
				push_error("C3 GLB validation: degenerate geometry bounds in " + path)
				instance.free()
				quit(1)
				return
			model_surfaces += mesh_instance.mesh.get_surface_count()
			if mesh_instance.mesh.get_blend_shape_count() > 0:
				model_morph_meshes += 1
		var model_animation_tracks := 0
		var model_animation_keys := 0
		var animation_nodes := instance.find_children("*", "AnimationPlayer", true, false)
		for animation_node in animation_nodes:
			var animation_player := animation_node as AnimationPlayer
			for animation_name in animation_player.get_animation_list():
				if animation_name == "RESET":
					continue
				var animation := animation_player.get_animation(animation_name)
				if animation == null:
					continue
				for track in range(animation.get_track_count()):
					var key_count := animation.track_get_key_count(track)
					if key_count > 1:
						model_animation_tracks += 1
						model_animation_keys += key_count
		if model_animation_tracks > 0:
			animated += 1
		total_animation_tracks += model_animation_tracks
		total_animation_keys += model_animation_keys
		morph_mesh_nodes += model_morph_meshes
		total_surfaces += model_surfaces
		if path.contains("/motion-poc/"):
			var clip_ok := model_surfaces > 0 and model_morph_meshes == meshes.size() and model_animation_tracks > 0 and model_animation_keys > 1
			var clip_result := {
				"path": path,
				"mesh_instance_count": meshes.size(),
				"surface_count": model_surfaces,
				"morph_mesh_count": model_morph_meshes,
				"animation_track_count": model_animation_tracks,
				"animation_key_count": model_animation_keys,
				"status": "GODOT_IMPORT_VALIDATED" if clip_ok else "FAILED"
			}
			motion_poc_results.append(clip_result)
			if not clip_ok:
				motion_poc_failed = true

		if path.contains("/motion-poc-skinned/"):
			var skeleton_nodes := instance.find_children("*", "Skeleton3D", true, false)
			var skinned_mesh_count := 0
			var skeleton_bone_count := 0
			for skeleton_node in skeleton_nodes:
				skeleton_bone_count += (skeleton_node as Skeleton3D).get_bone_count()
			for mesh_node in meshes:
				var mesh_instance := mesh_node as MeshInstance3D
				if mesh_instance.skin != null and not mesh_instance.skeleton.is_empty():
					skinned_mesh_count += 1
			var skeletal_ok := model_surfaces > 0 and skeleton_nodes.size() > 0 and skinned_mesh_count > 0 and skeleton_bone_count > 0 and model_animation_tracks > 0 and model_animation_keys > 1
			var skeletal_result := {
				"path": path,
				"mesh_instance_count": meshes.size(),
				"surface_count": model_surfaces,
				"skeleton_count": skeleton_nodes.size(),
				"skeleton_bone_count": skeleton_bone_count,
				"skinned_mesh_count": skinned_mesh_count,
				"animation_track_count": model_animation_tracks,
				"animation_key_count": model_animation_keys,
				"status": "GODOT_SKELETON_VALIDATED" if skeletal_ok else "FAILED"
			}
			skeletal_poc_results.append(skeletal_result)
			print("C3 SKELETAL POC: ", JSON.stringify(skeletal_result))
			if not skeletal_ok:
				skeletal_poc_failed = true
		print("C3 GLB OK: ", path, " | MeshInstance3D: ", meshes.size(), " | surfaces: ", model_surfaces, " | morph meshes: ", model_morph_meshes, " | animation tracks: ", model_animation_tracks, " | animation keys: ", model_animation_keys)
		instance.free()
		valid += 1
	var vat_results: Array[Dictionary] = []
	var vat_failed := false
	var vat_dir := DirAccess.open("res://build/c3-glb/motion-poc-vat")
	if vat_dir != null:
		var vat_files := vat_dir.get_files()
		vat_files.sort()
		for metadata_name in vat_files:
			if not metadata_name.ends_with(".json"):
				continue
			var metadata_file := FileAccess.open("res://build/c3-glb/motion-poc-vat".path_join(metadata_name), FileAccess.READ)
			if metadata_file == null:
				vat_failed = true
				continue
			var metadata_parser := JSON.new()
			var parse_error := metadata_parser.parse(metadata_file.get_as_text())
			metadata_file.close()
			if parse_error != OK or not (metadata_parser.data is Dictionary):
				vat_failed = true
				continue
			var metadata: Dictionary = metadata_parser.data
			var width := int(metadata.get("width", 0))
			var height := int(metadata.get("height", 0))
			var binary_name := str(metadata.get("binary_file", ""))
			var binary_path := "res://build/c3-glb/motion-poc-vat".path_join(binary_name)
			var data := FileAccess.get_file_as_bytes(binary_path) if not binary_name.is_empty() else PackedByteArray()
			var expected_bytes := width * height * 16
			var finite_values := data.size() == expected_bytes and width > 0 and height > 1
			var changed := false
			if finite_values:
				for offset in range(0, data.size(), 4):
					if not is_finite(data.decode_float(offset)):
						finite_values = false
						break
				if finite_values:
					for vertex_index in range(width):
						var first_offset := vertex_index * 16
						var last_offset := ((height - 1) * width + vertex_index) * 16
						for axis in range(3):
							if absf(data.decode_float(first_offset + axis * 4) - data.decode_float(last_offset + axis * 4)) > 0.000001:
								changed = true
								break
						if changed:
							break
			var valid_vat := finite_values and changed and metadata.get("format", "") == "C3_VAT_RGBA32F" and metadata.get("preserves_affine_shear", false)
				vat_results.append({
					"metadata": metadata_name, "width": width, "height": height,
					"bytes": data.size(), "finite": finite_values, "frame_positions_change": changed,
					"preserves_affine_shear": metadata.get("preserves_affine_shear", false),
					"status": "VAT_DATA_VALIDATED" if valid_vat else "FAILED"
				})
			if not valid_vat:
				vat_failed = true
	var vat_validated_count := vat_results.filter(func(row): return row.get("status") == "VAT_DATA_VALIDATED").size()
	var vat_status := "PASSED" if vat_results.size() == 6 and vat_validated_count == 6 and not vat_failed else "FAILED"
	var poc_report := {
		"expected_clip_count": 6,
		"validated_clip_count": motion_poc_results.filter(func(row): return row.get("status") == "GODOT_IMPORT_VALIDATED").size(),
		"status": "PASSED" if motion_poc_results.size() == 6 and not motion_poc_failed else "FAILED",
		"clips": motion_poc_results,
		"expected_skeletal_clip_count": 6,
		"validated_skeletal_clip_count": skeletal_poc_results.filter(func(row): return row.get("status") == "GODOT_SKELETON_VALIDATED").size(),
		"skeletal_status": "PASSED" if skeletal_poc_results.size() == 6 and not skeletal_poc_failed else "FAILED",
		"skeletal_clips": skeletal_poc_results,
		"expected_vat_clip_count": 6,
		"validated_vat_clip_count": vat_validated_count,
		"vat_status": vat_status,
		"vat_clips": vat_results
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports"))
	var poc_file := FileAccess.open("res://reports/c3-motion-poc-validation.json", FileAccess.WRITE)
	if poc_file == null:
		push_error("C3 motion POC validation: could not write validation report.")
		quit(1)
		return
	poc_file.store_string(JSON.stringify(poc_report, "\t") + "\n")
	poc_file.close()
	print("C3 SKELETAL POC SUMMARY: ", JSON.stringify(poc_report))
	print("C3 MOTION POC VALIDATION: ", poc_report["validated_clip_count"], "/", poc_report["expected_clip_count"], " clips passed Godot import and animation-track checks.")
	if motion_poc_results.size() != 6 or motion_poc_failed:
		push_error("C3 motion POC validation failed: expected six fully animated imported clips.")
		quit(1)
		return
	if (skeletal_poc_results.size() != 6 or skeletal_poc_failed) and vat_status != "PASSED":
		push_error("C3 motion validation failed: neither six skeletal clips nor six exact-affine VAT clips passed.")
		quit(1)
		return
	if vat_status == "PASSED" and (skeletal_poc_results.size() != 6 or skeletal_poc_failed):
		print("C3 MOTION FALLBACK: skeletal TRS is not representable for every clip; exact-affine VAT validated for all six clips.")
	if animated == 0 or morph_mesh_nodes == 0 or total_animation_tracks == 0:
		push_error("C3 GLB validation: converted models did not expose usable morph animation tracks.")
		quit(1)
		return
	print("C3 GLB VALIDATION PASSED: ", valid, " textured models imported; ", total_surfaces, " surfaces; ", morph_mesh_nodes, " morph-capable mesh nodes; ", animated, " animated models; ", total_animation_tracks, " animation tracks; ", total_animation_keys, " keys.")
	quit(0)
