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
var splash_progress_bar: ProgressBar
var splash_loading := false
var download_running := false
var download_done := false
var last_download_failure := ""

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

	# The same splash owns the resource bar: no dialog, card, labels or extra window.
	splash_progress_bar = ProgressBar.new()
	splash_progress_bar.name = "IntegratedSplashProgress"
	splash_progress_bar.min_value = 0.0
	splash_progress_bar.max_value = 100.0
	splash_progress_bar.value = 0.0
	splash_progress_bar.show_percentage = false
	splash_progress_bar.visible = false
	splash_progress_bar.anchor_left = 0.16
	splash_progress_bar.anchor_right = 0.84
	splash_progress_bar.anchor_top = 0.88
	splash_progress_bar.anchor_bottom = 0.88
	splash_progress_bar.offset_top = -5
	splash_progress_bar.offset_bottom = 5
	splash_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_track := StyleBoxFlat.new()
	bar_track.bg_color = Color(0.035, 0.055, 0.10, 0.82)
	bar_track.set_corner_radius_all(5)
	splash_progress_bar.add_theme_stylebox_override("background", bar_track)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color("#e4b95e")
	bar_fill.set_corner_radius_all(5)
	splash_progress_bar.add_theme_stylebox_override("fill", bar_fill)
	intro_overlay.add_child(splash_progress_bar)

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
	if manager.has_method("wait_for_bootstrap"):
		await manager.wait_for_bootstrap()
	if manager.packages.is_empty():
		await manager.refresh_manifest()
	# Validate the production character catalog before downloading optional packs.
	# The current catalog is expected in the bundled world/model baseline; if it
	# cannot provide verified class models, a large first-run download cannot fix it.
	var missing_classes := _missing_verified_character_classes()
	if not missing_classes.is_empty():
		var detail := "، ".join(PackedStringArray(missing_classes))
		print("WORLD_ENTRY_PREFLIGHT_BLOCKED_BEFORE_DOWNLOAD: " + detail)
		_show_production_content_block(missing_classes)
		return
	if manager.get_missing_package_count() <= 0:
		_enter_world()
		return
	_start_splash_resource_download(manager)


func _show_integrated_loading_splash(manager: Node) -> void:
	if not is_instance_valid(intro_overlay):
		_build_cinematic_intro()
	if is_instance_valid(intro_tween):
		intro_tween.kill()
	intro_overlay.modulate.a = 1.0
	intro_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	# Keep the opening artwork visible, but show only the progress bar over it.
	for child in intro_overlay.get_children():
		if child == splash_progress_bar:
			continue
		child.visible = false
	var veil := intro_overlay.get_child(0) as ColorRect
	if veil:
		veil.visible = true
		veil.color = Color(0.012, 0.018, 0.045, 0.22)
	splash_progress_bar.visible = true
	splash_progress_bar.value = 0.0
	splash_loading = true
	manager.emit_current_progress()


func _start_splash_resource_download(manager: Node) -> void:
	if download_running:
		return
	download_running = true
	last_download_failure = ""
	_show_integrated_loading_splash(manager)
	if not manager.aggregate_progress.is_connected(_on_aggregate_download_progress):
		manager.aggregate_progress.connect(_on_aggregate_download_progress)
	if not manager.package_failed.is_connected(_on_package_download_failed):
		manager.package_failed.connect(_on_package_download_failed)
	var success: bool = await manager.download_all_packages()
	download_running = false
	splash_loading = false
	if success and manager.get_missing_package_count() == 0:
		_enter_world()
		return
	# Keep failure recoverable without leaving a fake completed loading bar.
	if is_instance_valid(intro_overlay):
		intro_overlay.queue_free()
	intro_overlay = null
	if is_instance_valid(splash_progress_bar):
		splash_progress_bar = null
	if class_status:
		class_status.text = "تعذّر اكتمال تحميل الموارد؛ اضغط «ابدأ رحلتك» لإعادة المحاولة"


func _on_package_download_failed(package_id: String, reason: String) -> void:
	last_download_failure = "%s: %s" % [package_id, reason]


func _on_aggregate_download_progress(received: int, total: int, _completed: int, _count: int, _active: int) -> void:
	if not splash_loading or not is_instance_valid(splash_progress_bar):
		return
	var ratio := 0.0 if total <= 0 else clampf(float(received) / float(total), 0.0, 1.0)
	splash_progress_bar.value = ratio * 100.0


func _missing_verified_character_classes() -> Array[String]:
	var missing: Array[String] = []
	if not GameContentDatabase or not AssetCatalog or AssetCatalog.catalog_version <= 0 or AssetCatalog.assets_by_category.is_empty():
		return ["resource catalog unavailable"]
	for class_id in GameContentDatabase.get_selectable_class_ids():
		if AssetCatalog.get_verified_character_model_index(class_id) < 0:
			missing.append(class_id)
	return missing

func _show_production_content_block(missing: Array[String]) -> void:
	if is_instance_valid(intro_overlay):
		intro_overlay.queue_free()
	intro_overlay = null
	splash_progress_bar = null
	if class_status:
		class_status.visible = true
		var detail := "، ".join(PackedStringArray(missing))
		print("WORLD_ENTRY_BLOCKED: missing verified character models: " + detail)
		class_status.text = "لن أبدأ العالم بنماذج مؤقتة. ما زالت نماذج الشخصيات التالية غير موثّقة: %s" % detail

func _enter_world() -> void:
	var missing_classes := _missing_verified_character_classes()
	if not missing_classes.is_empty():
		_show_production_content_block(missing_classes)
		return
	if is_instance_valid(intro_overlay):
		intro_overlay.queue_free()
	intro_overlay = null
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
