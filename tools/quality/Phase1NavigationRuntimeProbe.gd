extends SceneTree

const WORLD_SCENE_PATH := "res://scenes/world/JianghaiOldCity.tscn"
const PLAYER_SCENE_PATH := "res://scenes/characters/Player.tscn"
const REPORT_PATH := "reports/phase1_navigation_runtime_probe.json"
const START_POSITION := Vector3(0.0, -0.14, -60.0)
const TARGET_POSITION := Vector3(-9.5, -0.14, -34.5)
const MAX_TEST_FRAMES := 1200

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world_packed := load(WORLD_SCENE_PATH) as PackedScene
	if world_packed == null:
		_fail("Saved Jianghai runtime scene could not be loaded.")
		return
	var world := world_packed.instantiate() as Node3D
	if world == null:
		_fail("Saved Jianghai runtime scene did not instantiate as Node3D.")
		return
	root.add_child(world)
	for _frame in range(4):
		await physics_frame

	var player_packed := load(PLAYER_SCENE_PATH) as PackedScene
	if player_packed == null:
		_fail("Player scene could not be loaded.")
		return
	var player := player_packed.instantiate() as CharacterBody3D
	if player == null:
		_fail("Player scene did not instantiate as CharacterBody3D.")
		return
	world.add_child(player)
	player.global_position = START_POSITION
	for _frame in range(8):
		await physics_frame

	var navigation_agent := player.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if navigation_agent == null:
		_fail("Player has no NavigationAgent3D child.")
		return
	var navigation_map := navigation_agent.get_navigation_map()
	if not navigation_map.is_valid():
		_fail("Player navigation agent has no valid navigation map.")
		return
	var map_cell_height := NavigationServer3D.map_get_cell_height(navigation_map)
	var expected_cell_height := float(ProjectSettings.get_setting("navigation/3d/default_cell_height", 0.25))
	var map_region_count := NavigationServer3D.map_get_regions(navigation_map).size()
	var projected_target := NavigationServer3D.map_get_closest_point(navigation_map, TARGET_POSITION)

	player.call("move_towards_target_position", TARGET_POSITION, 1.0 / 60.0)
	for _frame in range(3):
		await physics_frame
	var path_waypoint_count := navigation_agent.get_current_navigation_path().size()
	var start_after_settle := player.global_position
	var initial_floor_contact := player.is_on_floor()
	var frames_used := 0
	for frame in range(MAX_TEST_FRAMES):
		await physics_frame
		frames_used = frame + 1
		if not bool(player.get("is_moving_to_target")):
			break

	var final_position := player.global_position
	var horizontal_distance_to_target := Vector2(
		final_position.x - projected_target.x,
		final_position.z - projected_target.z
	).length()
	var horizontal_displacement := Vector2(
		final_position.x - start_after_settle.x,
		final_position.z - start_after_settle.z
	).length()
	var final_floor_contact := player.is_on_floor()
	var target_reached := horizontal_distance_to_target <= 1.5
	var report := {
		"world_scene_loaded": true,
		"player_scene_loaded": true,
		"navigation_map_valid": navigation_map.is_valid(),
		"navigation_map_region_count": map_region_count,
		"navigation_map_cell_height": map_cell_height,
		"project_default_cell_height": expected_cell_height,
		"navigation_cell_height_matches": is_equal_approx(map_cell_height, expected_cell_height),
		"path_waypoint_count": path_waypoint_count,
		"start_position": _vec(start_after_settle),
		"requested_target_position": _vec(TARGET_POSITION),
		"projected_target_position": _vec(projected_target),
		"final_player_position": _vec(final_position),
		"horizontal_displacement": horizontal_displacement,
		"horizontal_distance_to_projected_target": horizontal_distance_to_target,
		"initial_floor_contact": initial_floor_contact,
		"final_floor_contact": final_floor_contact,
		"target_reached": target_reached,
		"frames_used": frames_used
	}
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		_fail("Could not write runtime probe report.")
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("PHASE1 NAVIGATION RUNTIME PROBE: ", JSON.stringify(report))

	if map_region_count < 1:
		_fail("Runtime navigation map contains no registered regions.")
		return
	if not is_equal_approx(map_cell_height, expected_cell_height):
		_fail("Runtime navigation map cell height does not match project settings.")
		return
	if path_waypoint_count < 2:
		_fail("Player NavigationAgent3D did not receive a usable path.")
		return
	if horizontal_displacement < 8.0 or not target_reached:
		_fail("Player did not follow the baked navigation path to the hotel frontage.")
		return
	if not final_floor_contact or final_position.y < -1.0:
		_fail("Player did not remain supported by the generated walkable floor collisions.")
		return

	print("PHASE1 NAVIGATION PLAYER MOVEMENT AND FLOOR COLLISION: PASS")
	quit(0)

func _vec(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _fail(message: String) -> void:
	push_error("PHASE1 NAVIGATION RUNTIME PROBE FAILED: " + message)
	quit(1)
