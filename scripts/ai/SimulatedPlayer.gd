extends CharacterBody3D
class_name SimulatedPlayer

@export var sim_name_ar: String = "محارب_الرمال"
@export var sim_name_en: String = "SandWarrior"
@export var sim_class: String = "Warrior"
@export_enum("male", "female") var sim_gender: String = "male"
@export var level: int = 24
@export var movement_speed: float = 2.2

# Simulated characters are stationary by default, matching the reference town behavior.
# Movement must be explicitly commanded by a player-selected local interaction or event.
var movement_commanded: bool = false
var move_target: Vector3 = Vector3.ZERO
var target_monster: Node3D = null
var _c3_model_id: int = 0
@onready var visual_root: Node3D = get_node_or_null("VisualRoot")
@onready var c3_vat_animator: C3VatCharacterAnimator = get_node_or_null("C3VatAnimator")

@onready var label: Label3D = get_node_or_null("Label3D")

func _ready() -> void:
	add_to_group("simulated_players")
	_update_label()
	move_target = global_position
	if AssetCatalog and not AssetCatalog.catalog_loaded.is_connected(_on_asset_catalog_loaded):
		AssetCatalog.catalog_loaded.connect(_on_asset_catalog_loaded)
	call_deferred("_apply_gender_base_model")

func _on_asset_catalog_loaded(_asset_count: int) -> void:
	if _c3_model_id == 0:
		_apply_gender_base_model()
	velocity = Vector3.ZERO

func _apply_gender_base_model() -> bool:
	if visual_root == null or c3_vat_animator == null or AssetCatalog == null:
		return false
	var model_id := 7130000 if sim_gender == "male" else 8133010
	if not AssetCatalog.has_character_vat_animation(model_id):
		return false
	var model_path := AssetCatalog.get_character_vat_base_model_path(model_id)
	if model_path.is_empty():
		return false
	var entries := AssetCatalog.get_asset_entries("characters", [".glb", ".gltf"])
	var model_index := -1
	for index in range(entries.size()):
		if "res://" + str(entries[index].get("path", "")) == model_path:
			model_index = index
			break
	if model_index < 0:
		return false
	var candidate_root := AssetCatalog.instantiate_fitted_model("characters", model_index, visual_root, 1.7, "ImportedSimulatedCharacter")
	if candidate_root == null or candidate_root.get_child_count() == 0:
		if candidate_root:
			candidate_root.queue_free()
		return false
	var candidate := candidate_root.get_child(0) as Node3D
	if candidate == null or not c3_vat_animator.configure_character(candidate, model_id):
		candidate_root.queue_free()
		return false
	_c3_model_id = model_id
	return true

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
