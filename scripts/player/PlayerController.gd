extends CharacterBody3D
class_name PlayerController

@export var character_class: String = "Trojan"
@export var base_speed: float = 6.5
@export var mount_speed_multiplier: float = 1.6
@export var jump_velocity: float = 5.5

var current_hp: int = 500
var max_hp: int = 500
var current_mp: int = 200
var max_mp: int = 200
var current_xp: int = 0
var max_xp: int = 1000
var current_level: int = 1

var base_attack: int = 45
var base_defense: int = 15
var equipment_attack_bonus: int = 0
var equipment_defense_bonus: int = 0
var temp_defense_buff_timer: float = 0.0

var is_mounted: bool = false
var is_dead: bool = false
var basic_attack_cooldown: float = 0.0
var walk_anim_time: float = 0.0
var attack_anim_timer: float = 0.0

var input_direction: Vector2 = Vector2.ZERO
var target_nav_position: Vector3 = Vector3.ZERO
var is_moving_to_target: bool = false

@onready var camera_pivot: Node3D = $CameraPivot
@onready var free_camera: FreeCamera3D = $CameraPivot/FreeCamera3D
@onready var inventory: PlayerInventory = $PlayerInventory

# Visual Limb Nodes
@onready var visual_root: Node3D = get_node_or_null("VisualRoot")
@onready var torso_node: Node3D = get_node_or_null("VisualRoot/Torso")
@onready var left_leg: Node3D = get_node_or_null("VisualRoot/LeftLeg")
@onready var right_leg: Node3D = get_node_or_null("VisualRoot/RightLeg")
@onready var left_arm: Node3D = get_node_or_null("VisualRoot/Torso/LeftArm")
@onready var right_arm: Node3D = get_node_or_null("VisualRoot/Torso/RightArm")
@onready var weapon_mount: Node3D = get_node_or_null("VisualRoot/Torso/WeaponMount")
@onready var mount_mesh: Node3D = get_node_or_null("VisualRoot/MountMesh") if has_node("VisualRoot/MountMesh") else get_node_or_null("MountMesh")
@onready var anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer")

func _ready() -> void:
	if GameManager:
		GameManager.register_player(self)
	if ClassProgressionManager:
		ClassProgressionManager.configure_for_character(character_class)
	sync_stats_to_hud()
	if anim_player and anim_player.has_animation("idle"):
		anim_player.play("idle")

func _physics_process(delta: float) -> void:
	if is_dead:
		if visual_root:
			visual_root.rotation.x = lerp_angle(visual_root.rotation.x, deg_to_rad(-85.0), delta * 8.0)
		return
	if basic_attack_cooldown > 0.0:
		basic_attack_cooldown = max(0.0, basic_attack_cooldown - delta)
	if temp_defense_buff_timer > 0.0:
		temp_defense_buff_timer = max(0.0, temp_defense_buff_timer - delta)
	if attack_anim_timer > 0.0:
		attack_anim_timer = max(0.0, attack_anim_timer - delta)
		if weapon_mount:
			weapon_mount.rotation.x = sin(attack_anim_timer * 15.0) * 0.8
	elif weapon_mount:
		weapon_mount.rotation.x = lerp(weapon_mount.rotation.x, 0.0, delta * 10.0)

	if not is_on_floor():
		velocity.y += get_gravity().y * delta

	var move_vec = Vector3.ZERO
	var current_speed = base_speed * (mount_speed_multiplier if is_mounted else 1.0)
	if input_direction != Vector2.ZERO:
		var cam_yaw = free_camera.get_camera_yaw() if free_camera else 0.0
		var forward = Vector3(0, 0, -1).rotated(Vector3.UP, cam_yaw)
		var right = Vector3(1, 0, 0).rotated(Vector3.UP, cam_yaw)
		var dir = (right * input_direction.x + forward * -input_direction.y).normalized()
		move_vec = dir * current_speed
		is_moving_to_target = false
	elif is_moving_to_target:
		var diff = target_nav_position - global_position
		diff.y = 0.0
		if diff.length() > 0.6:
			move_vec = diff.normalized() * current_speed
		else:
			is_moving_to_target = false

	velocity.x = move_vec.x
	velocity.z = move_vec.z
	var is_moving = move_vec.length_squared() > 0.01
	if is_moving:
		look_at(global_position + Vector3(move_vec.x, 0, move_vec.z), Vector3.UP)
		walk_anim_time += delta * 12.0
		var stride = sin(walk_anim_time) * 0.45
		if left_leg: left_leg.rotation.x = stride
		if right_leg: right_leg.rotation.x = -stride
		if left_arm: left_arm.rotation.x = -stride * 0.7
		if right_arm and attack_anim_timer <= 0.0: right_arm.rotation.x = stride * 0.7
	else:
		walk_anim_time = 0.0
		if left_leg: left_leg.rotation.x = lerp(left_leg.rotation.x, 0.0, delta * 10.0)
		if right_leg: right_leg.rotation.x = lerp(right_leg.rotation.x, 0.0, delta * 10.0)
		if left_arm: left_arm.rotation.x = lerp(left_arm.rotation.x, 0.0, delta * 10.0)
		if right_arm and attack_anim_timer <= 0.0: right_arm.rotation.x = lerp(right_arm.rotation.x, 0.0, delta * 10.0)
	move_and_slide()

func set_joystick_input(vec: Vector2) -> void:
	input_direction = vec

func move_towards_target_position(pos: Vector3, _delta: float) -> void:
	target_nav_position = pos
	is_moving_to_target = true

func perform_jump() -> void:
	if is_on_floor() and not is_dead:
		velocity.y = jump_velocity

func toggle_mount() -> void:
	is_mounted = !is_mounted
	if mount_mesh:
		mount_mesh.visible = is_mounted
	if torso_node:
		torso_node.position.y = 1.35 if is_mounted else 0.9
	if GameManager:
		var msg = "تم امتطاء الحصان الحربي" if is_mounted else "تم الترجل عن الحصان"
		GameManager.post_notification(msg if GameManager.current_language == "ar" else ("Mounted" if is_mounted else "Dismounted"), false)

func execute_basic_attack() -> void:
	if basic_attack_cooldown > 0.0 or is_dead:
		return
	basic_attack_cooldown = 0.75
	attack_anim_timer = 0.35
	var target = GameManager.current_target if GameManager else null
	if not target or not is_instance_valid(target) or (target.has_method("is_dead_state") and target.is_dead_state()):
		return
	if global_position.distance_to(target.global_position) > 3.2:
		return
	var dmg = get_attack_power()
	var is_crit = randf() < 0.15
	if is_crit:
		dmg = int(dmg * 1.5)
	if target.has_method("take_damage"):
		target.take_damage(dmg, self)
		if CombatEngine:
			CombatEngine.emit_signal("damage_dealt", target, dmg, is_crit, target.global_position + Vector3(0, 1.2, 0))

func get_attack_power() -> int:
	return base_attack + equipment_attack_bonus

func get_defense_power() -> int:
	var total = base_defense + equipment_defense_bonus
	if temp_defense_buff_timer > 0.0:
		total += 25
	return total

func apply_defense_buff(duration: float) -> void:
	temp_defense_buff_timer = duration

func apply_healing(amount: int) -> void:
	current_hp = min(max_hp, current_hp + amount)
	sync_stats_to_hud()

func restore_mp(amount: int) -> void:
	current_mp = min(max_mp, current_mp + amount)
	sync_stats_to_hud()

func consume_mp(amount: int) -> void:
	current_mp = max(0, current_mp - amount)
	sync_stats_to_hud()

func get_mp() -> int:
	return current_mp

func get_character_class() -> String:
	return character_class

func set_character_class(new_cls: String) -> void:
	character_class = new_cls
	if ClassProgressionManager:
		ClassProgressionManager.configure_for_character(character_class)
	if GameManager:
		GameManager.post_notification("تم تغيير فئة البطل إلى " + new_cls, false)

func select_archer_weapon_style(style_id: String) -> bool:
	if character_class != "Archer" or not ClassProgressionManager:
		return false
	return ClassProgressionManager.select_weapon_style(style_id)

func get_archer_weapon_style() -> String:
	return ClassProgressionManager.selected_weapon_style if ClassProgressionManager else ""

func update_equipment_bonuses(atk_bonus: int, def_bonus: int) -> void:
	equipment_attack_bonus = atk_bonus
	equipment_defense_bonus = def_bonus

func take_damage(amount: int, attacker: Node3D) -> void:
	if is_dead:
		return
	var reduced: int = maxi(1, amount - int(get_defense_power() / 2))
	if has_node("PlayerInventory"):
		var inventory: PlayerInventory = get_node("PlayerInventory")
		reduced = maxi(1, int(round(float(reduced) * (1.0 - inventory.get_total_blessing_reduction()))))
	current_hp = max(0, current_hp - reduced)
	sync_stats_to_hud()
	if current_hp <= 0:
		_on_death(attacker)

func add_xp(amount: int) -> void:
	current_xp += amount
	while current_xp >= max_xp:
		current_xp -= max_xp
		_level_up()
	sync_stats_to_hud()

func _level_up() -> void:
	current_level += 1
	max_hp += 80
	current_hp = max_hp
	max_mp += 40
	current_mp = max_mp
	base_attack += 8
	base_defense += 4
	max_xp = int(max_xp * 1.35)
	if ClassProgressionManager:
		if ClassProgressionManager.refresh_level_unlocks(current_level) and GameManager:
			GameManager.post_notification("تم فتح مسار السفاح الشرقي! يمكنك الآن الاختيار بين القوس والخناجر الطائرة." if GameManager.current_language == "ar" else "Oriental Assassin path unlocked! Choose between bow and flying daggers.", false)
	for agent in get_tree().get_nodes_in_group("quest_agents"):
		if agent.has_method("on_level_reached"):
			agent.on_level_reached(current_level)
	if GameManager:
		var txt = "تهانينا! ارتقيت إلى المستوى %d!" % current_level
		GameManager.post_notification(txt if GameManager.current_language == "ar" else ("Level Up! Level %d" % current_level), false)

func _on_death(_killer: Node3D) -> void:
	is_dead = true
	if GameManager:
		GameManager.post_notification("سقط البطل في المعركة! ستتم العودة للحياة في مدينة التوأم..." if GameManager.current_language == "ar" else "You died! Respawning in Twin City...", true)
	await get_tree().create_timer(3.0).timeout
	respawn()

func respawn() -> void:
	is_dead = false
	if visual_root:
		visual_root.rotation.x = 0.0
	current_hp = max_hp
	current_mp = max_mp
	global_position = Vector3(0, 1.0, 0)
	sync_stats_to_hud()

func sync_stats_to_hud() -> void:
	if GameManager:
		var gold = GameManager.current_gold
		GameManager.emit_signal("player_stats_changed", current_hp, max_hp, current_mp, max_mp, current_xp, max_xp, current_level, gold)
