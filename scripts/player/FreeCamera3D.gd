extends SpringArm3D
class_name FreeCamera3D

@export var mouse_sensitivity: float = 0.005
@export var touch_sensitivity: float = 0.008
@export var min_pitch: float = deg_to_rad(-65.0)
@export var max_pitch: float = deg_to_rad(15.0)
@export var min_zoom: float = 3.0
@export var max_zoom: float = 18.0
@export var default_zoom: float = 8.5

var current_zoom: float = 8.5
var touch_start_pos: Vector2 = Vector2.ZERO
var is_touching_camera_area: bool = false

func _ready() -> void:
	spring_length = default_zoom
	current_zoom = default_zoom
	# Default classic Conquer Online elevated angle (~40 degrees downward)
	rotation.x = deg_to_rad(-38.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		# Touch rotation for Android touch screens (drag on right side of screen)
		if event.position.x > (get_viewport().get_visible_rect().size.x * 0.4):
			rotate_camera(event.relative.x * touch_sensitivity, -event.relative.y * touch_sensitivity)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		rotate_camera(event.relative.x * mouse_sensitivity, -event.relative.y * mouse_sensitivity)

func rotate_camera(yaw_delta: float, pitch_delta: float) -> void:
	rotation.y -= yaw_delta
	rotation.x = clamp(rotation.x + pitch_delta, min_pitch, max_pitch)

func set_zoom(val: float) -> void:
	current_zoom = clamp(val, min_zoom, max_zoom)
	spring_length = current_zoom

func adjust_zoom(delta_val: float) -> void:
	set_zoom(current_zoom + delta_val)

func reset_camera() -> void:
	rotation.y = 0.0
	rotation.x = deg_to_rad(-38.0)
	set_zoom(default_zoom)

func get_camera_yaw() -> float:
	return rotation.y
