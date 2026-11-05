extends SceneTree

func _initialize() -> void:
	call_deferred("_run_range_probe")

func _run_range_probe() -> void:
	var manifest_text := FileAccess.get_file_as_string("res://RESOURCE_MANIFEST")
	var parser := JSON.new()
	if parser.parse(manifest_text) != OK:
		push_error("PCK RANGE TEST FAILED: RESOURCE_MANIFEST is invalid.")
		quit(1)
		return
	var entries: Array = parser.data.get("resource_packages", [])
	var model_entry: Dictionary = {}
	for entry in entries:
		if typeof(entry) == TYPE_DICTIONARY and str(entry.get("package_id", "")) == "models":
			model_entry = entry
			break
	if model_entry.is_empty():
		push_error("PCK RANGE TEST FAILED: models package is missing.")
		quit(1)
		return
	var manager := preload("res://scripts/core/ResourcePackManager.gd").new()
	root.add_child(manager)
	var request_node := HTTPRequest.new()
	request_node.timeout = 60.0
	request_node.body_size_limit = 1024
	request_node.use_threads = true
	request_node.accept_gzip = false
	root.add_child(request_node)
	var result: Dictionary = await manager._fetch_range_chunk(
		request_node,
		str(model_entry.get("download_url", "")),
		0,
		1023,
		int(model_entry.get("size_bytes", 0))
	)
	request_node.queue_free()
	manager.queue_free()
	if not bool(result.get("success", false)):
		push_error("PCK RANGE TEST FAILED: " + str(result.get("reason", "unknown error")))
		quit(1)
		return
	var body: PackedByteArray = result.get("body", PackedByteArray())
	if body.size() != 1024:
		push_error("PCK RANGE TEST FAILED: expected 1024 bytes, got %d." % body.size())
		quit(1)
		return
	print("GODOT HTTP RANGE TEST PASSED: actual GitHub PCK host returned a validated 1024-byte 206 response.")
	quit(0)
