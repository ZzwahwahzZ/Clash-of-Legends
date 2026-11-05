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
		print("C3 GLB OK: ", path, " | MeshInstance3D: ", meshes.size(), " | surfaces: ", model_surfaces, " | morph meshes: ", model_morph_meshes, " | animation tracks: ", model_animation_tracks, " | animation keys: ", model_animation_keys)
		instance.free()
		valid += 1
	if animated == 0 or morph_mesh_nodes == 0 or total_animation_tracks == 0:
		push_error("C3 GLB validation: converted models did not expose usable morph animation tracks.")
		quit(1)
		return
	print("C3 GLB VALIDATION PASSED: ", valid, " textured models imported; ", total_surfaces, " surfaces; ", morph_mesh_nodes, " morph-capable mesh nodes; ", animated, " animated models; ", total_animation_tracks, " animation tracks; ", total_animation_keys, " keys.")
	quit(0)
