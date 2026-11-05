extends Node

const SAVE_PATH := "user://feature_guidance.cfg"
const GUIDES := {
	"inventory": {"title":"الحقيبة","body":"هنا تحتفظ بأسلحتك ودروعك وموادك وجرعاتك. اضغط على أي غرض لعرض تفاصيله، ثم اختر الإجراء المناسب مثل الاستخدام أو الارتداء أو النقل. انتبه إلى عدد الخانات والوزن إن كان النظام يطبّقه."},
	"blacksmith": {"title":"الحداد والتطوير","body":"تستخدم هذه الواجهة لتطوير المعدات أو إصلاحها أو تطبيق أنظمة التحسين المتاحة. اقرأ متطلبات العملية والمواد المطلوبة والتكلفة قبل التأكيد؛ بعض العمليات قد تستهلك مواد أو تغيّر خصائص القطعة."},
	"settings": {"title":"الإعدادات والحفظ","body":"من هنا تغيّر اللغة وتضبط خيارات اللعب وتحفظ تقدمك على هذا الجهاز. استخدم الحفظ قبل إغلاق اللعبة، ويمكنك استرجاع آخر تقدم محفوظ."},
	"quest": {"title":"المهام","body":"اقرأ وصف المهمة وأهدافها ومكافآتها. اتبع علامة الهدف أو استخدم التوجيه للوصول إلى المكان المطلوب. بعد إكمال جميع الأهداف ارجع إلى الشخصية التي أعطتك المهمة لاستلام المكافأة."},
	"auto_hunt": {"title":"الصيد التلقائي","body":"يساعدك على مهاجمة الأعداء القريبين وفق إعدادات الصيد. راجع مستوى الأعداء ومدى قدرتك على مواجهتهم، وأوقف الصيد إذا أردت التحكم اليدوي."},
	"auto_loot": {"title":"جمع الغنائم تلقائيًا","body":"عند تفعيل هذه الميزة تحاول الشخصية جمع الغنائم المتاحة حولها. راجع مساحة الحقيبة وإعدادات التصفية حتى لا تمتلئ بأغراض لا تحتاجها."},
	"interact": {"title":"التفاعل مع الشخصيات","body":"اقترب من الشخصية غير اللاعبة ثم اضغط تفاعل لفتح الحوار. اقرأ الخيارات؛ فقد تقدم الشخصية مهمة أو خدمة أو متجرًا أو انتقالًا إلى منطقة أخرى."},
	"dialogue": {"title":"حوارات الشخصيات","body":"اقرأ كلام الشخصية والاختيارات المتاحة قبل الضغط. قد يبدأ الاختيار مهمة أو يسلّمها أو يفتح متجرًا أو خدمة. يمكنك إغلاق الحوار والعودة إليه ما دامت الشخصية قريبة."},
	"mount": {"title":"الركوب","body":"اضغط زر الحصان للركوب أو الترجل. قد تختلف سرعة الحركة أو بعض إمكانيات القتال أثناء الركوب بحسب قواعد اللعبة."},
	"skills": {"title":"المهارات","body":"تستهلك بعض المهارات نقاطًا سحرية ولها مدى ووقت انتظار. اختر هدفًا مناسبًا وتأكد من توافق المهارة مع فئتك وسلاحك قبل استخدامها."}
}

var seen: Dictionary = {}
var dialog: AcceptDialog

func _ready() -> void:
	_load_seen()
	get_tree().node_added.connect(_on_node_added)
	_apply_rtl_tree(get_tree().root)

func _on_node_added(node: Node) -> void:
	if node is Control:
		_apply_rtl_control(node)

func _apply_rtl_tree(node: Node) -> void:
	if node is Control:
		_apply_rtl_control(node)
	for child in node.get_children():
		_apply_rtl_tree(child)

func _apply_rtl_control(control: Control) -> void:
	control.layout_direction = Control.LAYOUT_DIRECTION_RTL
	control.text_direction = Control.TEXT_DIRECTION_RTL

func show_feature_intro(feature_id: String) -> bool:
	if seen.get(feature_id, false):
		return false
	if not GUIDES.has(feature_id):
		push_warning("Missing first-use guide: " + feature_id)
		return false
	var guide: Dictionary = GUIDES[feature_id]
	if is_instance_valid(dialog):
		dialog.queue_free()
	dialog = AcceptDialog.new()
	dialog.title = str(guide["title"])
	dialog.dialog_text = str(guide["body"])
	dialog.ok_button_text = "فهمت"
	dialog.min_size = Vector2i(460, 220)
	_apply_rtl_tree(dialog)
	get_tree().root.add_child(dialog)
	dialog.confirmed.connect(func(): _mark_seen(feature_id))
	dialog.close_requested.connect(func(): _mark_seen(feature_id))
	dialog.popup_centered()
	return true

func _mark_seen(feature_id: String) -> void:
	seen[feature_id] = true
	_save_seen()

func _load_seen() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		seen = config.get_value("guidance", "seen", {})

func _save_seen() -> void:
	var config := ConfigFile.new()
	config.set_value("guidance", "seen", seen)
	var err := config.save(SAVE_PATH)
	if err != OK:
		push_warning("Could not save feature guidance state: " + str(err))
