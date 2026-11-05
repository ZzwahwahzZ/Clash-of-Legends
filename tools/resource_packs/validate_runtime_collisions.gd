extends SceneTree

func _initialize() -> void:
	call_deferred("_run_collision_test")

func _run_collision_test() -> void:
	var world_root := Node3D.new()
	get_root().add_child(world_root)
	var player_scene := ResourceLoader.load("res://scenes/characters/Player.tscn") as PackedScene
	var wolf_scene := ResourceLoader.load("res://scenes/enemies/WildWolf.tscn") as PackedScene
	if player_scene == null or wolf_scene == null:
		_fail("Could not load Player and WildWolf scenes.")
		return
	var player := player_scene.instantiate() as CharacterBody3D
	var wolf := wolf_scene.instantiate() as CharacterBody3D
	if player == null or wolf == null:
		_fail("Player or WildWolf scene root is not CharacterBody3D.")
		return
	player.position = Vector3(0.0, 0.0, 0.0)
	wolf.position = Vector3(2.4, 0.0, 0.0)
	world_root.add_child(player)
	world_root.add_child(wolf)
	await physics_frame
	var initial_gap := wolf.global_position.x - player.global_position.x
	var collision := player.move_and_collide(Vector3(4.0, 0.0, 0.0), false, 0.001, true)
	await physics_frame
	if collision == null:
		_fail("Player passed through a stationary WildWolf; runtime collision was not detected.")
		return
	var final_gap := wolf.global_position.x - player.global_position.x
	if final_gap <= 0.0 or player.global_position.x >= wolf.global_position.x:
		_fail("Player crossed the WildWolf collision body.")
		return
	print("RUNTIME COLLISION OK: Player stopped before WildWolf | initial_gap=", initial_gap, " | final_gap=", final_gap, " | normal=", collision.get_normal())
	player.queue_free()
	wolf.queue_free()
	world_root.queue_free()
	print("RUNTIME COLLISION AUDIT PASSED: moving Player collided with stationary WildWolf without passing through.")
	quit(0)

func _fail(message: String) -> void:
	push_error("RUNTIME COLLISION AUDIT FAILED: " + message)
	quit(1)
