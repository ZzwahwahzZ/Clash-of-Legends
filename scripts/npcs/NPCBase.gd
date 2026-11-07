extends CharacterBody3D
class_name NPCBase

@export var npc_name_ar: String = "الحكيم القديم"
@export var npc_name_en: String = "Ancient Sage"
@export var npc_id: String = "npc_sage"
@export var source_dialogue_id: int = 0
@export var role: String = "sage" # "sage", "blacksmith", "merchant", "warden"
@export var required_level: int = 1

var dialogue_lines_ar: Array[String] = [
	"مرحباً بك يا بطل في مدينة التوأم. أرض الأساطير بانتظار شجاعتك!",
	"الذئاب في السهول أصبحت شرسة للغاية، القوافل بحاجة إلى مساعدتك.",
	"التنين العظيم يتربص في القمم الجبلية.. لا تواجهه دون عتاد مصقول!"
]

var dialogue_lines_en: Array[String] = [
	"Welcome Hero to Twin City. The land of legends awaits your courage!",
	"Wolves in the plains have grown fierce; trade caravans need your aid.",
	"The great dragon rests in mountain summits.. do not challenge it unprepared!"
]

@onready var label: Label3D = get_node_or_null("Label3D")
@onready var interaction_area: Area3D = get_node_or_null("InteractionArea")

func _ready() -> void:
	add_to_group("npcs")
	_update_title()
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_area_entered)
		interaction_area.body_exited.connect(_on_interaction_area_exited)

func _update_title() -> void:
	if label:
		var n = npc_name_ar if (GameManager and GameManager.current_language == "ar") else npc_name_en
		label.text = "[%s]" % n

func _on_interaction_area_entered(body: Node3D) -> void:
	if body is PlayerController and GameManager:
		GameManager.set_nearby_npc(self)

func _on_interaction_area_exited(body: Node3D) -> void:
	if body is PlayerController and GameManager:
		GameManager.clear_nearby_npc(self)

func interact(player: CharacterBody3D) -> void:
	if not is_instance_valid(player):
		return
	if player.current_level < required_level:
		var msg := ("يتطلب التحدث معي المستوى %d!" % required_level) if GameManager.current_language == "ar" else ("You need level %d to interact." % required_level)
		if GameManager:
			GameManager.post_notification(msg, true)
		return

	if GameAudioManager:
		GameAudioManager.play_sfx("npc_talk", self, -10.0)
	for agent in get_tree().get_nodes_in_group("quest_agents"):
		if agent.has_method("on_npc_talked"):
			agent.on_npc_talked(npc_id)
	match role:
		"sage":
			_open_dialogue()
		"blacksmith":
			_open_blacksmith()
		"merchant":
			_open_merchant()
		"warden":
			_open_dialogue()

func _open_dialogue() -> void:
	var tree = get_tree()
	if not tree:
		return
	var dlg = tree.get_first_node_in_group("dialogue_ui")
	if dlg and dlg.has_method("show_dialogue"):
		var is_ar := GameManager and GameManager.current_language == "ar"
		var name_str = npc_name_ar if is_ar else npc_name_en
		var locale := "ar" if is_ar else "en"
		if source_dialogue_id > 0 and dlg.has_method("show_source_dialogue"):
			if dlg.show_source_dialogue(source_dialogue_id, name_str, locale):
				return
		var lines = dialogue_lines_ar if is_ar else dialogue_lines_en
		dlg.show_dialogue(name_str, lines[0], ["حسناً، فهمت", "سأبذل جهدي"])

func _open_blacksmith() -> void:
	var tree = get_tree()
	if not tree:
		return
	var b_ui = tree.get_first_node_in_group("blacksmith_ui")
	if b_ui and b_ui.has_method("open_ui"):
		b_ui.open_ui()

func _open_merchant() -> void:
	var tree = get_tree()
	if not tree:
		return
	var inv_ui = tree.get_first_node_in_group("inventory_ui")
	if inv_ui and inv_ui.has_method("open_ui"):
		inv_ui.open_ui()
	if GameManager:
		var txt = "فتح متجر التاجر: بيع المواد الفائضة للحصول على الذهب" if GameManager.current_language == "ar" else "Merchant Shop: Sell items for gold"
		GameManager.post_notification(txt, false)
