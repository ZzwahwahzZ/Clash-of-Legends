extends Node
class_name C3VatPlayer

var _material: ShaderMaterial
var _frame_count: int = 0
var _fps: float = 30.0
var _frame: float = 0.0
var _running: bool = false

func configure(mesh_instance: MeshInstance3D, metadata_path: String, binary_path: String, albedo: Texture2D = null, fps_override: float = 0.0) -> bool:
	if mesh_instance == null or not is_instance_valid(mesh_instance):
		push_error("C3 VAT: target MeshInstance3D is invalid.")
		return false
	if not FileAccess.file_exists(metadata_path) or not FileAccess.file_exists(binary_path):
		push_error("C3 VAT: metadata or RGBA32F data file is missing.")
		return false
	var metadata_file := FileAccess.open(metadata_path, FileAccess.READ)
	if metadata_file == null:
		return false
	var parsed = JSON.parse_string(metadata_file.get_as_text())
	metadata_file.close()
	if not (parsed is Dictionary):
		push_error("C3 VAT: metadata JSON is invalid.")
		return false
	var width := int(parsed.get("width", 0))
	_frame_count = int(parsed.get("height", 0))
	if parsed.get("format", "") != "C3_VAT_RGBA32F" or parsed.get("classification", "") != "deforming" or not str(parsed.get("vertex_order", "")).begins_with("source C3 vertex index") or width <= 0 or _frame_count <= 1:
		push_error("C3 VAT: metadata format, deformation class, source vertex map, or dimensions are invalid.")
		return false
	if mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() == 0:
		push_error("C3 VAT: target mesh has no surfaces.")
		return false
	var raw := FileAccess.get_file_as_bytes(binary_path)
	if raw.size() != width * _frame_count * 16:
		push_error("C3 VAT: binary size does not match metadata dimensions.")
		return false
	for surface in range(mesh_instance.mesh.get_surface_count()):
		var arrays: Array = mesh_instance.mesh.surface_get_arrays(surface)
		var imported_count: int = mesh_instance.mesh.surface_get_array_len(surface)
		if arrays.size() <= Mesh.ARRAY_TEX_UV2 or not (arrays[Mesh.ARRAY_TEX_UV2] is PackedVector2Array):
			push_error("C3 VAT: imported surface is missing TEXCOORD_1/UV2 source vertex IDs.")
			return false
		var source_ids: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		if source_ids.size() != imported_count:
			push_error("C3 VAT: source vertex ID count does not match imported surface vertices.")
			return false
		for source_uv in source_ids:
			if not is_finite(source_uv.x):
				push_error("C3 VAT: imported source vertex ID is not finite.")
				return false
			var source_index := int(floor(source_uv.x * float(width)))
			if source_index < 0 or source_index >= width or absf(source_uv.x - (float(source_index) + 0.5) / float(width)) > 0.00001:
				push_error("C3 VAT: imported vertex has an invalid original C3 vertex index.")
				return false
	var image := Image.create_from_data(width, _frame_count, false, Image.FORMAT_RGBAF, raw)
	if image == null or image.is_empty():
		push_error("C3 VAT: could not create RGBA32F animation texture.")
		return false
	var vat_texture := ImageTexture.create_from_image(image)
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/C3Vat.gdshader") as Shader
	if _material.shader == null:
		push_error("C3 VAT: shader resource failed to load.")
		return false
	_material.set_shader_parameter("vat_texture", vat_texture)
	_material.set_shader_parameter("vat_width", float(width))
	_material.set_shader_parameter("vat_height", float(_frame_count))
	if albedo != null:
		_material.set_shader_parameter("albedo_texture", albedo)
	# VAT already contains fully evaluated C3 vertex positions for every frame.
	# Keeping the imported glTF Skin would deform those baked positions a second time.
	mesh_instance.skin = null
	mesh_instance.skeleton = NodePath()
	_hide_c3_attachment_socket_markers(mesh_instance)
	mesh_instance.material_override = _material
	_fps = fps_override if fps_override > 0.0 else float(parsed.get("fps", 30.0))
	_frame = 0.0
	_running = true
	return true

func set_frame(frame: float) -> void:
	if _material == null or _frame_count <= 0:
		return
	_frame = clampf(frame, 0.0, float(_frame_count - 1))
	_material.set_shader_parameter("vat_frame", _frame)

func play() -> void:
	_running = true

func pause() -> void:
	_running = false

func _process(delta: float) -> void:
	if not _running or _material == null or _frame_count <= 1:
		return
	_frame = fposmod(_frame + delta * _fps, float(_frame_count))
	_material.set_shader_parameter("vat_frame", _frame)


# C3's v_slot/v_zero meshes are tiny attachment-reference markers, not
# visible character surfaces. Keep their original nodes, transforms and
# geometry in the GLB for equipment/socket placement, but do not draw the
# marker triangles over the character in-game.
func _hide_c3_attachment_socket_markers(mesh_instance: MeshInstance3D) -> void:
	var scene_root: Node = mesh_instance
	while scene_root.get_parent() != null and scene_root.get_parent() is Node3D:
		scene_root = scene_root.get_parent()
	var helper_names := {
		"v_zero": true,
		"v_slot": true,
		"v_l_slot01": true,
		"v_l_slot02": true,
		"v_r_slot01": true,
		"v_r_slot02": true
	}
	for node in scene_root.find_children("*", "MeshInstance3D", true, false):
		var helper := node as MeshInstance3D
		if helper_names.has(helper.name.to_lower()):
			helper.visible = false
