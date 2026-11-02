extends CharacterBody3D
class_name SimulatedPlayer

@export var sim_name_ar: String = "محارب_الرمال"
@export var sim_name_en: String = "SandWarrior"
@export var sim_class: String = "Warrior"
@export var level: int = 24
@export var movement_speed: float = 2.2

# Simulated characters are stationary by default, matching the reference town behavior.
# Movement must be explicitly commanded by a player-selected local interaction or event.
var movement_commanded: bool = false
var move_target: Vector3 = Vector3.ZERO
var target_monster: Node3D = null

@onready var label: Label3D = get_node_or_null("Label3D")

func _ready() -> void:
	add_to_group("simulated_players")
	_update_label()
	move_target = global_position
	velocity = Vector3.ZERO

func command_move_to(target: Vector3) -> void:
	move_target = target
	movement_commanded = true

func stop_commanded_movement() -> void:
	movement_commanded = false
	velocity.x = 0.0
	velocity.z = 0.0

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += get_gravity().y * delta

	if not movement_commanded:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var diff = move_target - global_position
	diff.y = 0.0
	if diff.length() > 0.8:
		var direction = diff.normalized()
		velocity.x = direction.x * movement_speed
		velocity.z = direction.z * movement_speed
		look_at(global_position + Vector3(direction.x, 0.0, direction.z), Vector3.UP)
	else:
		stop_commanded_movement()

	move_and_slide()

func _update_label() -> void:
	if label:
		var display_name = sim_name_ar if (GameManager and GameManager.current_language == "ar") else sim_name_en
		label.text = "%s [Lv.%d]" % [display_name, level]
		label.modulate = Color(0.4, 0.8, 1.0)
