extends Control
class_name DialogueUI

signal option_selected(index: int)

@onready var panel: Panel = get_node_or_null("Panel")
@onready var speaker_label: Label = get_node_or_null("Panel/SpeakerLabel")
@onready var dialogue_label: Label = get_node_or_null("Panel/DialogueLabel")
@onready var options_vbox: VBoxContainer = get_node_or_null("Panel/OptionsVBox")
@onready var close_button: Button = get_node_or_null("Panel/CloseButton")

var _source_dialogue_speaker := ""
var _source_dialogue_locale := "ar"
var _source_talks: Array = []
var _source_step_index := 0

func _ready() -> void:
	add_to_group("dialogue_ui")
	visible = false
	if close_button:
		close_button.pressed.connect(close_dialogue)

func _clear_options() -> void:
	if not options_vbox:
		return
	for child in options_vbox.get_children():
		child.queue_free()

func show_dialogue(speaker: String, text: String, options: Array = []) -> void:
	_source_talks.clear()
	_source_step_index = 0
	FeatureGuidanceManager.show_feature_intro("dialogue")
	visible = true
	if speaker_label:
		speaker_label.text = speaker
	if dialogue_label:
		dialogue_label.text = text
	_clear_options()
	if options_vbox:
		for i in range(options.size()):
			var btn := Button.new()
			btn.text = str(options[i])
			btn.pressed.connect(_on_option_clicked.bind(i))
			options_vbox.add_child(btn)

func show_source_dialogue(dialogue_id: int, speaker: String, locale: String = "ar") -> bool:
	if not is_instance_valid(WorldContentIndex) or not WorldContentIndex.index_ready:
		return false
	var entry: Dictionary = WorldContentIndex.get_npc_dialogue(dialogue_id)
	var talks: Array = entry.get("talks", [])
	if talks.is_empty():
		return false
	_source_dialogue_speaker = speaker
	_source_dialogue_locale = locale
	_source_talks = talks
	_source_step_index = 0
	FeatureGuidanceManager.show_feature_intro("dialogue")
	visible = true
	_render_source_dialogue_step()
	return true

func _render_source_dialogue_step() -> void:
	if _source_step_index < 0 or _source_step_index >= _source_talks.size():
		return
	var talk: Dictionary = _source_talks[_source_step_index]
	if speaker_label:
		speaker_label.text = _source_dialogue_speaker
	var text_key := str(talk.get("text_key", ""))
	var text_value := str(talk.get("text_ar" if _source_dialogue_locale == "ar" else "text_en", ""))
	if text_value.is_empty() and not text_key.is_empty():
		text_value = WorldContentIndex.get_dialogue_text(text_key, _source_dialogue_locale)
	if dialogue_label:
		dialogue_label.text = text_value
	_clear_options()

	var source: Dictionary = talk.get("source", {})
	var source_buttons: Variant = source.get("DlgBtn", {})
	var button_entries: Array = []
	if source_buttons is Dictionary:
		var keys: Array = source_buttons.keys()
		keys.sort()
		for key in keys:
			var item: Variant = source_buttons[key]
			if item is Dictionary:
				button_entries.append(item)

	if not button_entries.is_empty() and options_vbox:
		for item in button_entries:
			var option_key := str(item.get("text", ""))
			var option_text := WorldContentIndex.get_dialogue_text(option_key, _source_dialogue_locale)
			if option_text.is_empty():
				option_text = option_key
			var next_dialogue_id := int(item.get("funcData", 0))
			var option_button := Button.new()
			option_button.text = option_text
			option_button.pressed.connect(_on_source_button_pressed.bind(next_dialogue_id))
			options_vbox.add_child(option_button)
	elif _source_step_index + 1 < _source_talks.size() and options_vbox:
		var next_button := Button.new()
		next_button.text = "التالي" if _source_dialogue_locale == "ar" else "Next"
		next_button.pressed.connect(_advance_source_step)
		options_vbox.add_child(next_button)

func _on_source_button_pressed(next_dialogue_id: int) -> void:
	if next_dialogue_id > 0:
		if show_source_dialogue(next_dialogue_id, _source_dialogue_speaker, _source_dialogue_locale):
			return
	_advance_source_step()

func _advance_source_step() -> void:
	if _source_step_index + 1 < _source_talks.size():
		_source_step_index += 1
		_render_source_dialogue_step()
	else:
		close_dialogue()

func _on_option_clicked(index: int) -> void:
	emit_signal("option_selected", index)
	close_dialogue()

func close_dialogue() -> void:
	_source_talks.clear()
	_source_step_index = 0
	visible = false
