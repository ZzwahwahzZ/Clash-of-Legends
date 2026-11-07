extends Control
class_name DialogueUI

signal option_selected(index: int)

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

func show_source_dialogue(dialogue_id: int, speaker: String, locale: String = "ar") -> bool:
	if not is_instance_valid(WorldContentIndex) or not WorldContentIndex.index_ready:
		return false
	var entry: Dictionary = WorldContentIndex.get_npc_dialogue(dialogue_id)
	var talks: Array = entry.get("talks", [])
	if talks.is_empty():
		return false
	var first_talk: Dictionary = talks[0]
	var text_value := str(first_talk.get("text_ar" if locale == "ar" else "text_en", ""))
	if text_value.is_empty():
		text_value = WorldContentIndex.get_dialogue_text(str(first_talk.get("text_key", "")), locale)
	if text_value.is_empty():
		return false
	show_dialogue(speaker, text_value, [])
	return true

func _on_option_clicked(index: int) -> void:
	emit_signal("option_selected", index)
	close_dialogue()

func close_dialogue() -> void:
	visible = false
