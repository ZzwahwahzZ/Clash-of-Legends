extends Control
class_name NewPlayerGuide

@onready var panel: Panel = get_node_or_null("Panel")
@onready var title_label: Label = get_node_or_null("Panel/Title")
@onready var step_label: Label = get_node_or_null("Panel/Step")
@onready var body_label: Label = get_node_or_null("Panel/Body")
@onready var next_button: Button = get_node_or_null("Panel/Next")
@onready var skip_button: Button = get_node_or_null("Panel/Skip")
@onready var close_button: Button = get_node_or_null("Panel/Close")

var step_index := 0
var completed := false
var steps: Array[Dictionary] = [
	{"title_ar":"أهلاً بك في صراع الأساطير","title_en":"Welcome to Clash of Legends","body_ar":"دي مغامرتك. تقدر تختار واحدة من 11 فئة من الإعدادات، وكل فئة لها أسلحتها ومهاراتها وطريقة لعبها.","body_en":"Your adventure starts here. Choose one of 11 classes in Settings; each class has its own weapons, skills and play style."},
	{"title_ar":"الحركة والكاميرا","title_en":"Movement and Camera","body_ar":"استخدم عصا الحركة الافتراضية أسفل الشاشة للتحرك. اسحب على مساحة العالم لتدوير الكاميرا، واستخدم التحكم المتاح لتقريب المشهد وإبعاده.","body_en":"Use the virtual joystick at the bottom of the screen to move. Drag across the world to rotate the camera and use the camera controls to zoom."},
	{"title_ar":"القتال والمهارات","title_en":"Combat and Skills","body_ar":"اضغط زر الهجوم لاستهداف الوحوش القريبة، واستخدم أزرار المهارات للهجمات الخاصة. راقب نقاط الصحة والمانا قبل مواجهة الزعماء.","body_en":"Use the attack button against nearby enemies and the skill buttons for special attacks. Watch your HP and MP before boss fights."},
	{"title_ar":"المهام والشخصيات","title_en":"Quests and NPCs","body_ar":"تابع عنوان المهمة ووصفها أعلى الشاشة. اقترب من الشخصيات غير اللاعبة وتفاعل معها؛ بعض المهام تطلب قتل وحوش أو جمع مواد أو الوصول لمستوى معين.","body_en":"Track the quest title and description at the top of the screen. Talk to NPCs; quests may ask you to defeat monsters, collect materials or reach a level."},
	{"title_ar":"الغنائم والمخزون","title_en":"Loot and Inventory","body_ar":"التقط الغنائم بعد المعارك وافتح المخزون لمراجعة الأسلحة والدروع والمواد. نظام الالتقاط التلقائي يسمح لك بتحديد أنواع الغنائم التي تريدها.","body_en":"Collect loot after battles and open your inventory to manage weapons, armor and materials. Auto-loot lets you filter which drops to collect."},
	{"title_ar":"تطوير العتاد","title_en":"Gear Progression","body_ar":"من الحداد تقدر تصقل العتاد حتى +12، وتفتح فتحات الجواهر، وتستخدم الكمال والبركة والتعويذة والتطهير والأنِيما. كل تطوير يحتاج مواده وذهبه.","body_en":"At the Blacksmith, refine gear up to +12, socket gems and use Perfection, Blessing, Enchant, Purification and Anima. Each upgrade requires its own materials and Gold."},
	{"title_ar":"التنقل والصيد التلقائي","title_en":"Navigation and Auto-Hunt","body_ar":"استخدم توجيه المهمة للوصول إلى الهدف، وشغّل الصيد التلقائي عند الاستعداد. راجع إعدادات الالتقاط حتى لا تمتلئ الحقيبة بأشياء لا تحتاجها.","body_en":"Use quest navigation to reach objectives and enable Auto-Hunt when ready. Configure loot filters so your inventory does not fill with unwanted drops."},
	{"title_ar":"تنزيل موارد العالم واللعب دون اتصال","title_en":"Download World Resources and Play Offline","body_ar":"افتح الإعدادات ثم تنزيل موارد اللعبة. نزّل الحزم على Wi‑Fi، ويفضل تنزيلها كلها حتى تظهر الشخصيات والوحوش والخرائط والحركات والأصوات. بعد التحقق والتثبيت تقدر تلعب دون اتصال.","body_en":"Open Settings, then Download Game Resources. Download the packs over Wi‑Fi; downloading all packs enables the full character, monster, map, animation and audio library. After verification and installation, you can play offline."}
]

func _ready() -> void:
	add_to_group("new_player_guide")
	visible = false
	if next_button:
		next_button.pressed.connect(_on_next_pressed)
	if skip_button:
		skip_button.pressed.connect(_on_skip_pressed)
	if close_button:
		close_button.pressed.connect(close_guide)
	if GameManager:
		GameManager.language_changed.connect(_on_language_changed)
	var config := ConfigFile.new()
	if config.load("user://player_guide.cfg") == OK:
		completed = bool(config.get_value("guide", "completed", false))
	if not completed:
		call_deferred("open_guide")

func open_guide() -> void:
	step_index = 0
	visible = true
	_update_step()

func close_guide() -> void:
	visible = false

func _is_ar() -> bool:
	return GameManager == null or GameManager.current_language == "ar"

func _update_step() -> void:
	if steps.is_empty():
		return
	var step: Dictionary = steps[step_index]
	var is_ar := _is_ar()
	if title_label:
		title_label.text = str(step.get("title_ar", "")) if is_ar else str(step.get("title_en", ""))
	if step_label:
		step_label.text = ("الخطوة %d من %d" if is_ar else "Step %d of %d") % [step_index + 1, steps.size()]
	if body_label:
		body_label.text = str(step.get("body_ar", "")) if is_ar else str(step.get("body_en", ""))
	if next_button:
		next_button.text = ("ابدأ اللعب" if is_ar else "Start Playing") if step_index == steps.size() - 1 else ("التالي" if is_ar else "Next")
	if skip_button:
		skip_button.text = "تخطي الدليل" if is_ar else "Skip Guide"
	if close_button:
		close_button.text = "×"

func _on_next_pressed() -> void:
	if step_index < steps.size() - 1:
		step_index += 1
		_update_step()
	else:
		_mark_completed()

func _on_skip_pressed() -> void:
	_mark_completed()

func _mark_completed() -> void:
	completed = true
	var config := ConfigFile.new()
	config.set_value("guide", "completed", true)
	config.save("user://player_guide.cfg")
	visible = false

func _on_language_changed(_language: String) -> void:
	if visible:
		_update_step()
