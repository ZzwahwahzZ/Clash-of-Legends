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
	if parsed.get("format", "") != "C3_VAT_RGBA32F" or width <= 0 or _frame_count <= 1:
		push_error("C3 VAT: metadata format or dimensions are invalid.")
		return false
	if mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() == 0:
		push_error("C3 VAT: target mesh has no surfaces.")
		return false
	var raw := FileAccess.get_file_as_bytes(binary_path)
	if raw.size() != width * _frame_count * 16:
		push_error("C3 VAT: binary size does not match metadata dimensions.")
		return false
	for surface in range(mesh_instance.mesh.get_surface_count()):
		var imported_count := mesh_instance.mesh.surface_get_array_len(surface)
		if imported_count != width:
			push_error("C3 VAT: imported surface vertex count %d does not match VAT width %d." % [imported_count, width])
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
