extends SceneTree

func _initialize() -> void:
	call_deferred("_extract")

func _extract() -> void:
	var pack_path := "res://build/models.pck"
	if not FileAccess.file_exists(pack_path):
		push_error("C3 audit: models.pck is missing.")
		quit(1)
		return
	if not ProjectSettings.load_resource_pack(pack_path, true):
		push_error("C3 audit: Godot could not load models.pck.")
		quit(1)
		return
	var path_list_file := FileAccess.open("res://build/c3-paths.json", FileAccess.READ)
	if path_list_file == null:
		push_error("C3 audit: prepared C3 path list is missing.")
		quit(1)
		return
	var path_parser := JSON.new()
	if path_parser.parse(path_list_file.get_as_text()) != OK or not path_parser.data is Array:
		path_list_file.close()
		push_error("C3 audit: prepared C3 path list is invalid.")
		quit(1)
		return
	path_list_file.close()
	var paths: Array = path_parser.data
	if paths.is_empty():
		push_error("C3 audit: no original C3 paths were found in the source index.")
		quit(1)
		return
	var records: Array[Dictionary] = []
	for value in paths:
		var relative_path := str(value)
		var source_path := "res://" + relative_path
		var bytes := FileAccess.get_file_as_bytes(source_path)
		if bytes.is_empty():
			push_error("C3 audit: missing or empty C3 resource: " + source_path)
			continue
		records.append({"path": relative_path, "bytes": bytes})
	var absolute_build := ProjectSettings.globalize_path("res://build")
	DirAccess.make_dir_recursive_absolute(absolute_build)
	var output_path := ProjectSettings.globalize_path("res://build/c3-sources.bin")
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	if output == null:
		push_error("C3 audit: could not create binary extraction bundle.")
		quit(1)
		return
	output.store_32(records.size())
	var extracted := 0
	var total_bytes := 0
	for record in records:
		var relative_path := str(record["path"])
		var bytes: PackedByteArray = record["bytes"]
		var path_bytes := relative_path.to_utf8_buffer()
		output.store_32(path_bytes.size())
		output.store_buffer(path_bytes)
		output.store_64(bytes.size())
		output.store_buffer(bytes)
		extracted += 1
		total_bytes += bytes.size()
	output.close()
	print("C3 binary extraction complete: ", extracted, "/", records.size(), " models; ", total_bytes, " bytes.")
	if extracted == 0:
		quit(1)
	else:
		quit(0)
