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
		for mesh_node in meshes:
			if mesh_node.mesh == null:
				push_error("C3 GLB validation: empty mesh in " + path)
				instance.free()
				quit(1)
				return
		print("C3 GLB OK: ", path, " | MeshInstance3D: ", meshes.size())
		instance.free()
		valid += 1
	print("C3 GLB VALIDATION PASSED: ", valid, " textured models imported.")
	quit(0)
