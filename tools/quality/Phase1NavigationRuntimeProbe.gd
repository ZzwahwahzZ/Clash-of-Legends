extends SceneTree

const WORLD_SCENE_PATH := "res://scenes/world/JianghaiOldCity.tscn"
const PLAYER_SCENE_PATH := "res://scenes/characters/Player.tscn"
const REPORT_PATH := "reports/phase1_navigation_runtime_probe.json"
const WORLD_INTERACTION_REGISTRY_SCRIPT := preload("res://scripts/world/WorldInteractionRegistry.gd")
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

	var pawnshop_doorway_clear := _ray_is_clear(Vector3(-86.0, 1.0, -115.0), Vector3(-86.0, 1.0, -109.0))
	var factory_doorway_clear := _ray_is_clear(Vector3(86.0, 1.0, -11.0), Vector3(86.0, 1.0, -5.0))
	var pawnshop_wall_blocks := _ray_hits_collision(Vector3(-88.5, 1.0, -115.0), Vector3(-88.5, 1.0, -109.0))
	var factory_wall_blocks := _ray_hits_collision(Vector3(83.5, 1.0, -11.0), Vector3(83.5, 1.0, -5.0))
	var collision_probe_passed := pawnshop_doorway_clear and factory_doorway_clear and pawnshop_wall_blocks and factory_wall_blocks
	if not collision_probe_passed:
		push_warning("One or more physical building collision checks failed; continuing the integrated suite to collect all results.")

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
	var authored_city := world.get_node_or_null("AuthoredCity") as Node3D
	var interaction_registry = WORLD_INTERACTION_REGISTRY_SCRIPT.new()
	var interaction_registry_bound := authored_city != null and interaction_registry.bind_world(authored_city)

	# Geometry-only movement samples in an unverified authored environment.
	# These points are not Conquer Mobile destinations or quest targets.
	var runtime_route_targets := {
		"engineering_sample_01": Vector3(-86.0, -0.078, -106.0),
		"engineering_sample_02": Vector3(86.0, -0.078, -12.0),
		"engineering_sample_03": Vector3(11.6, -0.045, -48.0),
		"engineering_sample_04": Vector3(9.5, -0.14, -8.0)
	}
	var runtime_route_checks: Array[Dictionary] = []
	for route_id in runtime_route_targets:
		var route_target: Vector3 = runtime_route_targets[route_id]
		navigation_agent.target_position = NavigationServer3D.map_get_closest_point(navigation_map, route_target)
		var runtime_path: PackedVector3Array = PackedVector3Array()
		for _sync_frame in range(5):
			await physics_frame
			navigation_agent.get_next_path_position()
			runtime_path = navigation_agent.get_current_navigation_path()
		runtime_route_checks.append({
			"route": route_id,
			"waypoint_count": runtime_path.size(),
			"path_valid": runtime_path.size() >= 2
		})
	var runtime_routes_passed := 0
	for route_check in runtime_route_checks:
		if bool(route_check["path_valid"]):
			runtime_routes_passed += 1

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
	var horizontal_distance_to_target := Vector2(final_position.x - projected_target.x, final_position.z - projected_target.z).length()
	var horizontal_displacement := Vector2(final_position.x - start_after_settle.x, final_position.z - start_after_settle.z).length()
	var final_floor_contact := player.is_on_floor()
	var target_reached := horizontal_distance_to_target <= 1.5

	var runtime_route_movement_checks: Array[Dictionary] = []
	for route_id in runtime_route_targets:
		player.call("clear_movement_target")
		player.velocity = Vector3.ZERO
		player.global_position = START_POSITION
		for _reset_frame in range(8):
			await physics_frame
		var route_target: Vector3 = NavigationServer3D.map_get_closest_point(navigation_map, runtime_route_targets[route_id])
		player.call("move_towards_target_position", route_target, 1.0 / 60.0)
		var route_frames_used := 0
		for route_frame in range(1800):
			await physics_frame
			route_frames_used = route_frame + 1
			var route_distance := Vector2(player.global_position.x - route_target.x, player.global_position.z - route_target.z).length()
			if route_distance <= 1.5 or not bool(player.get("is_moving_to_target")):
				break
		var route_final_position: Vector3 = player.global_position
		var route_final_distance := Vector2(route_final_position.x - route_target.x, route_final_position.z - route_target.z).length()
		runtime_route_movement_checks.append({
			"route": route_id,
			"target_reached": route_final_distance <= 1.5,
			"horizontal_distance_to_target": route_final_distance,
			"horizontal_displacement": Vector2(route_final_position.x - START_POSITION.x, route_final_position.z - START_POSITION.z).length(),
			"floor_contact": player.is_on_floor(),
			"frames_used": route_frames_used
		})
	var runtime_route_movements_passed := 0
	for movement_check in runtime_route_movement_checks:
		if bool(movement_check["target_reached"]) and bool(movement_check["floor_contact"]):
			runtime_route_movements_passed += 1


	var report := {
		"world_scene_loaded": true,
		"pawnshop_doorway_clear": pawnshop_doorway_clear,
		"factory_doorway_clear": factory_doorway_clear,
		"pawnshop_adjacent_wall_blocks": pawnshop_wall_blocks,
		"factory_adjacent_wall_blocks": factory_wall_blocks,
		"collision_probe_passed": collision_probe_passed,
		"player_scene_loaded": true,
		"navigation_map_valid": navigation_map.is_valid(),
		"navigation_map_region_count": map_region_count,
		"navigation_map_cell_height": map_cell_height,
		"interaction_registry_bound": interaction_registry_bound,
		"semantic_gameplay_validation": false,
		"world_identity_verified_as_conquer_mobile": false,
		"project_default_cell_height": expected_cell_height,
		"navigation_cell_height_matches": is_equal_approx(map_cell_height, expected_cell_height),
		"path_waypoint_count": path_waypoint_count,
		"runtime_route_checks": runtime_route_checks,
		"runtime_routes_passed": runtime_routes_passed,
		"runtime_route_movement_checks": runtime_route_movement_checks,
		"runtime_route_movements_passed": runtime_route_movements_passed,
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

	if not collision_probe_passed:
		_fail("Physical collision suite failed: " + JSON.stringify({
			"pawnshop_doorway_clear": pawnshop_doorway_clear,
			"factory_doorway_clear": factory_doorway_clear,
			"pawnshop_adjacent_wall_blocks": pawnshop_wall_blocks,
			"factory_adjacent_wall_blocks": factory_wall_blocks,
		}))
		return
	if map_region_count < 1:
		_fail("Runtime navigation map contains no registered regions.")
		return
	if not interaction_registry_bound:
		_fail("World interaction registry could not bind the authored city.")
		return
	if not is_equal_approx(map_cell_height, expected_cell_height):
		_fail("Runtime navigation map cell height does not match project settings.")
		return
	if path_waypoint_count < 2:
		_fail("Player NavigationAgent3D did not receive a usable path.")
		return
	if runtime_routes_passed != runtime_route_targets.size():
		_fail("Player NavigationAgent3D could not resolve an authored city approach route: " + JSON.stringify(runtime_route_checks))
		return
	if runtime_route_movements_passed != runtime_route_targets.size():
		_fail("Player did not physically reach every verified city destination: " + JSON.stringify(runtime_route_movement_checks))
		return

	if horizontal_displacement < 8.0 or not target_reached:
		_fail("Player did not follow the baked navigation path to the hotel frontage.")
		return
	if not final_floor_contact or final_position.y < -1.0:
		_fail("Player did not remain supported by the generated walkable floor collisions.")
		return

	print("PHASE1 AUTHORED-ENVIRONMENT GEOMETRY MOVEMENT AND FLOOR COLLISION: PASS")
	quit(0)

func _ray_is_clear(from_position: Vector3, to_position: Vector3) -> bool:
	return _ray_result(from_position, to_position).is_empty()

func _ray_hits_collision(from_position: Vector3, to_position: Vector3) -> bool:
	return not _ray_result(from_position, to_position).is_empty()

func _ray_result(from_position: Vector3, to_position: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from_position, to_position, 1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_root().world_3d.direct_space_state.intersect_ray(query)

func _capture_slide_collisions(body: CharacterBody3D) -> Array:
	var collisions: Array = []
	for index in range(body.get_slide_collision_count()):
		var slide := body.get_slide_collision(index)
		var collider := slide.get_collider()
		collisions.append({
			"collider": str(collider.name) if collider else "null",
			"position": _vec(slide.get_position()),
			"normal": _vec(slide.get_normal())
		})
	return collisions

func _path_length(path: PackedVector3Array) -> float:
	var total := 0.0
	for index in range(1, path.size()):
		total += path[index - 1].distance_to(path[index])
	return total

func _vec(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _fail(message: String) -> void:
	push_error("PHASE1 NAVIGATION RUNTIME PROBE FAILED: " + message)
	quit(1)
