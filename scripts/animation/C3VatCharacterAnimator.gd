extends Node
class_name C3VatCharacterAnimator

const C3VatPlayerScript = preload("res://scripts/animation/C3VatPlayer.gd")

var _model_root: Node3D = null
var _model_id: int = 0
var _mesh_by_name: Dictionary = {}
var _players_by_mesh: Dictionary = {}
var _active_mesh_names: Dictionary = {}
var _current_state: String = ""
var _configured: bool = false

func has_vat_for_model(model_id: int) -> bool:
	return AssetCatalog != null and AssetCatalog.has_character_vat_animation(model_id)

func configure_character(model_root: Node3D, model_id: int) -> bool:
	if model_root == null or not is_instance_valid(model_root):
		push_error("C3 VAT Animator: model root is invalid.")
		return false
	if not has_vat_for_model(model_id):
		push_warning("C3 VAT Animator: no fully validated VAT clip catalog for model %d." % model_id)
		return false
	_reset_all_players()
	_mesh_by_name.clear()
	_players_by_mesh.clear()
	_active_mesh_names.clear()
	for node in model_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() <= 0:
			continue
		if _mesh_by_name.has(mesh_instance.name):
			push_error("C3 VAT Animator: duplicate mesh name makes C3 source binding ambiguous: " + mesh_instance.name)
			return false
		_mesh_by_name[mesh_instance.name] = mesh_instance
	if _mesh_by_name.is_empty():
		push_error("C3 VAT Animator: model has no renderable MeshInstance3D nodes.")
		return false
	for animation_node in model_root.find_children("*", "AnimationPlayer", true, false):
		(animation_node as AnimationPlayer).stop()
	for mesh_value in _mesh_by_name.values():
		var mesh_instance := mesh_value as MeshInstance3D
		if mesh_instance.mesh is ArrayMesh:
			var array_mesh := mesh_instance.mesh as ArrayMesh
			for blend_shape_index in range(array_mesh.get_blend_shape_count()):
				mesh_instance.set_blend_shape_value(blend_shape_index, 0.0)
	_model_root = model_root
	_model_id = model_id
	_configured = true
	if not play_state("idle"):
		_configured = false
		return false
	return true

func play_state(state: String) -> bool:
	if not _configured or _model_root == null or not is_instance_valid(_model_root):
		return false
	var normalized := state.to_lower()
	if normalized == "move":
		normalized = "walk"
	if not ["idle", "walk", "run"].has(normalized):
		push_warning("C3 VAT Animator: unsupported state " + state)
		return false
	var clip: Dictionary = AssetCatalog.get_character_vat_clip(_model_id, normalized)
	var metadata_paths: Array = clip.get("metadata_paths", [])
	if metadata_paths.is_empty():
		push_error("C3 VAT Animator: validated metadata paths are missing for model %d state %s." % [_model_id, normalized])
		return false

	var new_active: Dictionary = {}
	for metadata_path_value in metadata_paths:
		var metadata_path := str(metadata_path_value)
		if metadata_path.is_empty() or not FileAccess.file_exists(metadata_path):
			push_error("C3 VAT Animator: metadata file is missing: " + metadata_path)
			_reset_all_players()
			_active_mesh_names.clear()
			_current_state = ""
			return false
		var metadata_file := FileAccess.open(metadata_path, FileAccess.READ)
		if metadata_file == null:
			_reset_all_players()
			_active_mesh_names.clear()
			_current_state = ""
			return false
		var metadata_value = JSON.parse_string(metadata_file.get_as_text())
		metadata_file.close()
		if not (metadata_value is Dictionary):
			_reset_all_players()
			_active_mesh_names.clear()
			_current_state = ""
			return false
		var metadata: Dictionary = metadata_value
		var clip_id := str(clip.get("clip_id", ""))
		if str(metadata.get("clip_id", "")) != clip_id or str(metadata.get("format", "")) != "C3_VAT_RGBA32F":
			push_error("C3 VAT Animator: metadata does not match selected clip: " + metadata_path)
			_reset_all_players()
			_active_mesh_names.clear()
			_current_state = ""
			return false
		var mesh_name := str(metadata.get("mesh_name", ""))
		if mesh_name.is_empty() or not _mesh_by_name.has(mesh_name):
			push_error("C3 VAT Animator: imported model is missing source mesh " + mesh_name)
			_reset_all_players()
			_active_mesh_names.clear()
			_current_state = ""
			return false
		var mesh_instance := _mesh_by_name[mesh_name] as MeshInstance3D
		var vat_player: C3VatPlayer = _players_by_mesh.get(mesh_name)
		if vat_player == null:
			vat_player = C3VatPlayerScript.new() as C3VatPlayer
			if vat_player == null:
				push_error("C3 VAT Animator: could not instantiate C3VatPlayer.")
				_reset_all_players()
				_active_mesh_names.clear()
				_current_state = ""
				return false
			vat_player.name = "C3VAT_" + mesh_name
			add_child(vat_player)
			_players_by_mesh[mesh_name] = vat_player
		vat_player.pause()
		var binary_name := str(metadata.get("binary_file", ""))
		if binary_name.is_empty():
			push_error("C3 VAT Animator: position texture filename is missing in " + metadata_path)
			_reset_all_players()
			_active_mesh_names.clear()
			_current_state = ""
			return false
		var binary_path := metadata_path.get_base_dir().path_join(binary_name)
		var fps := float(clip.get("fps", 30.0))
		if not vat_player.configure(mesh_instance, metadata_path, binary_path, null, fps, false):
			push_error("C3 VAT Animator: failed to bind " + clip_id + " to " + mesh_name)
			_reset_all_players()
			_active_mesh_names.clear()
			_current_state = ""
			return false
		vat_player.play()
		new_active[mesh_name] = true

	for old_mesh_name in _active_mesh_names.keys():
		if not new_active.has(old_mesh_name) and _players_by_mesh.has(old_mesh_name):
			(_players_by_mesh[old_mesh_name] as C3VatPlayer).reset()
	_active_mesh_names = new_active
	_current_state = normalized
	return true

func stop() -> void:
	for player_value in _players_by_mesh.values():
		(player_value as C3VatPlayer).pause()

func get_current_state() -> String:
	return _current_state

func _reset_all_players() -> void:
	for player_value in _players_by_mesh.values():
		var player := player_value as C3VatPlayer
		if player != null:
			player.reset()
