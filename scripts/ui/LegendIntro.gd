extends Control
## Lightweight, animated Arabic-first title and class-selection screen.
## Uses CanvasItem drawing only; the 3D world is not loaded until the player enters.

const GAME_SCENE := "res://scenes/core/MainGame.tscn"
const MUSIC_PATH := "res://assets/audio/extracted/00032_37806e94e3_centralplains.ogg"
const CLASSES := [
	{"ar":"محارب","en":"Warrior","tag":"قوة وصلابة"},
	{"ar":"ترجمان","en":"Trojan","tag":"هجوم كاسح"},
	{"ar":"رامٍ","en":"Archer","tag":"قنص وسرعة"},
	{"ar":"نينجا","en":"Ninja","tag":"ظلّ قاتل"},
	{"ar":"راهب","en":"Monk","tag":"روح وانضباط"},
	{"ar":"قرصان","en":"Pirate","tag":"مناورة ومهارة"},
	{"ar":"محارب التنين","en":"Dragon Warrior","tag":"قوة التنين"},
	{"ar":"سائر الرياح","en":"Windwalker","tag":"سرعة الرياح"},
	{"ar":"صاعق","en":"Thunderstriker","tag":"قوة البرق"},
	{"ar":"طاووس الماء","en":"Water Taoist","tag":"سحر الماء"},
	{"ar":"طاووس النار","en":"Fire Taoist","tag":"سحر النار"}
]
var selected_class := 0
var music_player: AudioStreamPlayer
var pulse := 0.0
var class_status: Label
var enter_button: Button
var class_grid: GridContainer
var intro_overlay: Control
var intro_tween: Tween
var intro_finished := false
var download_overlay: Control
var download_progress_bar: ProgressBar
var download_status_label: Label
var download_detail_label: Label
var download_start_button: Button
var download_running := false
var download_done := false

func _ready() -> void:
	_build_screen()
	_build_cinematic_intro()
	_start_music()
	set_process(true)

func _process(delta: float) -> void:
	pulse += delta
	queue_redraw()

func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color("#080d20"))
	draw_circle(Vector2(size.x * 0.72, size.y * 0.26), size.y * (0.20 + sin(pulse * 0.7) * 0.008), Color(0.24, 0.39, 0.68, 0.12))
	draw_circle(Vector2(size.x * 0.18, size.y * 0.78), size.y * 0.23, Color(0.65, 0.31, 0.12, 0.07))
	var horizon := size.y * 0.62
	var mountains := PackedVector2Array([Vector2(0,horizon),Vector2(size.x*0.12,size.y*.43),Vector2(size.x*.23,horizon*.94),Vector2(size.x*.38,size.y*.39),Vector2(size.x*.53,horizon),Vector2(size.x*.69,size.y*.42),Vector2(size.x*.82,horizon*.92),Vector2(size.x,size.y*.44),Vector2(size.x,size.y),Vector2(0,size.y)])
	draw_colored_polygon(mountains, Color("#142746"))
	draw_rect(Rect2(0, horizon, size.x, size.y-horizon), Color("#0b142a"))
	for i in range(12):
		var x := fposmod(float(i) * 173.0 + pulse * 4.0, size.x)
		var y := fposmod(float(i) * 83.0, horizon)
		draw_circle(Vector2(x,y), 1.4 + sin(pulse + i) * .5, Color(1.0,.82,.48,.65))

func _build_screen() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	root.add_theme_constant_override("margin_left", 24)
	root.add_theme_constant_override("margin_right", 24)
	root.add_theme_constant_override("margin_top", 16)
	root.add_theme_constant_override("margin_bottom", 16)
	add_child(root)

	var header := VBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 2)
	root.add_child(header)
	var title := Label.new()
	title.text = "صِـــراعُ الأَساطِير"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color("#ffe4a0"))
	header.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "حيثُ تُكتَبُ المَلاحِمُ وتَنهَضُ الأَساطِير"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color("#c8d8f3"))
	header.add_child(subtitle)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 260)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.06, 0.13, 0.88)
	panel_style.border_color = Color("#b8893e")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(16)
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	var choose := Label.new()
	choose.text = "اختر بطلك… واختر طريق الأسطورة"
	choose.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choose.add_theme_font_size_override("font_size", 22)
	choose.add_theme_color_override("font_color", Color("#f5d58d"))
	content.add_child(choose)

	class_status = Label.new()
	class_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	class_status.add_theme_color_override("font_color", Color("#d8e5fa"))
	content.add_child(class_status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	class_grid = GridContainer.new()
	class_grid.columns = 3
	class_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	class_grid.add_theme_constant_override("h_separation", 8)
	class_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(class_grid)
	for i in range(CLASSES.size()):
		var data: Dictionary = CLASSES[i]
		var button := Button.new()
		button.text = str(data.ar) + "\n" + str(data.tag)
		button.custom_minimum_size = Vector2(0, 54)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(_select_class.bind(i))
		class_grid.add_child(button)

	enter_button = Button.new()
	enter_button.text = "ابدأ رحلتك"
	enter_button.custom_minimum_size = Vector2(0, 54)
	enter_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enter_button.add_theme_font_size_override("font_size", 22)
	var enter_style := StyleBoxFlat.new()
	enter_style.bg_color = Color("#9b641d")
	enter_style.border_color = Color("#ffe6a0")
	enter_style.set_border_width_all(2)
	enter_style.set_corner_radius_all(12)
	enter_button.add_theme_stylebox_override("normal", enter_style)
	enter_button.pressed.connect(_request_world_entry)
	content.add_child(enter_button)

	var footer := Label.new()
	footer.text = "مغامرة فردية • عالم مفتوح • تقدّم محفوظ على جهازك"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_color_override("font_color", Color("#9aaecb"))
	footer.add_theme_font_size_override("font_size", 12)
	root.add_child(footer)
	_select_class(0)


func _build_cinematic_intro() -> void:
	intro_overlay = Control.new()
	intro_overlay.name = "CinematicIntroOverlay"
	intro_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(intro_overlay)

	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.012, 0.018, 0.045, 0.88)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_overlay.add_child(veil)

	var center := VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.anchor_left = 0.12
	center.anchor_top = 0.25
	center.anchor_right = 0.88
	center.anchor_bottom = 0.75
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 16)
	intro_overlay.add_child(center)

	var crest := Label.new()
	crest.text = "✦     ⚔     ✦"
	crest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crest.add_theme_font_size_override("font_size", 38)
	crest.add_theme_color_override("font_color", Color("#f7d98e"))
	center.add_child(crest)

	var cinematic_title := Label.new()
	cinematic_title.text = "صِـــراعُ الأَساطِير"
	cinematic_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cinematic_title.add_theme_font_size_override("font_size", 48)
	cinematic_title.add_theme_color_override("font_color", Color("#ffe6a6"))
	cinematic_title.add_theme_color_override("font_shadow_color", Color(0.95, 0.55, 0.12, 0.9))
	cinematic_title.add_theme_constant_override("shadow_offset_x", 0)
	cinematic_title.add_theme_constant_override("shadow_offset_y", 3)
	cinematic_title.add_theme_constant_override("shadow_outline_size", 8)
	cinematic_title.pivot_offset = Vector2(240, 35)
	cinematic_title.scale = Vector2(0.72, 0.72)
	center.add_child(cinematic_title)

	var cinematic_subtitle := Label.new()
	cinematic_subtitle.text = "حينَ تَستَيقِظُ الأَساطِير… يُولَدُ البَطَل"
	cinematic_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cinematic_subtitle.add_theme_font_size_override("font_size", 19)
	cinematic_subtitle.add_theme_color_override("font_color", Color("#d9e5fa"))
	center.add_child(cinematic_subtitle)

	var skip := Button.new()
	skip.text = "ادخل إلى عالم الأساطير"
	skip.custom_minimum_size = Vector2(260, 52)
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skip.add_theme_font_size_override("font_size", 20)
	skip.pressed.connect(_finish_cinematic_intro)
	center.add_child(skip)

	intro_tween = create_tween()
	intro_tween.set_parallel(true)
	intro_tween.tween_property(cinematic_title, "scale", Vector2.ONE, 0.95).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro_tween.tween_property(crest, "modulate:a", 1.0, 0.7).from(0.0)
	intro_tween.set_parallel(false)
	intro_tween.tween_interval(2.1)
	intro_tween.tween_property(intro_overlay, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	intro_tween.tween_callback(_remove_cinematic_intro)

func _finish_cinematic_intro() -> void:
	if intro_finished:
		return
	if is_instance_valid(intro_tween):
		intro_tween.kill()
	intro_tween = create_tween()
	intro_tween.tween_property(intro_overlay, "modulate:a", 0.0, 0.25)
	intro_tween.tween_callback(_remove_cinematic_intro)

func _remove_cinematic_intro() -> void:
	if intro_finished:
		return
	intro_finished = true
	if is_instance_valid(intro_overlay):
		intro_overlay.queue_free()
	intro_overlay = null


func _select_class(index: int) -> void:
	selected_class = clampi(index, 0, CLASSES.size() - 1)
	var data: Dictionary = CLASSES[selected_class]
	if class_status:
		class_status.text = "الفئة المختارة: %s  —  %s" % [data.ar, data.tag]


func _request_world_entry() -> void:
	if download_running:
		return
	var manager := get_node_or_null("/root/ResourcePackManager")
	if manager == null:
		_enter_world()
		return
	if manager.packages.is_empty():
		await manager.refresh_manifest()
	if manager.get_missing_package_count() <= 0:
		_enter_world()
		return
	_show_unified_download_prompt()

func _show_unified_download_prompt() -> void:
	if is_instance_valid(download_overlay):
		return
	var manager := get_node("/root/ResourcePackManager")
	download_overlay = Control.new()
	download_overlay.name = "UnifiedResourceDownload"
	download_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	download_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(download_overlay)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.02, 0.045, 0.94)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	download_overlay.add_child(shade)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.07
	panel.anchor_top = 0.30
	panel.anchor_right = 0.93
	panel.anchor_bottom = 0.70
	panel.offset_left = 0
	panel.offset_top = 0
	panel.offset_right = 0
	panel.offset_bottom = 0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#101a31")
	panel_style.border_color = Color("#d4aa62")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(18)
	panel_style.content_margin_left = 22
	panel_style.content_margin_right = 22
	panel_style.content_margin_top = 22
	panel_style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", panel_style)
	download_overlay.add_child(panel)

	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 14)
	panel.add_child(layout)

	var heading := Label.new()
	heading.text = "بوابةُ العالَمِ الأَسطوريّ"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 27)
	heading.add_theme_color_override("font_color", Color("#ffe2a0"))
	layout.add_child(heading)

	var explanation := Label.new()
	explanation.text = "يلزم تنزيل موارد العالم كاملةً مرةً واحدة قبل بدء المغامرة"
	explanation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.add_theme_font_size_override("font_size", 15)
	explanation.add_theme_color_override("font_color", Color("#d4def0"))
	layout.add_child(explanation)

	download_status_label = Label.new()
	download_status_label.text = "جاهز لتنزيل %d حزمة موارد" % manager.get_missing_package_count()
	download_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	download_status_label.add_theme_color_override("font_color", Color("#f0d08b"))
	layout.add_child(download_status_label)

	download_progress_bar = ProgressBar.new()
	download_progress_bar.min_value = 0
	download_progress_bar.max_value = 100
	download_progress_bar.value = 0
	download_progress_bar.show_percentage = false
	download_progress_bar.custom_minimum_size = Vector2(0, 24)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#263653")
	track.set_corner_radius_all(12)
	download_progress_bar.add_theme_stylebox_override("background", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#d6a64d")
	fill.set_corner_radius_all(12)
	download_progress_bar.add_theme_stylebox_override("fill", fill)
	layout.add_child(download_progress_bar)

	download_detail_label = Label.new()
	download_detail_label.text = "سيتم التحقق من كل ملف قبل تثبيته"
	download_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	download_detail_label.add_theme_font_size_override("font_size", 13)
	download_detail_label.add_theme_color_override("font_color", Color("#aebed8"))
	layout.add_child(download_detail_label)

	download_start_button = Button.new()
	download_start_button.text = "ابدأ تنزيل موارد العالم"
	download_start_button.custom_minimum_size = Vector2(0, 52)
	download_start_button.add_theme_font_size_override("font_size", 19)
	download_start_button.pressed.connect(_start_unified_download)
	layout.add_child(download_start_button)

	var cancel := Button.new()
	cancel.text = "العودة"
	cancel.custom_minimum_size = Vector2(0, 40)
	cancel.pressed.connect(func(): download_overlay.queue_free(); download_overlay = null)
	layout.add_child(cancel)

	manager.aggregate_progress.connect(_on_aggregate_download_progress)
	_on_aggregate_download_progress(0, manager.get_total_package_bytes() - _get_bundled_bytes(manager), manager.packages.size() - manager.get_missing_package_count(), manager.packages.size(), 0)

func _get_bundled_bytes(manager: Node) -> int:
	var total := 0
	for package_id in manager.packages.keys():
		if manager.is_package_installed(str(package_id)):
			var path := "res://bundled/" + str(manager.packages[package_id].file_name)
			if FileAccess.file_exists(path):
				total += int(manager.packages[package_id].size_bytes)
	return total

func _on_aggregate_download_progress(received: int, total: int, completed: int, count: int, active: int) -> void:
	if not is_instance_valid(download_progress_bar):
		return
	var ratio := 0.0 if total <= 0 else clampf(float(received) / float(total), 0.0, 1.0)
	download_progress_bar.value = ratio * 100.0
	download_status_label.text = "اكتمل %d من %d حزمة" % [completed, count]
	download_detail_label.text = "%s / %s  •  %d تنزيلات متزامنة" % [_format_bytes(received), _format_bytes(total), active]

func _format_bytes(value: int) -> String:
	if value >= 1073741824:
		return "%.2f GB" % (float(value) / 1073741824.0)
	return "%.1f MB" % (float(value) / 1048576.0)

func _start_unified_download() -> void:
	if download_running:
		return
	download_running = true
	download_start_button.disabled = true
	download_start_button.text = "جارٍ تنزيل موارد العالم…"
	download_status_label.text = "يتم تنزيل جميع الموارد والتحقق منها"
	var manager := get_node("/root/ResourcePackManager")
	var success: bool = await manager.download_all_packages()
	download_running = false
	if success and manager.get_missing_package_count() == 0:
		download_done = true
		download_status_label.text = "اكتملت جميع الموارد بنجاح"
		download_detail_label.text = "تم التحقق من الملفات كاملةً — عالم الأساطير جاهز"
		download_start_button.text = "ادخل إلى عالم الأساطير"
		download_start_button.disabled = false
		for connection in manager.aggregate_progress.get_connections():
			if connection.callable.get_method() == "_on_aggregate_download_progress":
				manager.aggregate_progress.disconnect(connection.callable)
		download_start_button.pressed.disconnect(_start_unified_download)
		download_start_button.pressed.connect(_enter_world)
	else:
		download_status_label.text = "لم تكتمل كل الموارد — لم يتم اعتماد الملفات الناقصة"
		download_detail_label.text = "تحقق من الاتصال ثم اضغط إعادة المحاولة؛ الملفات السليمة محفوظة"
		download_start_button.text = "إعادة محاولة التنزيل"
		download_start_button.disabled = false

func _enter_world() -> void:
	if is_instance_valid(download_overlay):
		download_overlay.queue_free()
	GameManager.set("selected_class", str(CLASSES[selected_class].en))
	get_tree().change_scene_to_file(GAME_SCENE)

func _start_music() -> void:
	if not ResourceLoader.exists(MUSIC_PATH):
		return
	var stream := load(MUSIC_PATH)
	if stream == null:
		return
	music_player = AudioStreamPlayer.new()
	music_player.stream = stream
	music_player.volume_db = -12.0
	music_player.bus = "Master"
	add_child(music_player)
	music_player.play()
