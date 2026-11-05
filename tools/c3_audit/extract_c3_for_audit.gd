extends SceneTree

func _initialize() -> void:
	call_deferred("_extract")

func _extract_bundle(paths: Array, output_path: String) -> int:
	var absolute_path := ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var output := FileAccess.open(absolute_path, FileAccess.WRITE)
	if output == null:
		push_error("C3/PVR audit: could not create bundle: " + absolute_path)
		return 0
	output.store_32(paths.size())
	var extracted := 0
	var total_bytes := 0
	for value in paths:
		var relative_path := str(value)
		var bytes := FileAccess.get_file_as_bytes("res://" + relative_path)
		var path_bytes := relative_path.to_utf8_buffer()
		output.store_32(path_bytes.size())
		output.store_buffer(path_bytes)
		output.store_64(bytes.size())
		if not bytes.is_empty():
			output.store_buffer(bytes)
			extracted += 1
			total_bytes += bytes.size()
		else:
			push_error("C3/PVR audit: missing resource: " + relative_path)
	output.close()
	print("Resource extraction bundle: ", extracted, "/", paths.size(), " files; ", total_bytes, " bytes -> ", output_path)
	return extracted

func _extract() -> void:
	# During the resource build, source files are already staged under resource_stage/models.
	# Read them directly to avoid creating/importing a large temporary PCK.
	if FileAccess.file_exists("res://build/models.pck"):
		if not ProjectSettings.load_resource_pack("res://build/models.pck", true):
			push_error("C3/PVR audit: Godot could not load models.pck.")
			quit(1)
	var c3_file := FileAccess.open("res://build/c3-paths.json", FileAccess.READ)
	var pvr_file := FileAccess.open("res://build/pvr-paths.json", FileAccess.READ)
	if c3_file == null or pvr_file == null:
		push_error("C3/PVR audit: prepared path lists are missing.")
		quit(1)
		return
	var c3_parser := JSON.new()
	var pvr_parser := JSON.new()
	if c3_parser.parse(c3_file.get_as_text()) != OK or not c3_parser.data is Array:
		push_error("C3/PVR audit: C3 path list is invalid.")
		quit(1)
		return
	if pvr_parser.parse(pvr_file.get_as_text()) != OK or not pvr_parser.data is Array:
		push_error("C3/PVR audit: PVR path list is invalid.")
		quit(1)
		return
	c3_file.close()
	pvr_file.close()
	var c3_paths: Array = c3_parser.data
	var pvr_paths: Array = pvr_parser.data
	var c3_count := _extract_bundle(c3_paths, "res://build/c3-sources.bin")
	var pvr_count := _extract_bundle(pvr_paths, "res://build/pvr-sources.bin")
	if c3_count == 0 or pvr_count == 0:
		quit(1)
	else:
		quit(0)
