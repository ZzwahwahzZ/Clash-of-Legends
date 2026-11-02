extends Node

const SAVE_PATH: String = "user://clash_save_data.json"
const BACKUP_PATH: String = "user://clash_save_data.bak"
const SETTINGS_PATH: String = "user://clash_settings.json"

signal save_completed(success: bool)
signal load_completed(success: bool)

func _ready() -> void:
	pass

# Quest agents are saved by stable scene-node name so each local agent can
# restore its own progression without a server or a hard-coded scene path.
func capture_quest_states() -> Dictionary:
	var states: Dictionary = {}
	if not is_inside_tree():
		return states
	for agent in get_tree().get_nodes_in_group("quest_agents"):
		if is_instance_valid(agent) and agent.has_method("serialize"):
			states[str(agent.name)] = agent.serialize()
	return states

func restore_quest_states(states: Dictionary) -> int:
	if not is_inside_tree() or states.is_empty():
		return 0
	var restored := 0
	for agent in get_tree().get_nodes_in_group("quest_agents"):
		if not is_instance_valid(agent) or not agent.has_method("deserialize"):
			continue
		var key := str(agent.name)
		if states.has(key) and typeof(states[key]) == TYPE_DICTIONARY:
			agent.deserialize(states[key])
			restored += 1
	return restored

func save_game(player_data: Dictionary) -> bool:
	var payload = {
		"version": "1.0.0",
		"timestamp": Time.get_unix_time_from_system(),
		"player": player_data
	}
	
	var json_str = JSON.stringify(payload, "\t")
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("Failed to open save file for writing: " + SAVE_PATH)
		emit_signal("save_completed", false)
		return false
		
	file.store_string(json_str)
	file.close()
	
	# Create backup copy
	var backup_file = FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
	if backup_file:
		backup_file.store_string(json_str)
		backup_file.close()
		
	emit_signal("save_completed", true)
	if GameManager:
		GameManager.post_notification("تم حفظ بيانات اللعبة محلياً بنجاح" if GameManager.current_language == "ar" else "Game data saved locally", false)
	return true

func load_game() -> Dictionary:
	var target_path = SAVE_PATH
	if not FileAccess.file_exists(target_path):
		if FileAccess.file_exists(BACKUP_PATH):
			target_path = BACKUP_PATH
		else:
			return {}
			
	var file = FileAccess.open(target_path, FileAccess.READ)
	if not file:
		emit_signal("load_completed", false)
		return {}
		
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(content)
	if error != OK:
		push_error("JSON Parse Error on load: " + json.get_error_message())
		# Try fallback to backup
		if target_path != BACKUP_PATH and FileAccess.file_exists(BACKUP_PATH):
			return _load_backup_fallback()
		emit_signal("load_completed", false)
		return {}
		
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY and data.has("player"):
		emit_signal("load_completed", true)
		if GameManager:
			GameManager.post_notification("تم استرجاع تقدمك في اللعبة" if GameManager.current_language == "ar" else "Game progress loaded successfully", false)
		return data["player"]
		
	emit_signal("load_completed", false)
	return {}

func _load_backup_fallback() -> Dictionary:
	var file = FileAccess.open(BACKUP_PATH, FileAccess.READ)
	if not file:
		return {}
	var content = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(content) == OK and typeof(json.get_data()) == TYPE_DICTIONARY:
		return json.get_data().get("player", {})
	return {}

func save_settings(settings: Dictionary) -> bool:
	var json_str = JSON.stringify(settings, "\t")
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if not file:
		return false
	file.store_string(json_str)
	file.close()
	return true

func load_settings() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return {"language": "ar", "audio_volume": 1.0, "sfx_volume": 1.0, "camera_zoom": 1.0}
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not file:
		return {"language": "ar"}
	var content = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(content) == OK and typeof(json.get_data()) == TYPE_DICTIONARY:
		return json.get_data()
	return {"language": "ar"}
