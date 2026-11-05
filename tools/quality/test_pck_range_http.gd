extends SceneTree

func _initialize() -> void:
	call_deferred("_run_range_resume_test")

func _run_range_resume_test() -> void:
	var manifest_text := FileAccess.get_file_as_string("res://RESOURCE_MANIFEST")
	var parser := JSON.new()
	if parser.parse(manifest_text) != OK:
		push_error("PCK RANGE RESUME TEST FAILED: RESOURCE_MANIFEST is invalid.")
		quit(1)
		return
	var entries: Array = parser.data.get("resource_packages", [])
	var model_entry: Dictionary = {}
	for entry in entries:
		if typeof(entry) == TYPE_DICTIONARY and str(entry.get("package_id", "")) == "models":
			model_entry = entry
			break
	if model_entry.is_empty():
		push_error("PCK RANGE RESUME TEST FAILED: models package is missing.")
		quit(1)
		return
	var url := str(model_entry.get("download_url", ""))
	var total_size := int(model_entry.get("size_bytes", 0))
	var temp_path := "user://range_resume_test.bin"
	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))

	# First request: save the first 1 KiB, then destroy the downloader to simulate app interruption.
	var first_manager := preload("res://scripts/core/ResourcePackManager.gd").new()
	var first_request := _new_request(1024)
	var first: Dictionary = await first_manager._fetch_range_chunk(first_request, url, 0, 1023, total_size)
	if not bool(first.get("success", false)):
		push_error("PCK RANGE RESUME TEST FAILED on first chunk: " + str(first.get("reason", "unknown")))
		quit(1)
		return
	if not first_manager._append_verified_chunk(temp_path, first.get("body", PackedByteArray()), 1024):
		push_error("PCK RANGE RESUME TEST FAILED: first partial chunk was not persisted.")
		quit(1)
		return
	first_request.queue_free()
	first_manager.free()
	await process_frame

	# Second request: a fresh manager resumes at byte 1024 and appends the next 1 KiB.
	var resume_manager := preload("res://scripts/core/ResourcePackManager.gd").new()
	var resume_request := _new_request(1024)
	var second: Dictionary = await resume_manager._fetch_range_chunk(resume_request, url, 1024, 2047, total_size)
	if not bool(second.get("success", false)):
		push_error("PCK RANGE RESUME TEST FAILED on resumed chunk: " + str(second.get("reason", "unknown")))
		quit(1)
		return
	if not resume_manager._append_verified_chunk(temp_path, second.get("body", PackedByteArray()), 2048):
		push_error("PCK RANGE RESUME TEST FAILED: resumed chunk was not appended at the correct offset.")
		quit(1)
		return

	# Third request: compare the persisted two-chunk file with the same contiguous 2 KiB range.
	var reference: Dictionary = await resume_manager._fetch_range_chunk(resume_request, url, 0, 2047, total_size)
	if not bool(reference.get("success", false)):
		push_error("PCK RANGE RESUME TEST FAILED on reference range: " + str(reference.get("reason", "unknown")))
		quit(1)
		return
	var persisted := FileAccess.get_file_as_bytes(temp_path)
	if persisted.size() != 2048 or persisted != reference.get("body", PackedByteArray()):
		push_error("PCK RANGE RESUME TEST FAILED: resumed bytes do not match the contiguous server range.")
		quit(1)
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
	resume_request.queue_free()
	resume_manager.free()
	print("GODOT HTTP RANGE RESUME TEST PASSED: interrupted partial data resumed at byte 1024 and matched the contiguous 2 KiB reference.")
	quit(0)

func _new_request(body_limit: int) -> HTTPRequest:
	var request := HTTPRequest.new()
	request.timeout = 60.0
	request.body_size_limit = body_limit
	request.use_threads = true
	request.accept_gzip = false
	root.add_child(request)
	return request
