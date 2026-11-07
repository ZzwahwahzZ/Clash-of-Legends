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
	var bridge_rail := world.find_child("MarketRail_-123_95_4_85", true, false) as MeshInstance3D
	var bridge_rail_blocks := false
	var bridge_rail_hit_name := "rail_mesh_not_found"
	if bridge_rail != null and bridge_rail.mesh != null:
		var rail_world_bounds: AABB = bridge_rail.global_transform * bridge_rail.get_aabb()
		var rail_center := rail_world_bounds.get_center()
		var rail_hit := _ray_result(rail_center + Vector3(0.0, 0.0, 1.0), rail_center - Vector3(0.0, 0.0, 1.0))
		if not rail_hit.is_empty():
			bridge_rail_hit_name = str((rail_hit.get("collider") as Node).name)
		bridge_rail_blocks = bridge_rail_hit_name == "MarketBridgeRailCollision"
	print("PHASE1 BUILDING DOORWAY COLLISION PROBE: ", JSON.stringify({
		"pawnshop_doorway_clear": pawnshop_doorway_clear,
		"factory_doorway_clear": factory_doorway_clear,
		"pawnshop_adjacent_wall_blocks": pawnshop_wall_blocks,
		"factory_adjacent_wall_blocks": factory_wall_blocks,
		"market_bridge_guardrail_blocks": bridge_rail_blocks,
		"market_bridge_guardrail_hit_collider": bridge_rail_hit_name
	}))
	var collision_probe_passed := pawnshop_doorway_clear and factory_doorway_clear and pawnshop_wall_blocks and factory_wall_blocks and bridge_rail_blocks
	if not collision_probe_passed:
		push_warning("One or more physical collision checks failed; continuing the complete player/navigation suite to collect all results.")

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
	var bridge_landmark_route: Dictionary = interaction_registry.get_navigation_path("jianghai.market_bridge", START_POSITION, navigation_map) if interaction_registry_bound else {"ok": false, "reason": "registry_bind_failed"}
	var bridge_landmark_rejected := not bool(bridge_landmark_route.get("ok", false)) and str(bridge_landmark_route.get("reason", "")) == "anchor_is_landmark_not_navigation_target"

	# Verify authored city destinations at runtime. The former market_bridge_west_approach
	# pointed at a decorative ramp and is intentionally excluded until a real West Market
	# walkable entry is geometrically verified; nearest-point projection is not route proof.
	var runtime_route_targets := {
		"pawnshop_approach": Vector3(-86.0, -0.078, -106.0),
		"factory_approach": Vector3(86.0, -0.078, -12.0),
		"medicine_frontage": Vector3(11.6, -0.045, -48.0),
		"tea_frontage": Vector3(9.5, -0.14, -8.0)
	}
	var runtime_route_checks: Array[Dictionary] = []
	for route_id in runtime_route_targets:
		var route_target: Vector3 = runtime_route_targets[route_id]
		navigation_agent.target_position = NavigationServer3D.map_get_closest_point(navigation_map, route_target)
		var runtime_path: PackedVector3Array = PackedVector3Array()
		for _sync_frame in range(5):
			await physics_frame
			# NavigationAgent3D advances its path cache when this is queried
			# during physics processing; waiting alone leaves the path empty.
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
	# Path resolution alone is not enough: drive the actual CharacterBody3D
	# independently from the central avenue to both building approaches.
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

	# Prove traversal across the authored bridge deck only.
	# The decorative ramps are not walkable navigation surfaces or quest destinations.
	# Cross from the eastern deck end toward the western deck end. Stop on the
	# authored deck: do not route over either decorative ramp.
	var bridge_cross_start_requested := Vector3(21.0, 4.45, -126.0)
	var bridge_cross_target_requested := Vector3(-21.0, 4.45, -126.0)
	var bridge_cross_start := NavigationServer3D.map_get_closest_point(navigation_map, bridge_cross_start_requested)
	var bridge_cross_target := NavigationServer3D.map_get_closest_point(navigation_map, bridge_cross_target_requested)
	var bridge_cross_start_projection_distance := bridge_cross_start.distance_to(bridge_cross_start_requested)
	var bridge_cross_target_projection_distance := bridge_cross_target.distance_to(bridge_cross_target_requested)
	player.call("clear_movement_target")
	player.velocity = Vector3.ZERO
	player.global_position = bridge_cross_start
	for _reset_frame in range(8):
		await physics_frame
	navigation_agent.target_position = bridge_cross_target
	var bridge_cross_path := PackedVector3Array()
	for _sync_frame in range(5):
		await physics_frame
		navigation_agent.get_next_path_position()
		bridge_cross_path = navigation_agent.get_current_navigation_path()
	player.call("move_towards_target_position", bridge_cross_target, 1.0 / 60.0)
	var bridge_cross_frames := 0
	for bridge_frame in range(2400):
		await physics_frame
		bridge_cross_frames = bridge_frame + 1
		var bridge_distance := Vector2(player.global_position.x - bridge_cross_target.x, player.global_position.z - bridge_cross_target.z).length()
		if bridge_distance <= 1.5 or not bool(player.get("is_moving_to_target")):
			break
	var bridge_cross_final_position: Vector3 = player.global_position
	var bridge_cross_distance := Vector2(bridge_cross_final_position.x - bridge_cross_target.x, bridge_cross_final_position.z - bridge_cross_target.z).length()
	var bridge_cross_floor_contact := player.is_on_floor()
	var bridge_cross_waypoints: Array = []
	for waypoint in bridge_cross_path:
		bridge_cross_waypoints.append(_vec(waypoint))
	var bridge_cross_slide_collisions: Array = []
	for collision_index in range(player.get_slide_collision_count()):
		var slide := player.get_slide_collision(collision_index)
		var collider := slide.get_collider()
		bridge_cross_slide_collisions.append({
			"collider": str(collider.name) if collider else "null",
			"position": _vec(slide.get_position()),
			"normal": _vec(slide.get_normal())
		})
	var bridge_cross_next_path_position: Vector3 = navigation_agent.get_next_path_position()
	var bridge_cross_passed := bridge_cross_path.size() >= 2 and bridge_cross_start_projection_distance <= 2.0 and bridge_cross_target_projection_distance <= 2.0 and bridge_cross_distance <= 1.5 and bridge_cross_floor_contact

	var report := {
		"world_scene_loaded": true,
		"pawnshop_doorway_clear": pawnshop_doorway_clear,
		"factory_doorway_clear": factory_doorway_clear,
		"pawnshop_adjacent_wall_blocks": pawnshop_wall_blocks,
		"factory_adjacent_wall_blocks": factory_wall_blocks,
		"market_bridge_guardrail_blocks": bridge_rail_blocks,
		"market_bridge_guardrail_hit_collider": bridge_rail_hit_name,
		"collision_probe_passed": collision_probe_passed,
		"player_scene_loaded": true,
		"navigation_map_valid": navigation_map.is_valid(),
		"navigation_map_region_count": map_region_count,
		"navigation_map_cell_height": map_cell_height,
		"interaction_registry_bound": interaction_registry_bound,
		"bridge_landmark_route_rejected": bridge_landmark_rejected,
		"bridge_landmark_route_result": bridge_landmark_route,
		"west_market_route_status": "NOT_TESTED_NO_VERIFIED_WALKABLE_ENTRY_ANCHOR",
		"project_default_cell_height": expected_cell_height,
		"navigation_cell_height_matches": is_equal_approx(map_cell_height, expected_cell_height),
		"path_waypoint_count": path_waypoint_count,
		"runtime_route_checks": runtime_route_checks,
		"runtime_routes_passed": runtime_routes_passed,
		"runtime_route_movement_checks": runtime_route_movement_checks,
		"runtime_route_movements_passed": runtime_route_movements_passed,
		"market_bridge_crossing": {
			"start_requested": _vec(bridge_cross_start_requested),
			"start_projected": _vec(bridge_cross_start),
			"start_projection_distance": bridge_cross_start_projection_distance,
			"target_requested": _vec(bridge_cross_target_requested),
			"target_projected": _vec(bridge_cross_target),
			"target_projection_distance": bridge_cross_target_projection_distance,
			"path_waypoint_count": bridge_cross_path.size(),
			"path_waypoints": bridge_cross_waypoints,
			"next_path_position_at_finish": _vec(bridge_cross_next_path_position),
			"player_velocity_at_finish": _vec(player.velocity),
			"is_moving_to_target_at_finish": bool(player.get("is_moving_to_target")),
			"slide_collisions_at_finish": bridge_cross_slide_collisions,
			"final_position": _vec(bridge_cross_final_position),
			"distance_to_target": bridge_cross_distance,
			"floor_contact": bridge_cross_floor_contact,
			"frames_used": bridge_cross_frames,
			"passed": bridge_cross_passed
		},
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
			"market_bridge_guardrail_blocks": bridge_rail_blocks,
			"market_bridge_guardrail_hit_collider": bridge_rail_hit_name
		}))
		return
	if map_region_count < 1:
		_fail("Runtime navigation map contains no registered regions.")
		return
	if not interaction_registry_bound or not bridge_landmark_rejected:
		_fail("Market bridge landmark was incorrectly exposed as a navigation destination: " + JSON.stringify(bridge_landmark_route))
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
	if not bridge_cross_passed:
		_fail("Player could not physically cross the authored market bridge deck (ramps are excluded): " + JSON.stringify({
			"path_waypoint_count": bridge_cross_path.size(),
			"start_projection_distance": bridge_cross_start_projection_distance,
			"target_projection_distance": bridge_cross_target_projection_distance,
			"distance_to_target": bridge_cross_distance,
			"floor_contact": bridge_cross_floor_contact,
			"final_position": _vec(bridge_cross_final_position)
		}))
		return
	if horizontal_displacement < 8.0 or not target_reached:
		_fail("Player did not follow the baked navigation path to the hotel frontage.")
		return
	if not final_floor_contact or final_position.y < -1.0:
		_fail("Player did not remain supported by the generated walkable floor collisions.")
		return

	print("PHASE1 NAVIGATION PLAYER MOVEMENT, CITY ROUTES, BUILDING APPROACHES AND FLOOR COLLISION: PASS")
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

func _vec(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _fail(message: String) -> void:
	push_error("PHASE1 NAVIGATION RUNTIME PROBE FAILED: " + message)
	quit(1)
