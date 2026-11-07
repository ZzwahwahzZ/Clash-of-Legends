extends Control
class_name DialogueUI

signal option_selected(index: int)
signal source_quest_selected(mission_id: String)

@onready var panel: Panel = get_node_or_null("Panel")
@onready var speaker_label: Label = get_node_or_null("Panel/SpeakerLabel")
@onready var dialogue_label: Label = get_node_or_null("Panel/DialogueLabel")
@onready var options_vbox: VBoxContainer = get_node_or_null("Panel/OptionsVBox")
@onready var close_button: Button = get_node_or_null("Panel/CloseButton")

func _ready() -> void:
	add_to_group("dialogue_ui")
	visible = false
	if close_button:
		close_button.pressed.connect(close_dialogue)

func show_dialogue(speaker: String, text: String, options: Array = []) -> void:
	FeatureGuidanceManager.show_feature_intro("dialogue")
	visible = true
	if speaker_label:
		speaker_label.text = speaker
	if dialogue_label:
		dialogue_label.text = text
		
	if options_vbox:
		for child in options_vbox.get_children():
			child.queue_free()
			
		for i in range(options.size()):
			var btn = Button.new()
			btn.text = options[i]
			btn.pressed.connect(_on_option_clicked.bind(i))
			options_vbox.add_child(btn)

func show_source_quest_offers(speaker: String, intro: String, offers: Array, active_mission_id: String = "", service_id: String = "") -> void:
	FeatureGuidanceManager.show_feature_intro("dialogue")
	visible = true
	if speaker_label:
		speaker_label.text = speaker
	if dialogue_label:
		dialogue_label.text = intro
	if options_vbox:
		for child in options_vbox.get_children():
			child.queue_free()
		for offer in offers:
			if not offer is Dictionary:
				continue
			var mission_id := str(offer.get("id", ""))
			if mission_id.is_empty():
				continue
			var title := str(offer.get("name_ar", offer.get("name", mission_id)))
			var is_turnin := mission_id == active_mission_id and str(offer.get("runtime_state", "")) == "READY_TO_TURN_IN"
			var button := Button.new()
			button.text = ("استلام مكافأة: " if is_turnin else "مهمة: ") + title
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.pressed.connect(_on_source_quest_clicked.bind(mission_id))
			options_vbox.add_child(button)
		if not service_id.is_empty():
			var service_button := Button.new()
			service_button.text = "فتح ورشة الحدادة" if service_id == "blacksmith" else "Open Blacksmith"
			service_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			service_button.pressed.connect(_on_source_quest_clicked.bind("service:" + service_id))
			options_vbox.add_child(service_button)

func _on_source_quest_clicked(mission_id: String) -> void:
	source_quest_selected.emit(mission_id)
	close_dialogue()

func _on_option_clicked(index: int) -> void:
	emit_signal("option_selected", index)
	close_dialogue()

func close_dialogue() -> void:
	visible = false
