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

func _on_option_clicked(index: int) -> void:
	emit_signal("option_selected", index)
	close_dialogue()

func close_dialogue() -> void:
	visible = false
