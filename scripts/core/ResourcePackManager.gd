extends Node
## Offline-only resource bootstrap. All eleven PCK files must be embedded in the APK.
## This runtime never performs HTTP requests or downloads resource files.

signal manifest_loaded(package_count: int)
signal package_installed(package_id: String, path: String)
signal package_failed(package_id: String, reason: String)
signal package_finished(package_id: String, success: bool, reason: String)
signal aggregate_progress(received_bytes: int, total_bytes: int, completed_packages: int, total_packages: int, active_downloads: int)

const MANIFEST_PATH := "res://RESOURCE_MANIFEST"
const BUNDLED_DIR := "res://bundled"
const EXPECTED_PACKAGE_COUNT := 11
const APPLICATION_ID := "com.zwahwahzz.clashoflegends"
const GODOT_VERSION := "4.3"

var manifest: Dictionary = {}
var packages: Dictionary = {}
var installed_packages: Dictionary = {}
var busy := false
var last_error := ""
var _mount_started := false
var _mount_in_progress := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_bootstrap_embedded_resources")

func _bootstrap_embedded_resources() -> void:
	var manifest_ok := await refresh_manifest()
	if not manifest_ok:
		return
	await _load_embedded_packages()

func refresh_manifest(_unused_url: String = "") -> bool:
	# Kept as a compatibility method for existing screens; reads only APK contents.
	if not FileAccess.file_exists(MANIFEST_PATH):
		last_error = "ملف بيان الموارد غير موجود داخل التطبيق"
		push_error(last_error)
		return false
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		last_error = "تعذر قراءة بيان الموارد المضمّن"
		return false
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK or typeof(parser.data) != TYPE_DICTIONARY:
		last_error = "بيان الموارد المضمّن غير صالح"
		push_error(last_error)
		return false
	var candidate: Dictionary = parser.data
	if str(candidate.get("package_id", "")) != APPLICATION_ID:
		last_error = "بيان الموارد لا يخص هذا التطبيق"
		return false
	if str(candidate.get("release_tag", "")) != "resource-packs-v4":
		last_error = "إصدار حزم الموارد غير متوافق"
		return false
	var entries: Variant = candidate.get("resource_packages", [])
	if typeof(entries) != TYPE_ARRAY or entries.size() != EXPECTED_PACKAGE_COUNT:
		last_error = "يجب تضمين حزم الموارد الإحدى عشرة كاملة داخل APK"
		push_error(last_error)
		return false
	var validated: Dictionary = {}
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			last_error = "مدخل غير صالح في بيان الموارد"
			return false
		var package_id := str(entry.get("package_id", ""))
		var filename := str(entry.get("file_name", ""))
		var digest := str(entry.get("sha256", "")).to_lower()
		var size := int(entry.get("size_bytes", 0))
		if package_id.is_empty() or filename.get_file() != filename or not filename.to_lower().ends_with(".pck"):
			last_error = "اسم حزمة غير صالح"
			return false
		if size <= 0 or digest.length() != 64 or not _is_hex_digest(digest):
			last_error = "بيانات سلامة غير صالحة للحزمة: " + package_id
			return false
		if str(entry.get("godot_version", "")) != GODOT_VERSION:
			last_error = "إصدار Godot غير متوافق مع الحزمة: " + package_id
			return false
		if validated.has(package_id):
			last_error = "معرّف حزمة مكرر: " + package_id
			return false
		validated[package_id] = entry
	if validated.size() != EXPECTED_PACKAGE_COUNT:
		last_error = "عدد حزم الموارد غير مكتمل"
		return false
	manifest = candidate
	packages = validated
	manifest_loaded.emit(packages.size())
	_emit_aggregate_progress()
	return true

func _load_embedded_packages() -> void:
	if _mount_in_progress:
		while _mount_in_progress:
			await get_tree().process_frame
		return
	if _mount_started and get_missing_package_count() == 0:
		return
	_mount_in_progress = true
	_mount_started = true
	var ids: Array = packages.keys()
	ids.sort()
	for package_id in ids:
		if is_package_installed(str(package_id)):
			continue
		await get_tree().process_frame
		var entry: Dictionary = packages[package_id]
		var path := BUNDLED_DIR.path_join(str(entry.get("file_name", "")))
		if not FileAccess.file_exists(path):
			var reason := "الحزمة غير موجودة داخل APK: " + str(entry.get("file_name", ""))
			last_error = reason
			package_failed.emit(str(package_id), reason)
			package_finished.emit(str(package_id), false, reason)
			_emit_aggregate_progress()
			continue
		if ProjectSettings.load_resource_pack(path, true):
			installed_packages[str(package_id)] = true
			package_installed.emit(str(package_id), path)
			package_finished.emit(str(package_id), true, "")
		else:
			var reason := "تعذر تركيب الحزمة المضمّنة: " + str(entry.get("file_name", ""))
			last_error = reason
			package_failed.emit(str(package_id), reason)
			package_finished.emit(str(package_id), false, reason)
		_emit_aggregate_progress()
	_mount_in_progress = false

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

func is_package_installed(package_id: String) -> bool:
	return bool(installed_packages.get(package_id, false))

func _emit_aggregate_progress() -> void:
	var total := get_total_package_bytes()
	var received := 0
	var completed := 0
	for package_id in packages.keys():
		var entry: Dictionary = packages[package_id]
		if is_package_installed(str(package_id)):
			received += int(entry.get("size_bytes", 0))
			completed += 1
	aggregate_progress.emit(received, total, completed, packages.size(), 0)

# Compatibility wrappers for old UI/startup callers. These methods never download.
func download_all_packages() -> bool:
	if packages.is_empty() and not await refresh_manifest():
		return false
	if get_missing_package_count() > 0:
		await _load_embedded_packages()
	return get_missing_package_count() == 0

func download_package(package_id: String) -> bool:
	return is_package_installed(package_id)

func _is_hex_digest(value: String) -> bool:
	for character in value:
		if not "0123456789abcdef".contains(character):
			return false
	return true
