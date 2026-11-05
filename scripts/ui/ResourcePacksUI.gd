extends Control
class_name ResourcePacksUI

@onready var title_label: Label = get_node_or_null("Panel/Title")
@onready var status_label: Label = get_node_or_null("Panel/Status")
@onready var list_container: VBoxContainer = get_node_or_null("Panel/Scroll/PackageList")
@onready var close_button: Button = get_node_or_null("Panel/Close")
@onready var download_all_button: Button = get_node_or_null("Panel/DownloadAll")

var row_controls: Dictionary = {}

func _ready() -> void:
	add_to_group("resource_packs_ui")
	visible = false
	if close_button:
		close_button.pressed.connect(close_ui)
	if download_all_button:
		download_all_button.pressed.connect(_on_download_all_pressed)
	if ResourcePackManager:
		ResourcePackManager.manifest_loaded.connect(_on_manifest_loaded)
		ResourcePackManager.download_progress.connect(_on_download_progress)
		ResourcePackManager.package_installed.connect(_on_package_installed)
		ResourcePackManager.package_failed.connect(_on_package_failed)
		call_deferred("_startup_resource_check")

func _startup_resource_check() -> void:
	# Give the autoload bootstrap a moment to read its cached manifest first.
	for _attempt in range(120):
		if not ResourcePackManager.busy:
			break
		await get_tree().process_frame
	await get_tree().process_frame
	if ResourcePackManager.packages.is_empty():
		_set_status("جارٍ فحص موارد اللعبة..." if _is_ar() else "Checking game resources...")
		await ResourcePackManager.refresh_manifest()
	if ResourcePackManager.packages.is_empty():
		visible = true
		_set_status("تعذر الوصول إلى بيان الموارد. افحص اتصال الإنترنت واضغط إعادة المحاولة." if _is_ar() else "Could not reach the resource manifest. Check your connection and retry.")
		if download_all_button:
			download_all_button.disabled = false
			download_all_button.text = "إعادة المحاولة" if _is_ar() else "Retry"
		return
	var missing := false
	for package_id in ResourcePackManager.packages:
		if not ResourcePackManager.is_package_installed(str(package_id)):
			missing = true
			break
	if missing:
		await open_ui()
		# First launch: begin downloading all required packs automatically.
		await _on_download_all_pressed()
	else:
		_set_status("كل موارد اللعبة مثبتة ويمكن اللعب دون اتصال." if _is_ar() else "All game resources are installed. Offline play is ready.")

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
	if download_all_button:
		download_all_button.text = "تنزيل كل الموارد" if _is_ar() else "Download All Resources"

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
	if download_all_button:
		var all_installed := true
		for package_id in ResourcePackManager.packages:
			if not ResourcePackManager.is_package_installed(str(package_id)):
				all_installed = false
				break
		download_all_button.disabled = all_installed

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

func _on_download_all_pressed() -> void:
	if not ResourcePackManager:
		_set_status("مدير الموارد غير متاح" if _is_ar() else "Resource manager is unavailable")
		return
	if ResourcePackManager.packages.is_empty():
		_set_status("جارٍ إعادة محاولة الاتصال..." if _is_ar() else "Retrying manifest connection...")
		var refreshed := await ResourcePackManager.refresh_manifest()
		if refreshed:
			_build_package_rows()
		else:
			_set_status("لم نتمكن من الوصول إلى الموارد. حاول مرة أخرى." if _is_ar() else "Could not reach resources. Please retry.")
		return
	if download_all_button:
		download_all_button.disabled = true
		download_all_button.text = "جارٍ تنزيل الحزم..." if _is_ar() else "Downloading Packs..."
	var success := await ResourcePackManager.download_all_packages()
	if success:
		_set_status("اكتمل تنزيل كل الموارد والتحقق منها. يمكنك اللعب دون اتصال." if _is_ar() else "All resources downloaded and verified. You can play offline.")
	else:
		_set_status("توقف التنزيل عند حزمة لم تكتمل؛ يمكنك إعادة المحاولة." if _is_ar() else "A pack failed. You can retry the download.")
	_build_package_rows()
	_refresh_text()

func _on_package_failed(package_id: String, reason: String) -> void:
	var controls: Dictionary = row_controls.get(package_id, {})
	var action: Button = controls.get("action")
	if action:
		action.disabled = false
		action.text = "إعادة المحاولة" if _is_ar() else "Retry"
	_set_status("%s: %s" % [package_id, reason])
