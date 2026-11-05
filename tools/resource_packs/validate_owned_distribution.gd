extends SceneTree

func _initialize() -> void:
	var pack_path := "res://build/public-pcks/owned-core.pck"
	if not FileAccess.file_exists(pack_path):
		_fail("Owned PCK was not created.")
		return
	var file := FileAccess.open(pack_path, FileAccess.READ)
	if file == null or file.get_length() < 64:
		_fail("Owned PCK is empty or unreadable.")
		return
	file.close()
	var pack_bytes := FileAccess.get_file_as_bytes(pack_path)
	if pack_bytes.find("assets/shaders/weapon_glow.gdshader".to_utf8_buffer()) < 0:
		_fail("The PCK index does not contain the allowlisted shader path.")
		return
	if not ProjectSettings.load_resource_pack(pack_path, true):
		_fail("Godot could not mount the owned PCK.")
		return
	var shader := ResourceLoader.load("res://assets/shaders/weapon_glow.gdshader") as Shader
	if shader == null:
		_fail("Allowlisted shader did not load after mounting the PCK.")
		return
	if not shader.code.contains("EMISSION") or not shader.code.contains("pulse_speed"):
		_fail("Allowlisted shader content failed integrity checks.")
		return
	print("OWNED RESOURCE DISTRIBUTION VALIDATED: mounted PCK and loaded allowlisted original shader.")
	quit(0)

func _fail(message: String) -> void:
	push_error("OWNED RESOURCE DISTRIBUTION FAILED: " + message)
	quit(1)
