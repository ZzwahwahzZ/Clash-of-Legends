extends CharacterBody3D
class_name NPCBase

@export var npc_name_ar: String = "الحكيم القديم"
@export var npc_name_en: String = "Ancient Sage"
@export var npc_id: String = "npc_sage"
@export var role: String = "sage" # "sage", "blacksmith", "merchant", "warden"
@export var required_level: int = 1
@export var source_npc_id: String = ""
@export var source_map_id: String = "1002"

var _source_quest_agent: Node
var _source_quest_callback: Callable

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
		if not source_npc_id.is_empty() and agent.has_method("on_source_npc_talked"):
			agent.on_source_npc_talked(source_npc_id)
	if not source_npc_id.is_empty() and _open_source_quest_dialogue(player):
		return
	match role:
		"sage":
			_open_dialogue()
		"blacksmith":
			_open_blacksmith()
		"merchant":
			_open_merchant()
		"warden", "armorer":
			_open_dialogue()

func _open_source_quest_dialogue(player: CharacterBody3D) -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	var dlg := tree.get_first_node_in_group("dialogue_ui")
	if dlg == null or not dlg.has_method("show_source_quest_offers"):
		return false
	for agent in tree.get_nodes_in_group("quest_agents"):
		if not agent.has_method("get_source_missions_for_npc_interaction"):
			continue
		var class_id := str(player.call("get_character_class")) if player.has_method("get_character_class") else ""
		var offers: Array = agent.get_source_missions_for_npc_interaction(source_npc_id, player.current_level, class_id)
		if offers.is_empty():
			continue
		if not _source_quest_callback.is_null() and dlg.source_quest_selected.is_connected(_source_quest_callback):
			dlg.source_quest_selected.disconnect(_source_quest_callback)
		_source_quest_agent = agent
		_source_quest_callback = Callable(self, "_on_source_quest_selected").bind(agent, source_npc_id, player)
		if not dlg.source_quest_selected.is_connected(_source_quest_callback):
			dlg.source_quest_selected.connect(_source_quest_callback)
		var intro := "المهام المتاحة هنا مرتبطة بسجلات العالم ومتطلبات شخصيتك." if GameManager.current_language == "ar" else "Available quests are checked against the world source and your character requirements."
		dlg.show_source_quest_offers(npc_name_ar if GameManager.current_language == "ar" else npc_name_en, intro, offers, str(agent.active_source_mission_id))
		return true
	return false

func _on_source_quest_selected(mission_id: String, agent: Node, selected_npc_id: String, player: CharacterBody3D) -> void:
	var dlg := get_tree().get_first_node_in_group("dialogue_ui")
	if dlg and not _source_quest_callback.is_null() and dlg.source_quest_selected.is_connected(_source_quest_callback):
		dlg.source_quest_selected.disconnect(_source_quest_callback)
	_source_quest_callback = Callable()
	if not is_instance_valid(agent) or not is_instance_valid(player):
		return
	var class_id := str(player.call("get_character_class")) if player.has_method("get_character_class") else ""
	var success := bool(agent.call("select_source_mission_at_npc", mission_id, selected_npc_id, player.current_level, class_id))
	if not success:
		if GameManager:
			GameManager.post_notification("المهمة غير متاحة بعد أو لم يكتمل هدفها." if GameManager.current_language == "ar" else "This quest is locked or its objectives are not complete.", true)
		return
	var mission: Dictionary = agent.call("get_source_mission", mission_id)
	var is_completed := agent.completed_source_mission_ids.has(mission_id)
	var message := str(mission.get("content_ar", mission.get("intention_description_ar", mission.get("name_ar", "تم تحديث المهمة."))))
	if is_completed:
		message = "تم تسليم المهمة: " + str(mission.get("name_ar", mission_id))
	elif message.is_empty():
		message = "تم قبول المهمة: " + str(mission.get("name_ar", mission_id))
	if GameManager:
		GameManager.post_notification(message, false)

func _open_dialogue() -> void:
	var tree = get_tree()
	if not tree:
		return
	var dlg = tree.get_first_node_in_group("dialogue_ui")
	if dlg and dlg.has_method("show_dialogue"):
		var name_str = npc_name_ar if (GameManager and GameManager.current_language == "ar") else npc_name_en
		var lines = dialogue_lines_ar if (GameManager and GameManager.current_language == "ar") else dialogue_lines_en
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
