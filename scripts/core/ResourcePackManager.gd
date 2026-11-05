extends Node
## Downloads and verifies optional Godot PCK packages from the signed-by-hash
## RESOURCE_MANIFEST. Empty manifests are intentionally safe: no fake packs.

signal manifest_loaded(package_count: int)
signal download_progress(package_id: String, received_bytes: int, total_bytes: int)
signal package_installed(package_id: String, path: String)
signal package_failed(package_id: String, reason: String)
signal package_finished(package_id: String, success: bool, reason: String)

const MANIFEST_URL := "https://github.com/ZzwahwahzZ/Clash-of-Legends/releases/download/resource-packs-v3/RESOURCE_MANIFEST"
const INSTALL_DIR := "user://resource_packs"
const MAX_MANIFEST_BYTES := 1024 * 1024
const APPLICATION_ID := "com.zwahwahzz.clashoflegends"
const GODOT_VERSION := "4.3"
const RESOURCE_RELEASE_TAG := "resource-packs-v3"

var manifest: Dictionary = {}
var packages: Dictionary = {}
var installed_packages: Dictionary = {}
var busy := false
var _active_request: HTTPRequest
var _active_package_id := ""

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
			if parse_error == OK and typeof(parser.data) == TYPE_DICTIONARY and str(parser.data.get("release_tag", "")) == RESOURCE_RELEASE_TAG:
				_accept_manifest(parser.data)
	if packages.is_empty():
		await refresh_manifest()
	_load_installed_packages()

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
	if str(candidate.get("release_tag", "")) != RESOURCE_RELEASE_TAG:
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
	return true

func _load_installed_packages() -> void:
	installed_packages.clear()
	for package_id in packages:
		var entry: Dictionary = packages[package_id]
		var path := INSTALL_DIR.path_join(str(entry.file_name))
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var actual_size := file.get_length()
		file.close()
		if actual_size != int(entry.size_bytes) or _sha256_file(path) != str(entry.sha256).to_lower():
			continue
		if ProjectSettings.load_resource_pack(path, true):
			installed_packages[package_id] = true
			package_installed.emit(package_id, path)


func is_package_installed(package_id: String) -> bool:
	return bool(installed_packages.get(package_id, false))

func download_all_packages() -> bool:
	if packages.is_empty() and not await refresh_manifest():
		return false
	var package_ids: Array = packages.keys()
	package_ids.sort()
	for package_id in package_ids:
		if is_package_installed(str(package_id)):
			continue
		if not await download_package(str(package_id)):
			return false
		var result: Array = await package_finished
		if result.size() < 2 or str(result[0]) != str(package_id):
			return false
		if not bool(result[1]):
			return false
	return true

func download_package(package_id: String) -> bool:
	if busy:
		return false
	if packages.is_empty() and not await refresh_manifest():
		package_failed.emit(package_id, "تعذر تحميل بيان الموارد")
		package_finished.emit(package_id, false, "تعذر تحميل بيان الموارد")
		return false
	if not packages.has(package_id):
		package_failed.emit(package_id, "حزمة الموارد غير منشورة في البيان")
		package_finished.emit(package_id, false, "حزمة الموارد غير منشورة في البيان")
		return false
	if is_package_installed(package_id):
		return true
	var entry: Dictionary = packages[package_id]
	var filename := str(entry.file_name)
	var expected_size := int(entry.size_bytes)
	var expected_hash := str(entry.sha256).to_lower()
	var url := str(entry.download_url)
	var final_path := INSTALL_DIR.path_join(filename)
	var temp_path := INSTALL_DIR.path_join("." + filename + ".download")
	busy = true
	_active_package_id = package_id
	_active_request = HTTPRequest.new()
	_active_request.timeout = 900.0
	_active_request.download_file = temp_path
	_active_request.body_size_limit = expected_size
	add_child(_active_request)
	_active_request.request_completed.connect(_on_download_completed.bind(package_id, temp_path, final_path, expected_size, expected_hash), CONNECT_ONE_SHOT)
	var error := _active_request.request(url)
	if error != OK:
		_finish_failure(package_id, "فشل بدء التنزيل: %s" % error, temp_path)
		return false
	return true

func _process(_delta: float) -> void:
	if busy and is_instance_valid(_active_request) and _active_package_id != "":
		var total := _active_request.get_body_size()
		var received := _active_request.get_downloaded_bytes()
		download_progress.emit(_active_package_id, received, total)

func _on_download_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray, package_id: String, temp_path: String, final_path: String, expected_size: int, expected_hash: String) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_finish_failure(package_id, "فشل تنزيل الحزمة (HTTP %d، result %d)" % [response_code, result], temp_path)
		return
	var file := FileAccess.open(temp_path, FileAccess.READ)
	if file == null:
		_finish_failure(package_id, "ملف التنزيل غير موجود", temp_path)
		return
	var actual_size := file.get_length()
	file.close()
	if actual_size != expected_size:
		_finish_failure(package_id, "حجم الحزمة لا يطابق البيان", temp_path)
		return
	var actual_hash := _sha256_file(temp_path)
	if actual_hash != expected_hash:
		_finish_failure(package_id, "فشل التحقق من SHA-256", temp_path)
		return
	var absolute_temp := ProjectSettings.globalize_path(temp_path)
	var absolute_final := ProjectSettings.globalize_path(final_path)
	if FileAccess.file_exists(final_path):
		DirAccess.remove_absolute(absolute_final)
	var rename_error := DirAccess.rename_absolute(absolute_temp, absolute_final)
	if rename_error != OK:
		_finish_failure(package_id, "تعذر تثبيت ملف الحزمة", temp_path)
		return
	if not ProjectSettings.load_resource_pack(final_path, true):
		_finish_failure(package_id, "Godot رفض تحميل حزمة PCK", final_path)
		return
	installed_packages[package_id] = true
	package_installed.emit(package_id, final_path)
	package_finished.emit(package_id, true, "")
	_clear_request()

func _finish_failure(package_id: String, reason: String, path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	package_failed.emit(package_id, reason)
	package_finished.emit(package_id, false, reason)
	_clear_request()

func _clear_request() -> void:
	if is_instance_valid(_active_request):
		_active_request.queue_free()
	_active_request = null
	_active_package_id = ""
	busy = false

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
		if not ("0123456789abcdef".contains(character)):
			return false
	return true
