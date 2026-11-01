extends Control
class_name VirtualJoystickController

signal joystick_moved(direction: Vector2)

@export var max_distance: float = 64.0

var is_pressed: bool = false
var touch_index: int = -1
var stick_center: Vector2 = Vector2.ZERO
var current_vector: Vector2 = Vector2.ZERO

@onready var base: TextureRect = get_node_or_null("Base")
@onready var handle: TextureRect = get_node_or_null("Handle")

func _ready() -> void:
	stick_center = size / 2.0

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			is_pressed = true
			touch_index = event.index
			_update_joystick(event.position)
		elif event.index == touch_index:
			_reset_joystick()
	elif event is InputEventScreenDrag:
		if event.index == touch_index:
			_update_joystick(event.position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_pressed = true
				_update_joystick(event.position)
			else:
				_reset_joystick()
	elif event is InputEventMouseMotion:
		if is_pressed:
			_update_joystick(event.position)

func _update_joystick(pos: Vector2) -> void:
	var delta_vec = pos - stick_center
	if delta_vec.length() > max_distance:
		delta_vec = delta_vec.normalized() * max_distance
		
	if handle:
		handle.position = stick_center + delta_vec - (handle.size / 2.0)
		
	current_vector = delta_vec / max_distance
	emit_signal("joystick_moved", current_vector)

func _reset_joystick() -> void:
	is_pressed = false
	touch_index = -1
	current_vector = Vector2.ZERO
	if handle:
		handle.position = stick_center - (handle.size / 2.0)
	emit_signal("joystick_moved", Vector2.ZERO)

func get_direction() -> Vector2:
	return current_vector
