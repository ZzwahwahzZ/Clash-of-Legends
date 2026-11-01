extends CharacterBody3D
class_name SimulatedPlayer

@export var sim_name_ar: String = "محارب_الرمال"
@export var sim_name_en: String = "SandWarrior"
@export var sim_class: String = "Warrior"
@export var level: int = 24

var state_timer: float = 0.0
var move_target: Vector3 = Vector3.ZERO
var target_monster: Node3D = null

@onready var label: Label3D = get_node_or_null("Label3D")

func _ready() -> void:
	add_to_group("simulated_players")
	_update_label()
	move_target = global_position

func _physics_process(delta: float) -> void:
	state_timer += delta
	if state_timer > 4.0:
		state_timer = 0.0
		# Pick wandering point near current position
		var offset = Vector3(randf_range(-12, 12), 0, randf_range(-12, 12))
		move_target = global_position + offset
		
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
		
	var diff = move_target - global_position
	diff.y = 0.0
	if diff.length() > 0.8:
		var dir = diff.normalized()
		velocity.x = dir.x * 3.2
		velocity.z = dir.z * 3.2
		look_at(global_position + Vector3(dir.x, 0, dir.z), Vector3.UP)
	else:
		velocity.x = 0
		velocity.z = 0
		
	move_and_slide()

func _update_label() -> void:
	if label:
		var n = sim_name_ar if (GameManager and GameManager.current_language == "ar") else sim_name_en
		label.text = "%s [Lv.%d]" % [n, level]
		label.modulate = Color(0.4, 0.8, 1.0)
