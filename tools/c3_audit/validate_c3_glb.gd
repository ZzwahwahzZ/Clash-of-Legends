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
	var vat_clip_meshes: Dictionary = {}
	var vat_scene_cache: Dictionary = {}
	var vat_mesh_cache: Dictionary = {}
	var expected_vat_clips := [
		"look7_model7130000_weapon500_action100", "look7_model7130000_weapon500_action110", "look7_model7130000_weapon500_action120",
		"look8_model8133010_weapon500_action100", "look8_model8133010_weapon500_action110", "look8_model8133010_weapon500_action120"
	]
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
				# Compare every frame against frame zero; a loop can end at its initial pose.
				for frame_index in range(1, height):
					for vertex_index in range(width):
						var first_offset := vertex_index * 16
						var frame_offset := (frame_index * width + vertex_index) * 16
						for axis in range(3):
							if absf(data.decode_float(first_offset + axis * 4) - data.decode_float(frame_offset + axis * 4)) > 0.00001:
								changed = true
								break
						if changed:
							break
					if changed:
						break
			var clip_id := str(metadata.get("clip_id", ""))
			var mesh_index := int(metadata.get("mesh_index", -1))
			var mesh_name := str(metadata.get("mesh_name", ""))
			var vertex_order_matches := false
			if not clip_id.is_empty() and not mesh_name.is_empty():
				if not vat_scene_cache.has(clip_id):
					var glb_path := "res://build/c3-glb/motion-poc".path_join(clip_id + ".glb")
					var clip_packed := ResourceLoader.load(glb_path) as PackedScene
					if clip_packed != null:
						var clip_instance := clip_packed.instantiate()
						vat_scene_cache[clip_id] = clip_instance
						var named_meshes: Dictionary = {}
						for candidate in clip_instance.find_children("*", "MeshInstance3D", true, false):
							var candidate_mesh := candidate as MeshInstance3D
							if named_meshes.has(candidate_mesh.name):
								named_meshes.clear()
								break
							named_meshes[candidate_mesh.name] = candidate_mesh
						vat_mesh_cache[clip_id] = named_meshes
				if vat_mesh_cache.has(clip_id):
					var named_clip_meshes: Dictionary = vat_mesh_cache[clip_id]
					if named_clip_meshes.has(mesh_name):
						var imported_mesh := named_clip_meshes[mesh_name] as MeshInstance3D
						vertex_order_matches = imported_mesh.mesh != null and imported_mesh.mesh.get_surface_count() > 0
						var seen_source_indices: Dictionary = {}
						for surface in range(imported_mesh.mesh.get_surface_count()):
							var arrays: Array = imported_mesh.mesh.surface_get_arrays(surface)
							if arrays.size() <= Mesh.ARRAY_TEX_UV2 or not (arrays[Mesh.ARRAY_TEX_UV2] is PackedVector2Array):
								vertex_order_matches = false
								break
							var imported_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
							var source_ids: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
							if imported_vertices.size() != source_ids.size():
								vertex_order_matches = false
								break
							for imported_index in range(imported_vertices.size()):
								var source_uv := source_ids[imported_index]
								var source_index := int(floor(source_uv.x * float(width)))
								if source_index < 0 or source_index >= width or absf(source_uv.x - (float(source_index) + 0.5) / float(width)) > 0.00001 or absf(source_uv.y - 0.5) > 0.00001:
									vertex_order_matches = false
									break
								var offset := source_index * 16
								var vat_position := Vector3(data.decode_float(offset), data.decode_float(offset + 4), data.decode_float(offset + 8))
								if imported_vertices[imported_index].distance_to(vat_position) > 0.0001:
									vertex_order_matches = false
									break
								seen_source_indices[source_index] = true
							if not vertex_order_matches:
								break
						var expected_referenced_count := int(metadata.get("referenced_vertex_count", -1))
						vertex_order_matches = vertex_order_matches and expected_referenced_count > 0 and seen_source_indices.size() == expected_referenced_count
			var weighted_affine := str(metadata.get("influence_semantics", "")).contains("all positive C3 bone_weights")
			var valid_vat: bool = finite_values and changed and vertex_order_matches and str(metadata.get("format", "")) == "C3_VAT_RGBA32F" and str(metadata.get("classification", "")) == "deforming" and weighted_affine and bool(metadata.get("preserves_affine_shear", false)) and str(metadata.get("vertex_order", "")).begins_with("source C3 vertex index") and not clip_id.is_empty() and mesh_index >= 0 and not mesh_name.is_empty()
			if valid_vat:
				if not vat_clip_meshes.has(clip_id):
					vat_clip_meshes[clip_id] = {}
				var clip_meshes: Dictionary = vat_clip_meshes[clip_id]
				if clip_meshes.has(str(mesh_index)):
					valid_vat = false
				else:
					clip_meshes[str(mesh_index)] = mesh_name
					vat_clip_meshes[clip_id] = clip_meshes
			vat_results.append({
				"metadata": metadata_name, "clip_id": clip_id, "mesh_index": mesh_index, "mesh_name": mesh_name,
				"width": width, "height": height, "bytes": data.size(), "finite": finite_values,
				"frame_positions_change": changed, "source_vertex_order_matches_glb": vertex_order_matches,
				"weighted_affine_influences": weighted_affine,
				"preserves_affine_shear": metadata.get("preserves_affine_shear", false),
				"status": "VAT_DATA_VALIDATED" if valid_vat else "FAILED"
			})
			if not valid_vat:
				vat_failed = true
	var vat_validated_count := vat_results.filter(func(row): return row.get("status") == "VAT_DATA_VALIDATED").size()
	var clips_with_moving_mesh := 0
	var missing_vat_clips: Array[String] = []
	for expected_clip in expected_vat_clips:
		if vat_clip_meshes.has(expected_clip) and not (vat_clip_meshes[expected_clip] as Dictionary).is_empty():
			clips_with_moving_mesh += 1
		else:
			missing_vat_clips.append(expected_clip)
	var unexpected_vat_clips: Array[String] = []
	for clip_key in vat_clip_meshes.keys():
		if not expected_vat_clips.has(str(clip_key)):
			unexpected_vat_clips.append(str(clip_key))
	var vat_static_parts_retained := true
	var audit_path := "res://reports/c3-model-audit.json"
	var audit_data = JSON.parse_string(FileAccess.get_file_as_string(audit_path)) if FileAccess.file_exists(audit_path) else null
	if not (audit_data is Dictionary):
		vat_static_parts_retained = false
	else:
		for clip_report in audit_data.get("vat_motion_poc", []):
			var static_clip_id := str(clip_report.get("clip_id", ""))
			if not expected_vat_clips.has(static_clip_id):
				continue
			if not vat_mesh_cache.has(static_clip_id):
				vat_static_parts_retained = false
				continue
			var imported_scene_meshes: Dictionary = vat_mesh_cache[static_clip_id]
			var exported_meshes: Dictionary = vat_clip_meshes.get(static_clip_id, {})
			var static_parts: Array = clip_report.get("static_meshes_retained_without_vat", [])
			var expected_mesh_count := int(clip_report.get("source_renderable_mesh_count", -1))
			if expected_mesh_count < 1 or imported_scene_meshes.size() != expected_mesh_count or exported_meshes.size() + static_parts.size() != expected_mesh_count:
				vat_static_parts_retained = false
			for static_part in static_parts:
				var static_name := str(static_part.get("mesh_name", ""))
				if static_name.is_empty() or not imported_scene_meshes.has(static_name) or exported_meshes.values().has(static_name):
					vat_static_parts_retained = false
			for dynamic_name in exported_meshes.values():
				if not imported_scene_meshes.has(str(dynamic_name)):
					vat_static_parts_retained = false
	for clip_instance_value in vat_scene_cache.values():
		if is_instance_valid(clip_instance_value):
			clip_instance_value.free()
	var vat_status := "PASSED" if clips_with_moving_mesh == 6 and vat_validated_count == vat_results.size() and vat_results.size() >= 6 and not vat_failed and unexpected_vat_clips.is_empty() and vat_static_parts_retained else "FAILED"
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
		"validated_vat_clip_count": clips_with_moving_mesh,
		"vat_exported_deforming_mesh_count": vat_validated_count,
		"vat_static_parts_retained": vat_static_parts_retained,
		"vat_missing_clips": missing_vat_clips,
		"vat_unexpected_clips": unexpected_vat_clips,
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
	if skeletal_poc_results.size() != 6 or skeletal_poc_failed:
		push_error("C3 skeletal POC validation failed: all six reference clips must import with valid skeleton animation.")
		quit(1)
		return
	if vat_status != "PASSED":
		push_error("C3 VAT validation failed: all six clips, deforming meshes, source vertex order, and static-part retention must pass.")
		quit(1)
		return

	if animated == 0 or morph_mesh_nodes == 0 or total_animation_tracks == 0:
		push_error("C3 GLB validation: converted models did not expose usable morph animation tracks.")
		quit(1)
		return
	print("C3 GLB VALIDATION PASSED: ", valid, " textured models imported; ", total_surfaces, " surfaces; ", morph_mesh_nodes, " morph-capable mesh nodes; ", animated, " animated models; ", total_animation_tracks, " animation tracks; ", total_animation_keys, " keys.")
	quit(0)
