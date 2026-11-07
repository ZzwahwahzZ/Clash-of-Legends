extends Node
## Downloads, verifies, and mounts optional Godot PCK packages.
## Multiple independent HTTPRequest nodes allow safe parallel downloads.

signal manifest_loaded(package_count: int)
signal download_progress(package_id: String, received_bytes: int, total_bytes: int)
signal package_installed(package_id: String, path: String)
signal package_failed(package_id: String, reason: String)
signal package_finished(package_id: String, success: bool, reason: String)
signal aggregate_progress(received_bytes: int, total_bytes: int, completed_packages: int, total_packages: int, active_downloads: int)

const MANIFEST_URL := "https://raw.githubusercontent.com/ZzwahwahzZ/Clash-of-Legends/main/RESOURCE_MANIFEST"
const INSTALL_DIR := "user://resource_packs"
const MAX_MANIFEST_BYTES := 1024 * 1024
const APPLICATION_ID := "com.zwahwahzz.clashoflegends"
const GODOT_VERSION := "4.3"
const SUPPORTED_RELEASE_TAGS := ["resource-packs-v4", "owned-resource-packs-v1"]
const MAX_PARALLEL_DOWNLOADS := 3
const DOWNLOAD_MAX_ATTEMPTS := 4
const DOWNLOAD_TIMEOUT_SECONDS := 1200.0
const DOWNLOAD_CHUNK_BYTES := 16 * 1024 * 1024

var manifest: Dictionary = {}
var packages: Dictionary = {}
var installed_packages: Dictionary = {}
var busy := false
# package_id -> {request, temp_path, final_path, expected_size, expected_hash}
var _active_downloads: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(INSTALL_DIR))
	call_deferred("_bootstrap_installed_resources")

func _bootstrap_installed_resources() -> void:
	var cache_path := INSTALL_DIR.path_join("RESOURCE_MANIFEST")
	if FileAccess.file_exists(cache_path):
		var cache_file := FileAccess.open(cache_path, FileAccess.READ)
		if cache_file:
			var parser := JSON.new()
			var parse_error := parser.parse(cache_file.get_as_text())
			cache_file.close()
			if parse_error == OK and typeof(parser.data) == TYPE_DICTIONARY and SUPPORTED_RELEASE_TAGS.has(str(parser.data.get("release_tag", ""))):
				_accept_manifest(parser.data)
	if packages.is_empty():
		await refresh_manifest()
	await _load_installed_packages()

func refresh_manifest(url: String = MANIFEST_URL) -> bool:
	if busy:
		return false
	if not url.begins_with("https://"):
		push_error("Resource manifest must use HTTPS.")
		return false
	busy = true
	var request_node := HTTPRequest.new()
	request_node.timeout = 60.0
	add_child(request_node)
	var error := request_node.request(url, ["Accept: application/json"])
	if error != OK:
		request_node.queue_free()
		busy = false
		return false
	var response: Array = await request_node.request_completed
	request_node.queue_free()
	busy = false
	if response.size() < 4 or response[1] != 200 or response[3].size() > MAX_MANIFEST_BYTES:
		push_error("Resource manifest request failed or exceeded size limit.")
		return false
	var parser := JSON.new()
	if parser.parse(response[3].get_string_from_utf8()) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		push_error("Resource manifest is not valid JSON.")
		return false
	return _accept_manifest(parser.data)

func _accept_manifest(candidate: Dictionary) -> bool:
	if str(candidate.get("package_id", "")) != APPLICATION_ID:
		push_error("Resource manifest belongs to a different Android application.")
		return false
	if not SUPPORTED_RELEASE_TAGS.has(str(candidate.get("release_tag", ""))):
		push_error("Resource manifest release tag does not match this client.")
		return false
	var entries: Variant = candidate.get("resource_packages", [])
	if typeof(entries) != TYPE_ARRAY:
		return false
	var validated: Dictionary = {}
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			return false
		var package_id := str(entry.get("package_id", ""))
		var filename := str(entry.get("file_name", ""))
		var url_value := str(entry.get("download_url", ""))
		var size_value := int(entry.get("size_bytes", 0))
		var digest := str(entry.get("sha256", "")).to_lower()
		if package_id.is_empty() or filename.is_empty() or filename.get_file() != filename:
			return false
		if not filename.to_lower().ends_with(".pck") or not url_value.begins_with("https://"):
			return false
		if size_value <= 0 or size_value > 3 * 1024 * 1024 * 1024 or digest.length() != 64 or not _is_hex_digest(digest):
			return false
		if str(entry.get("godot_version", "")) != GODOT_VERSION:
			return false
		if str(entry.get("platform", "all")) not in ["all", "android"]:
			return false
		if validated.has(package_id):
			return false
		validated[package_id] = entry
	manifest = candidate
	packages = validated
	var cache := FileAccess.open(INSTALL_DIR.path_join("RESOURCE_MANIFEST"), FileAccess.WRITE)
	if cache:
		cache.store_string(JSON.stringify(candidate, "\t"))
		cache.close()
	manifest_loaded.emit(packages.size())
	_emit_aggregate_progress()
	return true

func _load_installed_packages() -> void:
	installed_packages.clear()
	var package_ids: Array = packages.keys()
	package_ids.sort()
	for package_id in package_ids:
		# Yield between packs so the opening screen can keep rendering on phones.
		await get_tree().process_frame
		var entry: Dictionary = packages[package_id]
		var bundled_path := "res://bundled/" + str(entry.file_name)
		if FileAccess.file_exists(bundled_path):
			# Bundled packs are covered by the signed APK and the CI SHA-256 audit.
			# Avoid hashing hundreds of MB again on every launch.
			if ProjectSettings.load_resource_pack(bundled_path, true):
				installed_packages[package_id] = true
				package_installed.emit(package_id, bundled_path)
				_emit_aggregate_progress()
			else:
				push_warning("Bundled resource pack could not be mounted: " + bundled_path)
			continue
		var path := INSTALL_DIR.path_join(str(entry.file_name))
		if not FileAccess.file_exists(path):
			continue
		var marker_path := path + ".verified"
		var marker_valid := false
		if FileAccess.file_exists(marker_path):
			var marker := FileAccess.open(marker_path, FileAccess.READ)
			if marker:
				marker_valid = marker.get_as_text().strip_edges() == str(entry.sha256).to_lower() + ":" + str(entry.size_bytes)
				marker.close()
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var actual_size := file.get_length()
		file.close()
		if actual_size != int(entry.size_bytes):
			continue
		if not marker_valid:
			var verifier := Thread.new()
			if verifier.start(Callable(self, "_verify_package_file").bind(path, int(entry.size_bytes), str(entry.sha256).to_lower())) != OK:
				continue
			while verifier.is_started():
				await get_tree().process_frame
			if not bool(verifier.wait_to_finish()):
				continue
			var marker_write := FileAccess.open(marker_path, FileAccess.WRITE)
			if marker_write:
				marker_write.store_string(str(entry.sha256).to_lower() + ":" + str(entry.size_bytes))
				marker_write.close()
		if ProjectSettings.load_resource_pack(path, true):
			installed_packages[package_id] = true
			package_installed.emit(package_id, path)
		_emit_aggregate_progress()

func _verify_package_file(path: String, expected_size: int, expected_hash: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var actual_size := file.get_length()
	file.close()
	return actual_size == expected_size and _sha256_file(path) == expected_hash


func emit_current_progress() -> void:
	_emit_aggregate_progress()

func get_missing_package_count() -> int:
	var missing := 0
	for package_id in packages.keys():
		if not is_package_installed(str(package_id)):
			missing += 1
	return missing

func get_total_package_bytes() -> int:
	var total := 0
	for entry in packages.values():
		total += int(entry.get("size_bytes", 0))
	return total

func _emit_aggregate_progress() -> void:
	var total_bytes := get_total_package_bytes()
	var received_bytes := 0
	var completed := 0
	for package_id in packages.keys():
		var entry: Dictionary = packages[package_id]
		var expected := int(entry.get("size_bytes", 0))
		if is_package_installed(str(package_id)):
			received_bytes += expected
			completed += 1
		elif _active_downloads.has(package_id):
			var info: Dictionary = _active_downloads[package_id]
			received_bytes += mini(maxi(int(info.get("received_bytes", 0)), 0), expected)
	aggregate_progress.emit(received_bytes, total_bytes, completed, packages.size(), _active_downloads.size())

func is_package_installed(package_id: String) -> bool:
	return bool(installed_packages.get(package_id, false))

func download_all_packages() -> bool:
	if packages.is_empty() and not await refresh_manifest():
		return false
	var pending: Array = []
	var package_ids: Array = packages.keys()
	package_ids.sort()
	for package_id in package_ids:
		if not is_package_installed(str(package_id)):
			pending.append(str(package_id))
	if pending.is_empty():
		return true

	var attempts: Dictionary = {}
	var all_success := true
	while not pending.is_empty() or not _active_downloads.is_empty():
		while not pending.is_empty() and _active_downloads.size() < MAX_PARALLEL_DOWNLOADS:
			var next_id := str(pending.pop_front())
			attempts[next_id] = int(attempts.get(next_id, 0)) + 1
			if not _start_download(next_id):
				if int(attempts[next_id]) < DOWNLOAD_MAX_ATTEMPTS:
					pending.append(next_id)
				else:
					all_success = false
		if _active_downloads.is_empty():
			continue
		var completion: Array = await package_finished
		if completion.size() >= 3 and not bool(completion[1]):
			var failed_id := str(completion[0])
			var used_attempts := int(attempts.get(failed_id, DOWNLOAD_MAX_ATTEMPTS))
			if used_attempts < DOWNLOAD_MAX_ATTEMPTS:
				# Retry transient network/server failures without discarding already
				# verified packages. A short backoff avoids hammering the release host.
				await get_tree().create_timer(float(used_attempts)).timeout
				pending.append(failed_id)
			else:
				all_success = false
	return all_success and pending.is_empty() and _active_downloads.is_empty() and get_missing_package_count() == 0

func download_package(package_id: String) -> bool:
	if is_package_installed(package_id):
		return true
	if not packages.has(package_id) and (packages.is_empty() and not await refresh_manifest()):
		package_failed.emit(package_id, "تعذر تحميل بيان الموارد")
		package_finished.emit(package_id, false, "تعذر تحميل بيان الموارد")
		return false
	if not packages.has(package_id):
		package_failed.emit(package_id, "حزمة الموارد غير منشورة في البيان")
		package_finished.emit(package_id, false, "حزمة الموارد غير منشورة في البيان")
		return false
	if not _active_downloads.has(package_id) and not _start_download(package_id):
		return false
	while true:
		var completion: Array = await package_finished
		if completion.size() >= 2 and str(completion[0]) == package_id:
			return bool(completion[1])
	return false

func _start_download(package_id: String) -> bool:
	if not packages.has(package_id) or is_package_installed(package_id) or _active_downloads.has(package_id):
		return false
	var entry: Dictionary = packages[package_id]
	var filename := str(entry.file_name)
	var expected_size := int(entry.size_bytes)
	var expected_hash := str(entry.sha256).to_lower()
	var url := str(entry.download_url)
	var final_path := INSTALL_DIR.path_join(filename)
	var temp_path := INSTALL_DIR.path_join("." + filename + ".download")
	var received_bytes := 0
	if FileAccess.file_exists(temp_path):
		var partial := FileAccess.open(temp_path, FileAccess.READ)
		if partial:
			received_bytes = partial.get_length()
			partial.close()
		if received_bytes > expected_size:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
			received_bytes = 0
	var request_node := HTTPRequest.new()
	request_node.timeout = DOWNLOAD_TIMEOUT_SECONDS
	request_node.body_size_limit = DOWNLOAD_CHUNK_BYTES
	request_node.use_threads = true
	request_node.accept_gzip = false
	add_child(request_node)
	_active_downloads[package_id] = {
		"request": request_node,
		"temp_path": temp_path,
		"final_path": final_path,
		"expected_size": expected_size,
		"expected_hash": expected_hash,
		"url": url,
		"received_bytes": received_bytes
	}
	busy = true
	call_deferred("_download_package_chunks", package_id)
	return true

func _process(_delta: float) -> void:
	for package_id in _active_downloads:
		var info: Dictionary = _active_downloads[package_id]
		download_progress.emit(
			str(package_id),
			int(info.get("received_bytes", 0)),
			int(info.get("expected_size", 0))
		)
	_emit_aggregate_progress()

func _download_package_chunks(package_id: String) -> void:
	if not _active_downloads.has(package_id):
		return
	var info: Dictionary = _active_downloads[package_id]
	var request_node: HTTPRequest = info.get("request")
	if not is_instance_valid(request_node):
		_finish_failure(package_id, "تعذر إنشاء اتصال التنزيل", true)
		return
	var temp_path := str(info.get("temp_path", ""))
	var url := str(info.get("url", ""))
	var expected_size := int(info.get("expected_size", 0))
	var offset := int(info.get("received_bytes", 0))
	while offset < expected_size:
		var end_byte := mini(offset + DOWNLOAD_CHUNK_BYTES - 1, expected_size - 1)
		var chunk_result: Dictionary = await _fetch_range_chunk(
			request_node, url, offset, end_byte, expected_size
		)
		if not _active_downloads.has(package_id):
			return
		if not bool(chunk_result.get("success", false)):
			_finish_failure(
				package_id,
				str(chunk_result.get("reason", "فشل تنزيل جزء من الحزمة")),
				bool(chunk_result.get("preserve_partial", true))
			)
			return
		var body: PackedByteArray = chunk_result.get("body", PackedByteArray())
		if not _append_verified_chunk(temp_path, body, end_byte + 1):
			_finish_failure(package_id, "تعذر حفظ جزء التنزيل في موضعه الصحيح", false)
			return
		var written_size := end_byte + 1
		offset = written_size
		info["received_bytes"] = offset
		_active_downloads[package_id] = info
		download_progress.emit(package_id, offset, expected_size)
		_emit_aggregate_progress()
		await get_tree().process_frame
	await _verify_and_install_package(package_id)

func _fetch_range_chunk(
	request_node: HTTPRequest,
	url: String,
	start_byte: int,
	end_byte: int,
	total_bytes: int
) -> Dictionary:
	var headers := PackedStringArray([
		"Range: bytes=%d-%d" % [start_byte, end_byte],
		"Accept-Encoding: identity"
	])
	var request_error := request_node.request(url, headers, HTTPClient.METHOD_GET)
	if request_error != OK:
		return {
			"success": false,
			"reason": "تعذر بدء جزء التنزيل: %s" % request_error,
			"preserve_partial": true
		}
	var response: Array = await request_node.request_completed
	if response.size() < 4:
		return {"success": false, "reason": "استجابة تنزيل غير مكتملة", "preserve_partial": true}
	var result_code := int(response[0])
	var response_code := int(response[1])
	var response_headers: PackedStringArray = response[2]
	var body: PackedByteArray = response[3]
	if result_code != HTTPRequest.RESULT_SUCCESS:
		return {
			"success": false,
			"reason": "انقطع اتصال تنزيل الحزمة (result %d)" % result_code,
			"preserve_partial": true
		}
	if response_code != 206:
		return {
			"success": false,
			"reason": "خادم الموارد لم يقبل نطاق التنزيل (HTTP %d)" % response_code,
			"preserve_partial": false
		}
	var expected_range := "bytes %d-%d/%d" % [start_byte, end_byte, total_bytes]
	var actual_range := _response_header(response_headers, "content-range").to_lower()
	if not actual_range.begins_with(expected_range):
		return {
			"success": false,
			"reason": "ترويسة Content-Range لا تطابق الجزء المطلوب",
			"preserve_partial": false
		}
	var expected_chunk_size := end_byte - start_byte + 1
	if body.size() != expected_chunk_size:
		return {
			"success": false,
			"reason": "حجم جزء التنزيل لا يطابق النطاق المطلوب",
			"preserve_partial": false
		}
	return {"success": true, "body": body}

func _append_verified_chunk(temp_path: String, body: PackedByteArray, expected_file_size: int) -> bool:
	if not FileAccess.file_exists(temp_path):
		var create_file := FileAccess.open(temp_path, FileAccess.WRITE)
		if create_file == null:
			return false
		create_file.close()
	var output := FileAccess.open(temp_path, FileAccess.READ_WRITE)
	if output == null:
		return false
	output.seek_end()
	output.store_buffer(body)
	var actual_size := output.get_length()
	output.close()
	return actual_size == expected_file_size

func _response_header(headers: PackedStringArray, header_name: String) -> String:
	for header in headers:
		var separator := header.find(":")
		if separator < 0:
			continue
		var name := header.substr(0, separator).strip_edges().to_lower()
		if name == header_name.to_lower():
			return header.substr(separator + 1).strip_edges()
	return ""

func _verify_and_install_package(package_id: String) -> void:
	if not _active_downloads.has(package_id):
		return
	var info: Dictionary = _active_downloads[package_id]
	var temp_path := str(info.temp_path)
	var final_path := str(info.final_path)
	var expected_size := int(info.expected_size)
	var expected_hash := str(info.expected_hash)
	var file := FileAccess.open(temp_path, FileAccess.READ)
	if file == null:
		_finish_failure(package_id, "ملف التنزيل غير موجود", false)
		return
	var actual_size := file.get_length()
	file.close()
	if actual_size != expected_size:
		_finish_failure(package_id, "حجم الحزمة لا يطابق البيان", false)
		return
	var verifier := Thread.new()
	var thread_error := verifier.start(
		Callable(self, "_verify_package_file").bind(temp_path, expected_size, expected_hash)
	)
	if thread_error != OK:
		_finish_failure(package_id, "تعذر بدء فحص سلامة الحزمة", true)
		return
	while verifier.is_started():
		await get_tree().process_frame
	var verified := bool(verifier.wait_to_finish())
	if not verified:
		_finish_failure(package_id, "فشل التحقق من SHA-256", false)
		return
	var absolute_temp := ProjectSettings.globalize_path(temp_path)
	var absolute_final := ProjectSettings.globalize_path(final_path)
	if FileAccess.file_exists(final_path):
		DirAccess.remove_absolute(absolute_final)
	var rename_error := DirAccess.rename_absolute(absolute_temp, absolute_final)
	if rename_error != OK:
		_finish_failure(package_id, "تعذر تثبيت ملف الحزمة", true)
		return
	if not ProjectSettings.load_resource_pack(final_path, true):
		DirAccess.remove_absolute(absolute_final)
		if FileAccess.file_exists(final_path + ".verified"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(final_path + ".verified"))
		_finish_failure(package_id, "Godot رفض تحميل حزمة PCK", false)
		return
	var marker := FileAccess.open(final_path + ".verified", FileAccess.WRITE)
	if marker:
		marker.store_string(expected_hash + ":" + str(expected_size))
		marker.close()
	installed_packages[package_id] = true
	package_installed.emit(package_id, final_path)
	_emit_aggregate_progress()
	_finish_success(package_id)

func _finish_success(package_id: String) -> void:
	_clear_download(package_id)
	package_finished.emit(package_id, true, "")

func _finish_failure(package_id: String, reason: String, preserve_partial: bool = true) -> void:
	if _active_downloads.has(package_id):
		var info: Dictionary = _active_downloads[package_id]
		var temp_path := str(info.get("temp_path", ""))
		if not preserve_partial and not temp_path.is_empty() and FileAccess.file_exists(temp_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
	_clear_download(package_id)
	package_failed.emit(package_id, reason)
	package_finished.emit(package_id, false, reason)
	_emit_aggregate_progress()

func _clear_download(package_id: String) -> void:
	if not _active_downloads.has(package_id):
		return
	var info: Dictionary = _active_downloads[package_id]
	var request_node: HTTPRequest = info.get("request")
	_active_downloads.erase(package_id)
	if is_instance_valid(request_node):
		request_node.queue_free()
	busy = not _active_downloads.is_empty()

func _sha256_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		file.close()
		return ""
	while not file.eof_reached():
		var chunk := file.get_buffer(1024 * 1024)
		if chunk.is_empty():
			break
		context.update(chunk)
	file.close()
	return context.finish().hex_encode()

func _is_hex_digest(value: String) -> bool:
	for character in value:
		if not "0123456789abcdef".contains(character):
			return false
	return true
