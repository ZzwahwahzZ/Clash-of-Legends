extends Control
class_name ResourcePacksUI

@onready var title_label: Label = get_node_or_null("Panel/Title")
@onready var status_label: Label = get_node_or_null("Panel/Status")
@onready var list_container: VBoxContainer = get_node_or_null("Panel/Scroll/PackageList")
@onready var close_button: Button = get_node_or_null("Panel/Close")
@onready var check_button: Button = get_node_or_null("Panel/DownloadAll")

func _ready() -> void:
	add_to_group("resource_packs_ui")
	visible = false
	if close_button:
		close_button.pressed.connect(close_ui)
	if check_button:
		check_button.text = "إعادة فحص الموارد المضمّنة"
		check_button.pressed.connect(_on_check_pressed)
	if ResourcePackManager:
		ResourcePackManager.manifest_loaded.connect(_refresh_view)
		ResourcePackManager.package_installed.connect(_on_package_installed)
		ResourcePackManager.package_failed.connect(_on_package_failed)
		call_deferred("_startup_resource_check")

func _startup_resource_check() -> void:
	if ResourcePackManager.packages.is_empty():
		await ResourcePackManager.refresh_manifest()
	if ResourcePackManager.packages.is_empty():
		visible = true
		_set_status("تعذّر قراءة بيان الموارد المضمّن داخل التطبيق: " + ResourcePackManager.last_error)
		return
	_refresh_view()
	if ResourcePackManager.get_missing_package_count() > 0:
		visible = true
		_set_status("بعض الحزم غير موجودة داخل APK. يلزم إعادة بناء التطبيق بالحزم الإحدى عشرة؛ لا يوجد تنزيل خارجي.")
	else:
		_set_status("اكتمل تجهيز الموارد المضمّنة. اللعبة جاهزة للعمل دون إنترنت.")

func open_ui() -> void:
	visible = true
	await _on_check_pressed()

func close_ui() -> void:
	visible = false

func _set_status(value: String) -> void:
	if status_label:
		status_label.text = value

func _refresh_view(_count: int = 0) -> void:
	if not list_container or not ResourcePackManager:
		return
	for child in list_container.get_children():
		child.queue_free()
	var ids: Array = ResourcePackManager.packages.keys()
	ids.sort()
	for package_id in ids:
		var entry: Dictionary = ResourcePackManager.packages[package_id]
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = str(entry.get("display_name_ar", package_id))
		var state := Label.new()
		var ready := ResourcePackManager.is_package_installed(str(package_id))
		state.text = "مُحمّلة داخل التطبيق ومركّبة" if ready else "مفقودة من APK"
		state.add_theme_color_override("font_color", Color("#79d69b") if ready else Color("#ff9a83"))
		row.add_child(label)
		row.add_child(state)
		list_container.add_child(row)
	if ResourcePackManager.get_missing_package_count() == 0:
		_set_status("كل الموارد مضمّنة ومركّبة محليًا. لا حاجة للإنترنت.")
	else:
		_set_status("الموارد الناقصة: %d. أعد بناء APK بعد تضمين جميع ملفات PCK." % ResourcePackManager.get_missing_package_count())

func _on_check_pressed() -> void:
	if check_button:
		check_button.disabled = true
	if ResourcePackManager.packages.is_empty():
		await ResourcePackManager.refresh_manifest()
	if not ResourcePackManager.packages.is_empty():
		await ResourcePackManager._load_embedded_packages()
	_refresh_view()
	if check_button:
		check_button.disabled = false

func _on_package_installed(_package_id: String, _path: String) -> void:
	_refresh_view()

func _on_package_failed(package_id: String, reason: String) -> void:
	_set_status("%s: %s" % [package_id, reason])
