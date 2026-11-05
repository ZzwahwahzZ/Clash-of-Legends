extends Control
class_name ResourcePacksUI

@onready var title_label: Label = get_node_or_null("Panel/Title")
@onready var status_label: Label = get_node_or_null("Panel/Status")
@onready var list_container: VBoxContainer = get_node_or_null("Panel/Scroll/PackageList")
@onready var close_button: Button = get_node_or_null("Panel/Close")

var row_controls: Dictionary = {}

func _ready() -> void:
	visible = false
	if close_button:
		close_button.pressed.connect(close_ui)
	if ResourcePackManager:
		ResourcePackManager.manifest_loaded.connect(_on_manifest_loaded)
		ResourcePackManager.download_progress.connect(_on_download_progress)
		ResourcePackManager.package_installed.connect(_on_package_installed)
		ResourcePackManager.package_failed.connect(_on_package_failed)

func open_ui() -> void:
	visible = true
	_refresh_text()
	if ResourcePackManager.packages.is_empty():
		_set_status("جارٍ تحميل بيان الموارد..." if _is_ar() else "Loading resource manifest...")
		var ok := await ResourcePackManager.refresh_manifest()
		if not ok:
			_set_status("تعذر الوصول إلى بيان الموارد" if _is_ar() else "Could not load resource manifest")
			return
	_build_package_rows()

func close_ui() -> void:
	visible = false

func _is_ar() -> bool:
	return GameManager == null or GameManager.current_language == "ar"

func _refresh_text() -> void:
	if title_label:
		title_label.text = "تنزيل موارد اللعبة" if _is_ar() else "Game Resource Downloads"
	if close_button:
		close_button.text = "إغلاق" if _is_ar() else "Close"

func _set_status(value: String) -> void:
	if status_label:
		status_label.text = value

func _on_manifest_loaded(_count: int) -> void:
	if visible:
		_build_package_rows()

func _build_package_rows() -> void:
	if not list_container:
		return
	for child in list_container.get_children():
		child.queue_free()
	row_controls.clear()
	var ids: Array = ResourcePackManager.packages.keys()
	ids.sort()
	for package_id in ids:
		var entry: Dictionary = ResourcePackManager.packages[package_id]
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label := Label.new()
		name_label.text = str(entry.get("display_name_ar", package_id)) if _is_ar() else str(entry.get("display_name_en", package_id))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var size_label := Label.new()
		size_label.text = "%.1f MB" % (float(entry.get("size_bytes", 0)) / 1048576.0)
		size_label.add_theme_font_size_override("font_size", 12)
		info.add_child(name_label)
		info.add_child(size_label)
		var progress := ProgressBar.new()
		progress.custom_minimum_size = Vector2(130, 18)
		progress.max_value = 100.0
		progress.value = 100.0 if ResourcePackManager.is_package_installed(package_id) else 0.0
		var action := Button.new()
		action.custom_minimum_size = Vector2(110, 42)
		action.text = "مثبت" if ResourcePackManager.is_package_installed(package_id) and _is_ar() else ("Installed" if ResourcePackManager.is_package_installed(package_id) else ("تنزيل" if _is_ar() else "Download"))
		action.disabled = ResourcePackManager.is_package_installed(package_id)
		action.pressed.connect(_on_download_pressed.bind(package_id))
		row.add_child(info)
		row.add_child(progress)
		row.add_child(action)
		list_container.add_child(row)
		row_controls[package_id] = {"progress":progress,"action":action,"name":name_label}
	_set_status("اختر الحزم التي تريد تنزيلها. يمكن اللعب دون اتصال بعد اكتمال التنزيل." if _is_ar() else "Choose the packs to download. The game can run offline after downloads finish.")

func _on_download_pressed(package_id: String) -> void:
	var controls: Dictionary = row_controls.get(package_id, {})
	var action: Button = controls.get("action")
	if action:
		action.disabled = true
		action.text = "جارٍ التنزيل..." if _is_ar() else "Downloading..."
	var started := await ResourcePackManager.download_package(package_id)
	if not started and action:
		action.disabled = false
		action.text = "إعادة المحاولة" if _is_ar() else "Retry"

func _on_download_progress(package_id: String, received: int, total: int) -> void:
	var controls: Dictionary = row_controls.get(package_id, {})
	var progress: ProgressBar = controls.get("progress")
	if progress:
		var expected := int(ResourcePackManager.packages.get(package_id, {}).get("size_bytes", total))
		var denominator := total if total > 0 else expected
		progress.value = clampf(float(received) / maxf(1.0, float(denominator)) * 100.0, 0.0, 100.0)
	_set_status(("تنزيل %s: %d / %d ميجابايت" if _is_ar() else "Downloading %s: %d / %d MB") % [package_id, int(received / 1048576), int(maxi(total, int(ResourcePackManager.packages.get(package_id, {}).get("size_bytes", 0))) / 1048576)])

func _on_package_installed(package_id: String, _path: String) -> void:
	var controls: Dictionary = row_controls.get(package_id, {})
	var action: Button = controls.get("action")
	var progress: ProgressBar = controls.get("progress")
	if action:
		action.disabled = true
		action.text = "مثبت" if _is_ar() else "Installed"
	if progress:
		progress.value = 100.0
	_set_status(("تم تثبيت حزمة %s والتحقق منها بنجاح" if _is_ar() else "Package %s installed and verified") % package_id)

func _on_package_failed(package_id: String, reason: String) -> void:
	var controls: Dictionary = row_controls.get(package_id, {})
	var action: Button = controls.get("action")
	if action:
		action.disabled = false
		action.text = "إعادة المحاولة" if _is_ar() else "Retry"
	_set_status("%s: %s" % [package_id, reason])
