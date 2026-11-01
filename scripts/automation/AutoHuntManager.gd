extends Node

signal auto_hunt_toggled(is_enabled: bool)

var is_enabled: bool = false
var search_radius: float = 24.0
var target_enemy: Node3D = null
var skill_check_timer: float = 0.0

func _ready() -> void:
	pass

func toggle_auto_hunt() -> bool:
	is_enabled = !is_enabled
	if GameManager:
		GameManager.is_auto_hunting = is_enabled
		var text_ar = "تم تفعيل وضع الصيد التلقائي" if is_enabled else "تم إيقاف وضع الصيد التلقائي"
		var text_en = "Auto-Hunt Enabled" if is_enabled else "Auto-Hunt Disabled"
		GameManager.post_notification(text_ar if GameManager.current_language == "ar" else text_en, false)
	emit_signal("auto_hunt_toggled", is_enabled)
	return is_enabled

func set_enabled(value: bool) -> void:
	if is_enabled != value:
		toggle_auto_hunt()

func _physics_process(delta: float) -> void:
	if not is_enabled:
		return
		
	var player = GameManager.player_reference if GameManager else null
	if not player or not is_instance_valid(player) or player.is_dead:
		return
		
	if not target_enemy or not is_instance_valid(target_enemy) or (target_enemy.has_method("is_dead_state") and target_enemy.is_dead_state()):
		target_enemy = _find_nearest_enemy(player.global_position)
		if GameManager:
			GameManager.current_target = target_enemy
			
	if target_enemy and is_instance_valid(target_enemy):
		var dist = player.global_position.distance_to(target_enemy.global_position)
		if dist > 2.8:
			# Guide player towards enemy
			if player.has_method("move_towards_target_position"):
				player.move_towards_target_position(target_enemy.global_position, delta)
		else:
			# In range: attack and execute skills
			if player.has_method("execute_basic_attack"):
				player.execute_basic_attack()
				
			skill_check_timer += delta
			if skill_check_timer > 1.2:
				skill_check_timer = 0.0
				_try_use_class_skills(player, target_enemy)

func _find_nearest_enemy(from_pos: Vector3) -> Node3D:
	var tree = get_tree()
	if not tree:
		return null
	var enemies = tree.get_nodes_in_group("enemies")
	var nearest: Node3D = null
	var min_dist: float = search_radius
	
	for enemy in enemies:
		if is_instance_valid(enemy):
			if enemy.has_method("is_dead_state") and enemy.is_dead_state():
				continue
			var d = from_pos.distance_to(enemy.global_position)
			if d < min_dist:
				min_dist = d
				nearest = enemy
	return nearest

func _try_use_class_skills(player: CharacterBody3D, target: Node3D) -> void:
	if not CombatEngine:
		return
	var cls = player.get_character_class() if player.has_method("get_character_class") else "Trojan"
	var skills = CombatEngine.get_class_skills(cls)
	for s_id in skills:
		if CombatEngine.can_cast_skill(s_id, player):
			CombatEngine.execute_skill(s_id, player, target)
			break
