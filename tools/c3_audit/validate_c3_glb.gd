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
		for mesh_node in meshes:
			var mesh_instance := mesh_node as MeshInstance3D
			if mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() <= 0:
				push_error("C3 GLB validation: empty mesh or no surfaces in " + path)
				instance.free()
				quit(1)
				return
			var bounds := mesh_instance.get_aabb()
			if bounds.size.x <= 0.0001 or bounds.size.y <= 0.0001 or bounds.size.z <= 0.0001:
				push_error("C3 GLB validation: degenerate geometry bounds in " + path)
				instance.free()
				quit(1)
				return
			model_surfaces += mesh_instance.mesh.get_surface_count()
		var animation_player := instance.find_child("*", "AnimationPlayer", true, false)
		var animation_count := 0
		if animation_player is AnimationPlayer:
			animation_count = animation_player.get_animation_list().size()
		if animation_count > 0:
			animated += 1
		total_surfaces += model_surfaces
		print("C3 GLB OK: ", path, " | MeshInstance3D: ", meshes.size(), " | surfaces: ", model_surfaces, " | animations: ", animation_count)
		instance.free()
		valid += 1
	if animated == 0:
		push_error("C3 GLB validation: no converted C3 model exposes an imported animation.")
		quit(1)
		return
	print("C3 GLB VALIDATION PASSED: ", valid, " textured models imported; ", total_surfaces, " surfaces; ", animated, " models expose animation tracks.")
	quit(0)
