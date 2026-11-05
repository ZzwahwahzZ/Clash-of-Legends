extends CharacterBody3D
class_name MonsterBase

@export var monster_name_ar: String = "وحش بري"
@export var monster_name_en: String = "Wild Beast"
@export var enemy_type: String = "wolf"
@export var max_health: int = 180
@export var attack_power: int = 22
@export var move_speed: float = 3.8
@export var detection_range: float = 14.0
@export var attack_range: float = 2.2
@export var xp_reward: int = 65
@export var gold_min: int = 35
@export var gold_max: int = 80
@export var respawn_time: float = 6.0
@export var is_boss: bool = false

enum State { IDLE, PATROL, CHASE, ATTACK, RETURNING, DEAD }

var current_state: State = State.IDLE
var current_health: int = 180
var spawn_position: Vector3 = Vector3.ZERO
var target_player: CharacterBody3D = null
var attack_cooldown: float = 0.0
var state_timer: float = 0.0
var anim_time: float = 0.0
var imported_model_animation: AnimationPlayer = null
var imported_animation_name: String = ""

@onready var loot_scene: PackedScene = preload("res://scenes/world/LootDrop3D.tscn")
@onready var health_bar: Label3D = get_node_or_null("HealthLabel")

# Visual Nodes
@onready var visual_root: Node3D = get_node_or_null("VisualRoot")
@onready var fl_leg: Node3D = get_node_or_null("VisualRoot/FrontLeftLeg")
@onready var fr_leg: Node3D = get_node_or_null("VisualRoot/FrontRightLeg")
@onready var rl_leg: Node3D = get_node_or_null("VisualRoot/RearLeftLeg")
@onready var rr_leg: Node3D = get_node_or_null("VisualRoot/RearRightLeg")
@onready var left_wing: Node3D = get_node_or_null("VisualRoot/Torso/LeftWing")
@onready var right_wing: Node3D = get_node_or_null("VisualRoot/Torso/RightWing")
@onready var tail_node: Node3D = get_node_or_null("VisualRoot/Torso/Tail")

func _ready() -> void:
	add_to_group("enemies")
	spawn_position = global_position
	current_health = max_health
	_update_label()
	if AssetCatalog:
		AssetCatalog.catalog_loaded.connect(_on_asset_catalog_loaded)
	call_deferred("_apply_monster_model")
	if is_boss and GameManager:
		GameManager.emit_signal("boss_spawned", monster_name_ar if GameManager.current_language == "ar" else monster_name_en, spawn_position)

func _on_asset_catalog_loaded(_asset_count: int) -> void:
	_apply_monster_model()

func _apply_monster_model() -> void:
	if not visual_root or not AssetCatalog:
		return
	var model_entries := AssetCatalog.get_asset_entries("monsters", [".glb", ".gltf"])
	if model_entries.is_empty():
		return
	# A category index is not a monster identity. Do not bind a random GLB
	# to an enemy type; scenes may opt in only after a source-verified mapping.
	var model_index := int(get_meta("verified_monster_model_index", -1))
	if model_index < 0 or model_index >= model_entries.size():
		return
	imported_model_animation = null
	imported_animation_name = ""
	var old_root := visual_root.get_node_or_null("ImportedModelRoot")
	if old_root:
		old_root.queue_free()
	var target_height := 4.5 if is_boss else 1.35
	var imported_root := AssetCatalog.instantiate_fitted_model("monsters", model_index, visual_root, target_height, "ImportedModelRoot")
	if imported_root == null:
		return
	for child in visual_root.get_children():
		if child != imported_root and child is Node3D:
			child.visible = false
	var instance: Node = imported_root.get_child(0)
	var model_animation := instance.find_child("AnimationPlayer", true, false)
	if model_animation is AnimationPlayer:
		imported_model_animation = model_animation as AnimationPlayer
		_set_imported_animation_state("idle")

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return
		
	if attack_cooldown > 0.0:
		attack_cooldown = max(0.0, attack_cooldown - delta)
		
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
		
	anim_time += delta * 6.0
	
	# Wing flapping for boss dragon
	if left_wing and right_wing:
		var flap = sin(anim_time * 1.5) * 0.35
		left_wing.rotation.z = flap
		right_wing.rotation.z = -flap
		
	# Tail subtle sway
	if tail_node:
		tail_node.rotation.y = sin(anim_time * 0.8) * 0.2
		
	match current_state:
		State.IDLE:
			state_timer += delta
			if state_timer > 2.5:
				state_timer = 0.0
				current_state = State.PATROL
			_check_player_detection()
		State.PATROL:
			state_timer += delta
			if state_timer > 3.0:
				state_timer = 0.0
				current_state = State.IDLE
			_check_player_detection()
		State.CHASE:
			if target_player and is_instance_valid(target_player) and not target_player.is_dead:
				var dist = global_position.distance_to(target_player.global_position)
				if dist > detection_range * 1.5:
					current_state = State.RETURNING
				elif dist <= attack_range:
					current_state = State.ATTACK
				else:
					var diff = target_player.global_position - global_position
					diff.y = 0.0
					var dir = diff.normalized()
					_set_imported_animation_state("move")
					velocity.x = dir.x * move_speed
					velocity.z = dir.z * move_speed
					look_at(global_position + Vector3(dir.x, 0, dir.z), Vector3.UP)
					_animate_legs(delta, true)
			else:
				current_state = State.RETURNING
		State.ATTACK:
			if target_player and is_instance_valid(target_player) and not target_player.is_dead:
				var dist = global_position.distance_to(target_player.global_position)
				if dist > attack_range * 1.2:
					current_state = State.CHASE
				else:
					velocity.x = 0
					velocity.z = 0
					_set_imported_animation_state("attack")
					_animate_legs(delta, false)
					if attack_cooldown <= 0.0:
						_perform_attack()
			else:
				current_state = State.RETURNING
		State.RETURNING:
			var diff = spawn_position - global_position
			diff.y = 0.0
			if diff.length() < 1.0:
				velocity.x = 0
				velocity.z = 0
				_set_imported_animation_state("idle")
				_animate_legs(delta, false)
				current_state = State.IDLE
			else:
				var dir = diff.normalized()
				_set_imported_animation_state("move")
				velocity.x = dir.x * move_speed
				velocity.z = dir.z * move_speed
				look_at(global_position + Vector3(dir.x, 0, dir.z), Vector3.UP)
				_animate_legs(delta, true)
				
	move_and_slide()

func _set_imported_animation_state(state: String) -> void:
	if imported_model_animation == null or not is_instance_valid(imported_model_animation):
		return
	var preferred := ["idle", "stand"] if state == "idle" else (["attack", "hit"] if state == "attack" else ["run", "walk", "move"])
	var selected := ""
	for animation_name in imported_model_animation.get_animation_list():
		var normalized := animation_name.to_lower()
		for token in preferred:
			if normalized.contains(token):
				selected = animation_name
				break
		if not selected.is_empty():
			break
	# Imported action clips are not semantically mapped yet. Never play
	# the first clip merely because it exists; wait for a verified alias.
	if selected.is_empty():
		return
	imported_model_animation.speed_scale = 1.0 if state == "idle" else (1.15 if state == "move" else 1.0)
	if selected != imported_animation_name:
		imported_animation_name = selected
		imported_model_animation.play(selected)

func _animate_legs(delta: float, is_moving: bool) -> void:
	if fl_leg and fr_leg and rl_leg and rr_leg:
		if is_moving:
			var stride = sin(anim_time * 2.2) * 0.45
			fl_leg.rotation.x = stride
			fr_leg.rotation.x = -stride
			rl_leg.rotation.x = -stride
			rr_leg.rotation.x = stride
		else:
			fl_leg.rotation.x = lerp(fl_leg.rotation.x, 0.0, delta * 8.0)
			fr_leg.rotation.x = lerp(fr_leg.rotation.x, 0.0, delta * 8.0)
			rl_leg.rotation.x = lerp(rl_leg.rotation.x, 0.0, delta * 8.0)
			rr_leg.rotation.x = lerp(rr_leg.rotation.x, 0.0, delta * 8.0)

func _check_player_detection() -> void:
	var player = GameManager.player_reference if GameManager else null
	if player and is_instance_valid(player) and not player.is_dead:
		if global_position.distance_to(player.global_position) <= detection_range:
			target_player = player
			current_state = State.CHASE

func _perform_attack() -> void:
	attack_cooldown = 1.6
	if target_player and target_player.has_method("take_damage"):
		target_player.take_damage(attack_power, self)

func take_damage(amount: int, attacker: CharacterBody3D) -> void:
	if current_state == State.DEAD:
		return
	current_health = max(0, current_health - amount)
	_update_label()
	
	if target_player == null and attacker:
		target_player = attacker
		current_state = State.CHASE
		
	if current_health <= 0:
		_on_death(attacker)

func _update_label() -> void:
	if health_bar:
		var name_str = monster_name_ar if (GameManager and GameManager.current_language == "ar") else monster_name_en
		health_bar.text = "%s [%d/%d]" % [name_str, current_health, max_health]

func _on_death(killer: CharacterBody3D) -> void:
	current_state = State.DEAD
	velocity = Vector3.ZERO
	visible = false
	collision_layer = 0
	collision_mask = 0
	
	# Rewards require an explicitly source-verified profile on this monster scene.
	var reward_profile := _get_verified_reward_profile()
	if not reward_profile.is_empty():
		if killer and killer.has_method("add_xp"):
			killer.add_xp(int(reward_profile["xp"]))
		_spawn_verified_loot(reward_profile)
		
	# Notify Quest Agent
	var tree = get_tree()
	if tree:
		var quest_agents = tree.get_nodes_in_group("quest_agents")
		for qa in quest_agents:
			if qa.has_method("on_enemy_killed"):
				qa.on_enemy_killed(enemy_type)
				
	if is_boss and GameManager:
		var killer_name = "البطل" if GameManager.current_language == "ar" else "Hero"
		GameManager.emit_signal("boss_defeated", monster_name_ar if GameManager.current_language == "ar" else monster_name_en, killer_name)
		
	# Respawn timer
	await get_tree().create_timer(respawn_time).timeout
	_respawn()

func _get_verified_reward_profile() -> Dictionary:
	var raw_profile: Variant = get_meta("verified_reward_profile", {})
	if not raw_profile is Dictionary:
		return {}
	var profile: Dictionary = raw_profile
	for required_key in ["xp", "gold_min", "gold_max", "drops"]:
		if not profile.has(required_key):
			return {}
	if int(profile["xp"]) < 0 or int(profile["gold_min"]) < 0 or int(profile["gold_max"]) < int(profile["gold_min"]):
		return {}
	if not profile["drops"] is Array:
		return {}
	for entry in profile["drops"]:
		if not entry is Dictionary or not entry.has("chance") or not entry.has("item_data"):
			return {}
		if float(entry["chance"]) < 0.0 or float(entry["chance"]) > 1.0 or not entry["item_data"] is Dictionary:
			return {}
	return profile


func _spawn_verified_loot(profile: Dictionary) -> void:
	if loot_scene == null:
		return
	var gold_minimum := int(profile["gold_min"])
	var gold_maximum := int(profile["gold_max"])
	var gold_value := randi_range(gold_minimum, gold_maximum) if gold_maximum > 0 else 0
	var selected_item: Variant = null
	for entry in profile["drops"]:
		if randf() <= float(entry["chance"]):
			selected_item = entry["item_data"].duplicate(true)
			break
	if gold_value <= 0 and selected_item == null:
		return
	var drop := loot_scene.instantiate()
	get_parent().add_child(drop)
	drop.global_position = global_position + Vector3(0, 0.5, 0)
	if drop.has_method("setup_loot"):
		drop.setup_loot({
			"gold": gold_value,
			"has_item": selected_item != null,
			"item_data": selected_item
		})


func _respawn() -> void:
	current_health = max_health
	global_position = spawn_position
	visible = true
	collision_layer = 1
	collision_mask = 1
	current_state = State.IDLE
	_update_label()

func is_dead_state() -> bool:
	return current_state == State.DEAD
