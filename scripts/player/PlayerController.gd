extends CharacterBody3D
class_name PlayerController

@export var character_class: String = "Trojan"
@export_enum("male", "female") var character_gender: String = "male"
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
var imported_model_animation: AnimationPlayer = null
var imported_animation_name: String = ""
var imported_mount_item_id: String = ""
var imported_weapon_item_id: String = ""
var footstep_timer: float = 0.0

# World-touch navigation is separate from the virtual joystick. UI controls
# consume their own touches before they reach _unhandled_input.
@export var world_tap_max_drag: float = 18.0
@export var world_double_tap_window_ms: int = 300
@export var world_double_tap_jump: bool = true
var _world_touch_starts: Dictionary = {}
var _last_world_tap_ms: int = -1000
var _last_world_tap_position: Vector2 = Vector2.ZERO
var _mouse_world_press_position: Vector2 = Vector2.ZERO
var _mouse_world_pressed: bool = false

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
	if inventory and not inventory.equipment_updated.is_connected(_on_equipment_updated):
		inventory.equipment_updated.connect(_on_equipment_updated)
	if AssetCatalog:
		AssetCatalog.catalog_loaded.connect(_on_asset_catalog_loaded)
	sync_stats_to_hud()
	if anim_player and anim_player.has_animation("idle"):
		anim_player.play("idle")
	call_deferred("_apply_character_model")
	call_deferred("_apply_mount_model")
	call_deferred("_apply_weapon_model")
	call_deferred("_apply_refinement_glow")

func _on_equipment_updated() -> void:
	_apply_refinement_glow()
	_apply_mount_model()
	_apply_weapon_model()

func _apply_refinement_glow() -> void:
	if not inventory:
		return
	var weapon: Variant = inventory.equipment.get("weapon", null)
	var refine_level := int(weapon.get("refine_level", 0)) if weapon is Dictionary else 0
	var weapon_nodes: Array[MeshInstance3D] = []
	if weapon_mount:
		for node in weapon_mount.find_children("*", "MeshInstance3D", true, false):
			var mesh_node := node as MeshInstance3D
			if _is_renderable_mesh_instance(mesh_node) and not weapon_nodes.has(mesh_node):
				weapon_nodes.append(mesh_node)
	if visual_root:
		var imported := visual_root.get_node_or_null("ImportedModelRoot")
		if imported:
			for node in imported.find_children("*", "MeshInstance3D", true, false):
				var node_name := str(node.name).to_lower()
				var mesh_node := node as MeshInstance3D
				if ("weapon" in node_name or "sword" in node_name or "blade" in node_name or "dagger" in node_name or "axe" in node_name) and _is_renderable_mesh_instance(mesh_node) and not weapon_nodes.has(mesh_node):
					weapon_nodes.append(mesh_node)
	if weapon_nodes.is_empty():
		return
	var shader := load("res://assets/shaders/weapon_glow.gdshader") as Shader
	if shader == null:
		return
	var glow := Color(0.18, 0.55, 1.0)
	if refine_level >= 9:
		glow = Color(1.0, 0.24, 0.12)
	elif refine_level >= 6:
		glow = Color(0.72, 0.28, 1.0)
	elif refine_level >= 3:
		glow = Color(0.18, 0.85, 0.55)
	var energy := 0.0 if refine_level <= 0 else 1.0 + float(refine_level) * 0.48
	for mesh_node in weapon_nodes:
		if not _is_renderable_mesh_instance(mesh_node):
			continue
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("base_color", Color(0.72, 0.76, 0.82))
		material.set_shader_parameter("glow_color", glow)
		material.set_shader_parameter("emission_energy", energy)
		material.set_shader_parameter("pulse_speed", 1.8 + float(refine_level) * 0.12)
		material.set_shader_parameter("pulse_intensity", 0.12 + float(refine_level) * 0.025)
		mesh_node.material_override = material

func _is_renderable_mesh_instance(node: MeshInstance3D) -> bool:
	return is_instance_valid(node) and node.mesh != null and node.mesh.get_surface_count() > 0

func _on_asset_catalog_loaded(_asset_count: int) -> void:
	_apply_character_model()
	_apply_mount_model()
	_apply_weapon_model()

func _apply_character_model() -> bool:
	if not visual_root or not AssetCatalog:
		return false
	var model_entries := AssetCatalog.get_asset_entries("characters", [".glb", ".gltf"])
	if model_entries.is_empty():
		return false
	# Never assign a class model by array position: source catalogs contain body
	# parts, NPCs and unrelated models. Only explicit, reviewed runtime mappings qualify.
	var model_index := AssetCatalog.get_verified_character_model_index(character_class, character_gender)
	if model_index < 0:
		return false
	# Build and validate the candidate while the current visible model remains intact.
	var candidate_root := AssetCatalog.instantiate_fitted_model("characters", model_index, visual_root, 1.7, "CharacterCandidate")
	if candidate_root == null:
		push_warning("Character replacement rejected: scene could not be instantiated.")
		return false
	var candidate_instance: Node = candidate_root.get_child(0) if candidate_root.get_child_count() > 0 else null
	var candidate_animation := candidate_instance.find_child("AnimationPlayer", true, false) if candidate_instance else null
	var validation := _validate_character_candidate(candidate_instance, candidate_animation)
	if not bool(validation.get("ok", false)):
		push_warning("Character replacement rejected; keeping current visible model. " + str(validation.get("reason", "validation failed")))
		candidate_root.queue_free()
		return false

	var old_root := visual_root.get_node_or_null("ImportedModelRoot")
	if old_root:
		old_root.queue_free()
	candidate_root.name = "ImportedModelRoot"
	imported_model_animation = candidate_animation as AnimationPlayer
	imported_animation_name = ""
	_set_imported_animation_state("idle")
	for child in visual_root.get_children():
		if child != candidate_root and child is Node3D:
			child.visible = false
	call_deferred("_apply_refinement_glow")
	return true

func _validate_character_candidate(candidate: Node, animation_node: Node) -> Dictionary:
	if candidate == null:
		return {"ok": false, "reason": "missing instantiated model root"}
	var mesh_count := 0
	var textured_surface_count := 0
	var morph_mesh_count := 0
	var skinned_mesh_count := 0
	var skeleton_count := 0
	var total_bones := 0
	for node in candidate.find_children("*", "Skeleton3D", true, false):
		var skeleton := node as Skeleton3D
		skeleton_count += 1
		total_bones += skeleton.get_bone_count()
	for node in candidate.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if not _is_renderable_mesh_instance(mesh_instance):
			continue
		mesh_count += 1
		var array_mesh := mesh_instance.mesh as ArrayMesh
		if array_mesh != null and array_mesh.get_blend_shape_count() > 0:
			morph_mesh_count += 1
		if mesh_instance.skin != null and not mesh_instance.skeleton.is_empty():
			skinned_mesh_count += 1
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var surface_material := mesh_instance.get_active_material(surface_index)
			if surface_material == null:
				return {"ok": false, "reason": "mesh surface has no active material"}
			if surface_material is BaseMaterial3D:
				var albedo_texture := (surface_material as BaseMaterial3D).albedo_texture
				if albedo_texture != null and albedo_texture.get_width() > 1 and albedo_texture.get_height() > 1:
					textured_surface_count += 1
	if mesh_count == 0:
		return {"ok": false, "reason": "no renderable mesh surfaces"}
	if textured_surface_count == 0:
		return {"ok": false, "reason": "no valid texture-backed material surfaces"}
	if not animation_node is AnimationPlayer:
		return {"ok": false, "reason": "no AnimationPlayer"}
	var animation_player := animation_node as AnimationPlayer
	var has_skeletal_idle := false
	var has_skeletal_move := false
	var has_morph_idle := false
	var has_morph_move := false
	for animation_name in animation_player.get_animation_list():
		var normalized := animation_name.to_lower()
		var animation := animation_player.get_animation(animation_name)
		if animation == null or animation.get_track_count() == 0:
			continue
		var has_skeletal_track := false
		var has_morph_track := false
		for track_index in range(animation.get_track_count()):
			var track_path := str(animation.track_get_path(track_index)).to_lower()
			if track_path.contains("skeleton3d") or track_path.contains("bone_pose") or track_path.contains("bones/"):
				has_skeletal_track = true
			if track_path.contains("blend_shapes") or track_path.contains("blend_shape"):
				has_morph_track = true
		has_skeletal_idle = has_skeletal_idle or (has_skeletal_track and (normalized.contains("idle") or normalized.contains("stand")))
		has_skeletal_move = has_skeletal_move or (has_skeletal_track and (normalized.contains("walk") or normalized.contains("run") or normalized.contains("move")))
		has_morph_idle = has_morph_idle or (has_morph_track and (normalized.contains("idle") or normalized.contains("stand")))
		has_morph_move = has_morph_move or (has_morph_track and (normalized.contains("walk") or normalized.contains("run") or normalized.contains("move")))
	var skeletal_animation_valid := skeleton_count > 0 and total_bones >= 8 and skinned_mesh_count > 0 and has_skeletal_idle and has_skeletal_move
	var morph_animation_valid := morph_mesh_count >= 8 and has_morph_idle and has_morph_move
	if not skeletal_animation_valid and not morph_animation_valid:
		return {"ok": false, "reason": "requires bound skeletal idle/move clips or at least 8 morph meshes with semantic idle/move clips"}
	var mode := "skeletal" if skeletal_animation_valid else "morph"
	return {"ok": true, "reason": "renderable texture-backed materials and complete %s idle/move animation path present" % mode}

func _unhandled_input(event: InputEvent) -> void:
	# Short world taps move toward the ground point. UI touches are consumed
	# by Controls; camera drags are rejected by the movement threshold.
	if event is InputEventScreenTouch:
		if event.pressed:
			_world_touch_starts[event.index] = event.position
		elif _world_touch_starts.has(event.index):
			var start_position: Vector2 = _world_touch_starts[event.index]
			_world_touch_starts.erase(event.index)
			if start_position.distance_to(event.position) <= world_tap_max_drag:
				_handle_world_tap(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mouse_world_pressed = true
			_mouse_world_press_position = event.position
		elif _mouse_world_pressed:
			_mouse_world_pressed = false
			if _mouse_world_press_position.distance_to(event.position) <= world_tap_max_drag:
				_handle_world_tap(event.position)

func _handle_world_tap(screen_position: Vector2) -> void:
	if is_dead:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_end := ray_origin + camera.project_ray_normal(screen_position) * 300.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	# Ground-only picking prevents taps on actors from becoming move commands.
	query.collision_mask = 1
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var now_ms := Time.get_ticks_msec()
	var is_double_tap := (
		world_double_tap_jump
		and now_ms - _last_world_tap_ms <= world_double_tap_window_ms
		and _last_world_tap_position.distance_to(screen_position) <= 56.0
	)
	_last_world_tap_ms = -1000 if is_double_tap else now_ms
	_last_world_tap_position = screen_position
	if is_double_tap:
		perform_jump()
		return
	move_towards_target_position(hit.position, 0.0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_world_touch_starts.clear()
		_mouse_world_pressed = false
		input_direction = Vector2.ZERO

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
	_set_imported_animation_state("move" if is_moving else "idle")
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
		footstep_timer = 0.0
		if left_leg: left_leg.rotation.x = lerp(left_leg.rotation.x, 0.0, delta * 10.0)
		if right_leg: right_leg.rotation.x = lerp(right_leg.rotation.x, 0.0, delta * 10.0)
		if left_arm: left_arm.rotation.x = lerp(left_arm.rotation.x, 0.0, delta * 10.0)
		if right_arm and attack_anim_timer <= 0.0: right_arm.rotation.x = lerp(right_arm.rotation.x, 0.0, delta * 10.0)
	if is_moving and is_on_floor():
		footstep_timer = maxf(0.0, footstep_timer - delta)
		if footstep_timer <= 0.0 and GameAudioManager:
			GameAudioManager.play_sfx("footstep", self, -10.0, randf_range(0.94, 1.06))
			footstep_timer = 0.38 if is_mounted else 0.48
	move_and_slide()

func _set_imported_animation_state(state: String) -> void:
	if imported_model_animation == null or not is_instance_valid(imported_model_animation):
		return
	var preferred := ["idle", "stand"] if state == "idle" else ["run", "walk", "move"]
	var selected := ""
	for animation_name in imported_model_animation.get_animation_list():
		var normalized := animation_name.to_lower()
		for token in preferred:
			if normalized.contains(token):
				selected = animation_name
				break
		if not selected.is_empty():
			break
	# Never guess an animation from import order: C3 action clips may be
	# present without semantic names. Keep the current safe pose until a
	# verified idle/walk alias is available in the model metadata.
	if selected.is_empty():
		return
	imported_model_animation.speed_scale = 1.0 if state == "idle" else 1.2
	if selected != imported_animation_name:
		imported_animation_name = selected
		imported_model_animation.play(selected)

func set_joystick_input(vec: Vector2) -> void:
	input_direction = vec

func move_towards_target_position(pos: Vector3, _delta: float) -> void:
	target_nav_position = pos
	is_moving_to_target = true

func clear_movement_target() -> void:
	is_moving_to_target = false
	target_nav_position = global_position
	input_direction = Vector2.ZERO

func perform_jump() -> void:
	if is_on_floor() and not is_dead:
		velocity.y = jump_velocity
		if GameAudioManager:
			GameAudioManager.play_sfx("jump", self)

func toggle_mount() -> void:
	if not is_mounted:
		if not inventory:
			return
		var equipped_mount: Variant = inventory.equipment.get("mount", null)
		if not equipped_mount is Dictionary:
			if GameManager:
				GameManager.post_notification("لا توجد مطية مجهزة" if GameManager.current_language == "ar" else "No mount equipped", true)
			return
		if not mount_mesh or mount_mesh.get_node_or_null("ImportedMountRoot") == null:
			if GameManager:
				GameManager.post_notification("نموذج هذه المطية غير معتمد بعد" if GameManager.current_language == "ar" else "This mount model is not verified yet", true)
			return
	is_mounted = !is_mounted
	if mount_mesh:
		mount_mesh.visible = is_mounted
	if torso_node:
		torso_node.position.y = 1.35 if is_mounted else 0.9
	if GameManager:
		var msg = "تم امتطاء المطية المجهزة" if is_mounted else "تم الترجل عن المطية"
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
		if GameAudioManager:
			GameAudioManager.play_player_attack(self, target)
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

func _apply_mount_model() -> void:
	if not mount_mesh or not inventory:
		return
	var equipped_mount: Variant = inventory.equipment.get("mount", null)
	var mount_item_id := str(equipped_mount.get("id", "")) if equipped_mount is Dictionary else ""
	var existing_root := mount_mesh.get_node_or_null("ImportedMountRoot")
	# Never let a previously equipped mount masquerade as a newly equipped item.
	if mount_item_id != imported_mount_item_id:
		if is_mounted:
			is_mounted = false
			mount_mesh.visible = false
			if torso_node:
				torso_node.position.y = 0.9
		if existing_root:
			existing_root.queue_free()
		imported_mount_item_id = ""
	if mount_item_id.is_empty() or not AssetCatalog:
		return
	var verified_index := AssetCatalog.get_verified_mount_model_index(mount_item_id)
	if verified_index < 0:
		return
	var candidate_root := AssetCatalog.instantiate_fitted_model("mounts", verified_index, mount_mesh, 1.6, "MountCandidate")
	if candidate_root == null:
		return
	var candidate_instance: Node = candidate_root.get_child(0) if candidate_root.get_child_count() > 0 else null
	var mesh_count := 0
	if candidate_instance:
		for node in candidate_instance.find_children("*", "MeshInstance3D", true, false):
			var mesh_node := node as MeshInstance3D
			if mesh_node.mesh == null or mesh_node.mesh.get_surface_count() == 0:
				continue
			mesh_count += 1
			for surface_index in range(mesh_node.mesh.get_surface_count()):
				if mesh_node.get_active_material(surface_index) == null:
					candidate_root.queue_free()
					return
	if mesh_count == 0:
		candidate_root.queue_free()
		return
	var old_root := mount_mesh.get_node_or_null("ImportedMountRoot")
	if old_root:
		old_root.queue_free()
	candidate_root.name = "ImportedMountRoot"
	imported_mount_item_id = mount_item_id
	for child in mount_mesh.get_children():
		if child != candidate_root and child is Node3D:
			child.visible = false

func set_character_class(new_cls: String) -> void:
	if new_cls.is_empty() or new_cls == character_class:
		return
	var previous_class := character_class
	var had_imported_model := visual_root and visual_root.get_node_or_null("ImportedModelRoot") != null
	character_class = new_cls
	if ClassProgressionManager:
		ClassProgressionManager.configure_for_character(character_class)
	var replacement_applied := _apply_character_model()
	if had_imported_model and not replacement_applied:
		character_class = previous_class
		if ClassProgressionManager:
			ClassProgressionManager.configure_for_character(character_class)
		if GameManager:
			GameManager.post_notification("لا يمكن تغيير الفئة قبل اعتماد نموذجها المطابق" if GameManager.current_language == "ar" else "Class change blocked until its matching model is verified", true)
		return
	if GameManager:
		GameManager.post_notification("تم تغيير فئة البطل إلى " + new_cls, false)

func set_character_gender(new_gender: String) -> void:
	var normalized := new_gender.strip_edges().to_lower()
	if normalized not in ["male", "female"] or normalized == character_gender:
		return
	var previous_gender := character_gender
	var had_imported_model := visual_root and visual_root.get_node_or_null("ImportedModelRoot") != null
	character_gender = normalized
	var replacement_applied := _apply_character_model()
	if had_imported_model and not replacement_applied:
		character_gender = previous_gender
		if GameManager:
			GameManager.post_notification("لا يمكن تغيير النوع قبل اعتماد النموذج المطابق" if GameManager.current_language == "ar" else "Gender change blocked until its matching model is verified", true)

func select_archer_weapon_style(style_id: String) -> bool:
	if character_class != "Archer" or not ClassProgressionManager:
		return false
	return ClassProgressionManager.select_weapon_style(style_id)

func select_progression_choice(choice_id: String) -> bool:
	if not ClassProgressionManager:
		return false
	var selected := ClassProgressionManager.select_progression_choice(choice_id)
	if selected and GameManager:
		var message := ClassProgressionManager.get_selection_message(choice_id, GameManager.current_language)
		if not message.is_empty():
			GameManager.post_notification(message, false)
	return selected

func get_available_progression_choices() -> Array[String]:
	return ClassProgressionManager.get_available_progression_choices() if ClassProgressionManager else []

func get_selected_progression_choice() -> String:
	return ClassProgressionManager.get_selected_progression_choice() if ClassProgressionManager else ""

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
	if GameAudioManager:
		GameAudioManager.play_sfx("hit", self, -4.0)
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
	if GameAudioManager:
		GameAudioManager.play_sfx("level_up", self)
	max_hp += 80
	current_hp = max_hp
	max_mp += 40
	current_mp = max_mp
	base_attack += 8
	base_defense += 4
	max_xp = int(max_xp * 1.35)
	if ClassProgressionManager:
		if ClassProgressionManager.refresh_level_unlocks(current_level) and GameManager:
			var unlock_message := ClassProgressionManager.get_last_unlock_message(GameManager.current_language)
			if not unlock_message.is_empty():
				GameManager.post_notification(unlock_message, false)
	for agent in get_tree().get_nodes_in_group("quest_agents"):
		if agent.has_method("on_level_reached"):
			agent.on_level_reached(current_level)
	if GameManager:
		var txt = "تهانينا! ارتقيت إلى المستوى %d!" % current_level
		GameManager.post_notification(txt if GameManager.current_language == "ar" else ("Level Up! Level %d" % current_level), false)

func _on_death(_killer: Node3D) -> void:
	is_dead = true
	if GameAudioManager:
		GameAudioManager.play_sfx("death", self)
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
	var travel_manager := get_tree().get_first_node_in_group("world_travel_manager")
	if travel_manager and travel_manager.has_method("travel_to"):
		travel_manager.travel_to("twin_city", "respawn")
	else:
		global_position = Vector3(0, 1.0, 0)
	sync_stats_to_hud()

func sync_stats_to_hud() -> void:
	if GameManager:
		var gold = GameManager.current_gold
		GameManager.emit_signal("player_stats_changed", current_hp, max_hp, current_mp, max_mp, current_xp, max_xp, current_level, gold)

func _apply_weapon_model() -> void:
	if not weapon_mount or not inventory or not AssetCatalog:
		return
	var equipped_weapon: Variant = inventory.equipment.get("weapon", null)
	var item_id := str(equipped_weapon.get("id", "")) if equipped_weapon is Dictionary else ""
	var existing_root := weapon_mount.get_node_or_null("ImportedWeaponRoot")
	if item_id != imported_weapon_item_id:
		if existing_root:
			existing_root.queue_free()
			imported_weapon_item_id = ""
			_set_placeholder_weapon_visible(true)
			call_deferred("_apply_weapon_model")
			return
		imported_weapon_item_id = ""
	if item_id.is_empty():
		_set_placeholder_weapon_visible(true)
		return
	var verified_index := AssetCatalog.get_verified_weapon_model_index(item_id)
	if verified_index < 0:
		_set_placeholder_weapon_visible(true)
		return
	if weapon_mount.get_node_or_null("ImportedWeaponRoot") != null:
		_set_placeholder_weapon_visible(false)
		return
	var candidate_root := AssetCatalog.instantiate_fitted_weapon_model(item_id, weapon_mount, 0.95)
	if candidate_root == null:
		push_warning("Weapon visual candidate could not be instantiated; retaining placeholder.")
		_set_placeholder_weapon_visible(true)
		return
	candidate_root.name = "ImportedWeaponRoot"
	imported_weapon_item_id = item_id
	_set_placeholder_weapon_visible(false)
	call_deferred("_apply_refinement_glow")

func _set_placeholder_weapon_visible(visible_state: bool) -> void:
	if not weapon_mount:
		return
	var placeholder := weapon_mount.get_node_or_null("MainWeapon")
	if placeholder is Node3D:
		placeholder.visible = visible_state
