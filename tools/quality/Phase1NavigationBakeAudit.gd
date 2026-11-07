extends SceneTree

## Builds a deliberately curated navigation mesh from authored walkable street
## surfaces only. Buildings, props, vegetation, and open terrain are excluded.
## This is an audit/bake tool; it does not enable NPC spawning or modify gameplay.

const CITY_PATH := "res://assets/environment/phase1/jianghai/full_city_preview.glb"
const REPORT_PATH := "reports/phase1_navigation_bake_audit.json"
const NAVMESH_PATH := "res://assets/environment/phase1/jianghai/jianghai_city_navmesh.tres"
const WORLD_SCENE_PATH := "res://scenes/world/JianghaiOldCity.tscn"
const WALKABLE_PATHS := [
	"JianghaiOldCityAuthoredScene/AuthoredStreetNetwork/CentralAvenue",
	"JianghaiOldCityAuthoredScene/AuthoredStreetNetwork/RiverWardStreet",
	"JianghaiOldCityAuthoredScene/AuthoredStreetNetwork/NorthCrossStreet",
	"JianghaiOldCityAuthoredScene/AuthoredStreetNetwork/SouthCrossStreet",
	"JianghaiOldCityAuthoredScene/AuthoredStreetNetwork/ExtractionSquare",
	"JianghaiOldCityAuthoredScene/AuthoredStreetNetwork/PawnshopApproach",
	"JianghaiOldCityAuthoredScene/AuthoredStreetNetwork/FactoryApproach",
	"JianghaiOldCityAuthoredScene/OldCityMarketBridge/MarketBridgeDeck",
	"JianghaiOldCityAuthoredScene/OldCityMarketBridge/MarketEastRamp",
	"JianghaiOldCityAuthoredScene/OldCityMarketBridge/MarketWestRamp"
]
const NPC_SPAWN_CANDIDATES := {
	"npc_jianghai_pawnshop": Vector3(-86.0, -0.078, -101.0),
	"npc_jianghai_innkeeper": Vector3(-8.7, -0.14, -34.5),
	"npc_jianghai_apothecary": Vector3(13.0, -0.045, -48.0),
	"npc_jianghai_tea_merchant": Vector3(8.7, -0.14, -8.0)
}
const ANCHORS := {
	"jianghai.central_avenue": Vector3(0.0, -0.14, -60.0),
	"jianghai.pawnshop_approach": Vector3(-86.0, -0.078, -106.0),
	"jianghai.factory_approach": Vector3(86.0, -0.078, -12.0),
	"jianghai.market_bridge": Vector3(0.0, 4.18, -126.0),
	"jianghai.hotel_frontage": Vector3(-9.5, -0.14, -34.5),
	"jianghai.medicine_frontage": Vector3(11.6, -0.045, -48.0),
	"jianghai.tea_frontage": Vector3(9.5, -0.14, -8.0)
}

var _city: Node3D
var _region: NavigationRegion3D
var _navigation_mesh: NavigationMesh
var _source_geometry: NavigationMeshSourceGeometryData3D
var _selected_sources: Array[String] = []
var _walkable_collision_count := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://reports")
	var packed := load(CITY_PATH) as PackedScene
	if packed == null:
		_fail("Could not load city GLB.")
		return
	_city = packed.instantiate() as Node3D
	if _city == null:
		_fail("City root is not Node3D.")
		return
	get_root().add_child(_city)
	await process_frame

	for relative_path in WALKABLE_PATHS:
		var source := _city.get_node_or_null(NodePath(relative_path)) as MeshInstance3D
		if source == null or source.mesh == null:
			_fail("Missing curated walkable mesh: " + relative_path)
			return
		source.add_to_group("jianghai_nav_walkable")
		_selected_sources.append(relative_path)

	_navigation_mesh = NavigationMesh.new()
	_navigation_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_EXPLICIT
	_navigation_mesh.geometry_source_group_name = &"jianghai_nav_walkable"
	_navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_MESH_INSTANCES
	_navigation_mesh.sample_partition_type = NavigationMesh.SAMPLE_PARTITION_LAYERS
	_navigation_mesh.agent_radius = 0.5
	_navigation_mesh.agent_height = 1.8
	_navigation_mesh.agent_max_climb = 0.45
	_navigation_mesh.agent_max_slope = 38.0
	_navigation_mesh.cell_size = 0.25
	_navigation_mesh.cell_height = 0.25
	_navigation_mesh.filter_ledge_spans = true
	_navigation_mesh.filter_walkable_low_height_spans = true
	_navigation_mesh.region_min_size = 1.0
	_navigation_mesh.region_merge_size = 12.0

	_region = NavigationRegion3D.new()
	_region.name = "JianghaiCuratedNavigationAudit"
	_region.navigation_mesh = _navigation_mesh
	_city.add_child(_region)

	_source_geometry = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(
		_navigation_mesh,
		_source_geometry,
		_city,
		Callable(self, "_on_source_geometry_parsed")
	)

func _on_source_geometry_parsed() -> void:
	NavigationServer3D.bake_from_source_geometry_data_async(
		_navigation_mesh,
		_source_geometry,
		Callable(self, "_on_navigation_baked")
	)

func _on_navigation_baked() -> void:
	if _navigation_mesh.get_polygon_count() <= 0:
		_fail("Navigation bake produced zero polygons.")
		return
	var navmesh_save_error := ResourceSaver.save(_navigation_mesh, NAVMESH_PATH)
	if navmesh_save_error != OK:
		_fail("Could not save baked navigation resource: " + str(navmesh_save_error))
		return
	var world_scene_save_error := _save_world_scene()
	if world_scene_save_error != OK:
		_fail("Could not save Jianghai runtime world scene: " + str(world_scene_save_error))
		return
	_region.navigation_mesh = _navigation_mesh
	call_deferred("_validate_navigation_after_sync")

func _save_world_scene() -> int:
	var world_directory := ProjectSettings.globalize_path("res://scenes/world")
	var directory_error := DirAccess.make_dir_recursive_absolute(world_directory)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return directory_error
	var root := Node3D.new()
	root.name = "JianghaiOldCity"
	var city_packed := load(CITY_PATH) as PackedScene
	if city_packed == null:
		root.free()
		return ERR_CANT_OPEN
	var city_instance := city_packed.instantiate()
	city_instance.name = "AuthoredCity"
	root.add_child(city_instance)
	city_instance.owner = root
	_walkable_collision_count = 0
	for index in range(WALKABLE_PATHS.size()):
		var mesh_node := city_instance.get_node_or_null(NodePath(WALKABLE_PATHS[index])) as MeshInstance3D
		if mesh_node == null or mesh_node.mesh == null:
			root.free()
			return ERR_INVALID_DATA
		var collision_mesh := mesh_node.mesh.create_trimesh_shape()
		if collision_mesh == null:
			root.free()
			return ERR_CANT_CREATE
		var static_body := StaticBody3D.new()
		static_body.name = "WalkableCollision_%02d" % index
		static_body.collision_layer = 1
		static_body.collision_mask = 0
		static_body.transform = mesh_node.global_transform
		var collision_shape := CollisionShape3D.new()
		collision_shape.shape = collision_mesh
		static_body.add_child(collision_shape)
		root.add_child(static_body)
		static_body.owner = root
		collision_shape.owner = root
		_walkable_collision_count += 1
	var navigation_region := NavigationRegion3D.new()
	navigation_region.name = "CuratedNavigationRegion"
	navigation_region.navigation_mesh = _navigation_mesh
	root.add_child(navigation_region)
	navigation_region.owner = root
	var packed_world := PackedScene.new()
	var pack_error := packed_world.pack(root)
	if pack_error != OK:
		root.free()
		return pack_error
	var save_error := ResourceSaver.save(packed_world, WORLD_SCENE_PATH)
	root.free()
	return save_error

func _validate_navigation_after_sync() -> void:
	await physics_frame
	await physics_frame
	await physics_frame
	var navigation_map := _region.get_navigation_map()
	if not navigation_map.is_valid():
		_fail("NavigationRegion3D has no valid navigation map after synchronization.")
		return

	var anchor_rows: Array[Dictionary] = []
	for anchor_id in ANCHORS:
		var source_position: Vector3 = ANCHORS[anchor_id]
		var projected := NavigationServer3D.map_get_closest_point(navigation_map, source_position)
		var projection_distance := projected.distance_to(source_position)
		anchor_rows.append({
			"id": anchor_id,
			"source_position": _vec(source_position),
			"projected_position": _vec(projected),
			"projection_distance": projection_distance,
			"projection_valid": projection_distance <= 6.0
		})

	var spawn_rows: Array[Dictionary] = []
	var spawn_projection_pass_count := 0
	for npc_id in NPC_SPAWN_CANDIDATES:
		var spawn_source: Vector3 = NPC_SPAWN_CANDIDATES[npc_id]
		var spawn_projected := NavigationServer3D.map_get_closest_point(navigation_map, spawn_source)
		var spawn_distance := spawn_projected.distance_to(spawn_source)
		var spawn_valid := spawn_distance <= 1.0
		if spawn_valid:
			spawn_projection_pass_count += 1
		spawn_rows.append({
			"npc_id": npc_id,
			"source_position": _vec(spawn_source),
			"projected_position": _vec(spawn_projected),
			"projection_distance": spawn_distance,
			"projection_valid": spawn_valid,
			"collision_clearance_validated": false
		})

	var route_pairs := [
		["jianghai.central_avenue", "jianghai.pawnshop_approach"],
		["jianghai.central_avenue", "jianghai.factory_approach"],
		["jianghai.central_avenue", "jianghai.market_bridge"],
		["jianghai.central_avenue", "jianghai.hotel_frontage"],
		["jianghai.central_avenue", "jianghai.medicine_frontage"],
		["jianghai.central_avenue", "jianghai.tea_frontage"],
		["jianghai.pawnshop_approach", "jianghai.factory_approach"]
	]
	var route_rows: Array[Dictionary] = []
	for pair in route_pairs:
		var start_position: Vector3 = ANCHORS[pair[0]]
		var end_position: Vector3 = ANCHORS[pair[1]]
		var start_point := NavigationServer3D.map_get_closest_point(navigation_map, start_position)
		var end_point := NavigationServer3D.map_get_closest_point(navigation_map, end_position)
		var path := NavigationServer3D.map_get_path(navigation_map, start_point, end_point, true, 1)
		route_rows.append({
			"from": pair[0],
			"to": pair[1],
			"waypoint_count": path.size(),
			"connected": path.size() >= 2,
			"path_length": _path_length(path)
		})

	var valid_projections := 0
	for row in anchor_rows:
		if bool(row["projection_valid"]):
			valid_projections += 1
	var connected_routes := 0
	for row in route_rows:
		if bool(row["connected"]):
			connected_routes += 1

	var report := {
		"city_scene": CITY_PATH,
		"saved_navigation_mesh": NAVMESH_PATH,
		"saved_runtime_world_scene": WORLD_SCENE_PATH,
		"bake_status": "BAKED",
		"route_status": "CONNECTED" if connected_routes == route_pairs.size() else "BAKED_WITH_ROUTE_GAPS",
		"source_geometry_mode": "GROUPS_EXPLICIT",
		"parsed_geometry_type": "MESH_INSTANCES",
		"selected_walkable_sources": _selected_sources,
		"excluded_geometry_policy": "All unlisted city meshes are excluded from navigation baking.",
		"agent_profile": {
			"radius": _navigation_mesh.agent_radius,
			"height": _navigation_mesh.agent_height,
			"max_climb": _navigation_mesh.agent_max_climb,
			"max_slope_degrees": _navigation_mesh.agent_max_slope,
			"cell_size": _navigation_mesh.cell_size,
			"cell_height": _navigation_mesh.cell_height
		},
		"polygon_count": _navigation_mesh.get_polygon_count(),
		"vertex_count": _navigation_mesh.get_vertices().size(),
		"navigation_map_valid": navigation_map.is_valid(),
		"anchor_projections": anchor_rows,
		"npc_spawn_projections": spawn_rows,
		"npc_spawn_projection_pass_count": spawn_projection_pass_count,
		"route_connectivity": route_rows,
		"projection_pass_count": valid_projections,
		"route_connectivity_pass_count": connected_routes,
		"npc_spawning_enabled": false,
		"collision_bake_included": true,
		"walkable_floor_collision_shape_count": _walkable_collision_count,
		"building_obstacle_collisions_included": false,
		"runtime_android_performance_validated": false
	}
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		_fail("Could not write navigation audit report.")
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("PHASE1 NAVIGATION BAKE AUDIT: ", JSON.stringify(report))
	if valid_projections != ANCHORS.size():
		_fail("One or more task anchors are too far from the curated walkable surfaces.")
		return
	if spawn_projection_pass_count != NPC_SPAWN_CANDIDATES.size():
		push_warning("One or more deferred NPC spawn points are outside the curated walkable surfaces.")
	if connected_routes != route_pairs.size():
		push_warning("Navigation bake completed, but route connectivity has gaps. Keep NPC spawning disabled until routes are repaired.")
	else:
		print("PHASE1 CURATED NAVIGATION ROUTE CONNECTIVITY: PASS")
	print("PHASE1 CURATED NAVIGATION BAKE: COMPLETE")
	quit(0)

func _path_length(path: PackedVector3Array) -> float:
	var total := 0.0
	for index in range(1, path.size()):
		total += path[index - 1].distance_to(path[index])
	return total

func _vec(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _fail(message: String) -> void:
	push_error("PHASE1 NAVIGATION BAKE FAILED: " + message)
	quit(1)
