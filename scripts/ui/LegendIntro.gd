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

func _ready() -> void:
	_build_screen()
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
	enter_button.pressed.connect(_enter_world)
	content.add_child(enter_button)

	var footer := Label.new()
	footer.text = "مغامرة فردية • عالم مفتوح • تقدّم محفوظ على جهازك"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_color_override("font_color", Color("#9aaecb"))
	footer.add_theme_font_size_override("font_size", 12)
	root.add_child(footer)
	_select_class(0)

func _select_class(index: int) -> void:
	selected_class = clampi(index, 0, CLASSES.size() - 1)
	var data: Dictionary = CLASSES[selected_class]
	if class_status:
		class_status.text = "الفئة المختارة: %s  —  %s" % [data.ar, data.tag]

func _enter_world() -> void:
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
