extends SceneTree

const CITY_PATH := "res://assets/environment/phase1/jianghai/chinese_district.glb"
const SOURCE_GATE_ANCHOR := Vector3(-86.001892, 1.2787764, -122.576271)
var audit_root: Node3D

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    get_root().get_viewport().size = Vector2i(960, 540)
    var root := Node3D.new()
    root.name = "ChineseDistrictVisualAudit"
    audit_root = root
    get_root().add_child(root)

    var world := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color(0.12, 0.36, 0.68)
    sky_material.sky_horizon_color = Color(0.55, 0.72, 0.86)
    sky_material.sky_curve = 0.22
    sky_material.sky_energy_multiplier = 1.0
    sky_material.ground_bottom_color = Color(0.09, 0.12, 0.14)
    sky_material.ground_horizon_color = Color(0.40, 0.48, 0.52)
    sky_material.ground_curve = 0.18
    sky_material.ground_energy_multiplier = 0.55
    sky_material.sun_angle_max = 5.5
    sky_material.sun_curve = 0.10
    sky_material.use_debanding = true
    sky.sky_material = sky_material
    sky.radiance_size = Sky.RADIANCE_SIZE_128
    sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.55, 0.66, 0.82)
    environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
    environment.background_energy_multiplier = 1.0
    environment.ambient_light_energy = 1.0
    environment.fog_enabled = true
    environment.fog_light_color = Color(0.55, 0.68, 0.76)
    environment.fog_light_energy = 0.38
    environment.fog_density = 0.0010
    environment.fog_sky_affect = 0.08
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.tonemap_exposure = 0.98
    environment.adjustment_enabled = true
    environment.adjustment_brightness = 1.02
    environment.adjustment_contrast = 0.98
    environment.adjustment_saturation = 1.04
    world.environment = environment
    root.add_child(world)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-42, 28, 0)
    sun.light_color = Color(0.98, 0.90, 0.78)
    sun.light_energy = 1.03
    sun.shadow_enabled = true
    root.add_child(sun)

    var fill := DirectionalLight3D.new()
    fill.rotation_degrees = Vector3(-18, -148, 0)
    fill.light_color = Color(0.55, 0.66, 0.82)
    fill.light_energy = 0.62
    fill.shadow_enabled = false
    root.add_child(fill)

    var packed := load(CITY_PATH) as PackedScene
    if packed == null:
        push_error("Chinese district GLB did not import as PackedScene.")
        quit(2)
        return
    var city := packed.instantiate() as Node3D
    if city == null:
        push_error("Chinese district GLB root is not Node3D.")
        quit(2)
        return
    root.add_child(city)
    await process_frame

    var horizontal_bounds := _collect_bounds(city)
    var horizontal_span := maxf(horizontal_bounds.size.x, horizontal_bounds.size.z)
    if horizontal_span <= 0.01:
        push_error("Chinese district has no measurable horizontal geometry.")
        quit(3)
        return
    var factor := 1.0
    city.scale = Vector3.ONE * factor
    city.position = -SOURCE_GATE_ANCHOR * factor
    # Keep source-authored gravel, rocky terrain and mountain materials unchanged.
    await process_frame

    var final_bounds := _collect_bounds(city)
    var final_center := final_bounds.position + final_bounds.size * 0.5
    var span := maxf(final_bounds.size.x, maxf(final_bounds.size.y, final_bounds.size.z))
    var authored_bounds := _collect_authored_city_bounds(city)
    var authored_center := authored_bounds.position + authored_bounds.size * 0.5
    var authored_span := maxf(authored_bounds.size.x, maxf(authored_bounds.size.y, authored_bounds.size.z))
    print("CHINESE DISTRICT SOURCE GATE ANCHOR ", SOURCE_GATE_ANCHOR)
    print("CHINESE DISTRICT FULL BOUNDS ", final_bounds, " scale=", factor)
    print("CHINESE DISTRICT AUTHORED-BUILDINGS BOUNDS ", authored_bounds)
    print("CHINESE DISTRICT MESH NODES ", _count_mesh_nodes(city))

    # Keep the overview camera identical to the full-source comparison render.
    # This makes omitted structures obvious instead of hiding them through auto-fit.
    var overview_camera := Camera3D.new()
    overview_camera.fov = 50.0
    overview_camera.position = Vector3(90, 65, 110)
    root.add_child(overview_camera)
    overview_camera.look_at(Vector3(0, 5, -10), Vector3.UP)
    overview_camera.current = true
    await _capture("reports/phase1_chinese_district_preview.png")

    # A wider city framing complements the source-matched camera while retaining
    # all authored transforms and excluding only outer landscape meshes from bounds.
    var district_camera := Camera3D.new()
    district_camera.fov = 52.0
    var district_horizontal_span := maxf(authored_bounds.size.x, authored_bounds.size.z)
    var district_distance := maxf(district_horizontal_span * 0.48, 85.0)
    var district_view_direction := Vector3(0.78, 0.62, 1.0).normalized()
    district_camera.position = authored_center + district_view_direction * district_distance
    root.add_child(district_camera)
    district_camera.look_at(authored_center, Vector3.UP)
    district_camera.current = true
    await _capture("reports/phase1_chinese_district_closeup.png")

    var gate_camera := Camera3D.new()
    gate_camera.fov = 55.0
    gate_camera.position = Vector3(10, 8, 14)
    root.add_child(gate_camera)
    gate_camera.look_at(Vector3(0, 2, -3), Vector3.UP)
    gate_camera.current = true
    await _capture("reports/phase1_chinese_district_gate_detail.png")

    # Dedicated bridge framing: the source gate anchor shifts the city, so a
    # fixed origin-facing camera can miss the market bridge entirely.
    var bridge_deck := city.find_child("MarketBridgeDeck", true, false) as MeshInstance3D
    var east_ramp := city.find_child("MarketEastRamp", true, false) as MeshInstance3D
    var west_ramp := city.find_child("MarketWestRamp", true, false) as MeshInstance3D
    if bridge_deck == null or east_ramp == null or west_ramp == null:
        push_error("Market bridge deck or one of its ramps is missing from the imported district.")
        quit(5)
        return
    var bridge_center := bridge_deck.global_position
    var bridge_camera := Camera3D.new()
    bridge_camera.fov = 58.0
    bridge_camera.position = bridge_center + Vector3(12.0, 10.0, 12.0)
    bridge_camera.fov = 50.0
    root.add_child(bridge_camera)
    bridge_camera.look_at(bridge_center, Vector3.UP)
    bridge_camera.current = true
    print("PHASE1 MARKET BRIDGE CAMERA TARGET ", bridge_center,
        " deck=", bridge_deck.name, " east_ramp=", east_ramp.name, " west_ramp=", west_ramp.name)
    await _capture("reports/phase1_market_bridge_detail.png")
    print("CHINESE DISTRICT PREVIEWS SAVED full-world, authored-district, gate-detail, and market-bridge-detail; full_span=", span, " authored_span=", authored_span)
    await _run_main_game_integration()
    quit(0)


func _run_main_game_integration() -> void:
    # Audit-only composition: do not modify or delete the source MainGame nodes.
    audit_root.visible = false
    for camera_node in audit_root.find_children("*", "Camera3D", true, false):
        (camera_node as Camera3D).current = false
    var main_packed := load("res://scenes/core/MainGame.tscn") as PackedScene
    var city_packed := load(CITY_PATH) as PackedScene
    if main_packed == null or city_packed == null:
        push_error("MainGame or Phase 1 city failed to load for integration audit.")
        quit(6)
        return
    var game := main_packed.instantiate() as Node3D
    if game == null:
        push_error("MainGame root is not Node3D.")
        quit(6)
        return
    get_root().add_child(game)
    await process_frame
    var old_ground := game.get_node_or_null("Ground")
    var old_city := game.get_node_or_null("TwinCity")
    if old_ground:
        old_ground.visible = false
    if old_city:
        old_city.visible = false
    var old_trees := game.get_node_or_null("TwinPlainsTrees")
    if old_trees:
        old_trees.visible = false
    var old_volcano := game.get_node_or_null("MountainSummitVolcano")
    if old_volcano:
        old_volcano.visible = false
    var canvas := game.get_node_or_null("CanvasLayer")
    if canvas:
        canvas.visible = false
    for camera_node in game.find_children("*", "Camera3D", true, false):
        (camera_node as Camera3D).current = false
    var city := city_packed.instantiate() as Node3D
    if city == null:
        push_error("Phase 1 city root is not Node3D.")
        quit(6)
        return
    city.name = "Phase1ChineseDistrict_AuditOnly"
    city.position = -SOURCE_GATE_ANCHOR
    game.add_child(city)
    await process_frame
    var player := game.get_node_or_null("Player")
    var travel := game.get_node_or_null("WorldTravelManager")
    var bridge := city.find_child("MarketBridgeDeck", true, false) as MeshInstance3D
    var east_ramp := city.find_child("MarketEastRamp", true, false)
    var west_ramp := city.find_child("MarketWestRamp", true, false)
    var street := city.find_child("CentralAvenue", true, false)
    if player == null or travel == null or bridge == null or east_ramp == null or west_ramp == null or street == null:
        push_error("Integration audit missing Player, WorldTravelManager, street, bridge deck, or bridge ramps.")
        quit(7)
        return
    print("PHASE1 MAIN GAME AUDIT: player=", player.name,
        " npc_count=", game.find_children("*", "NPCBase", true, false).size(),
        " bridge_world_position=", bridge.global_position,
        " street=", street.name, " travel_manager=", travel.name)
    var gate_camera := Camera3D.new()
    gate_camera.fov = 62.0
    gate_camera.position = Vector3(18.0, 12.0, 28.0)
    game.add_child(gate_camera)
    gate_camera.look_at(Vector3(0.0, 3.0, 0.0), Vector3.UP)
    gate_camera.current = true
    await _capture("reports/phase1_maingame_gate_integration.png")
    var bridge_camera := Camera3D.new()
    bridge_camera.fov = 62.0
    var bridge_center := bridge.global_position
    bridge_camera.position = bridge_center + Vector3(12.0, 9.0, 12.0)
    game.add_child(bridge_camera)
    bridge_camera.look_at(bridge_center, Vector3.UP)
    bridge_camera.current = true
    await _capture("reports/phase1_maingame_bridge_integration.png")
    var avenue_target := Vector3(86.0, 3.0, 45.0)
    var avenue_camera := Camera3D.new()
    avenue_camera.fov = 68.0
    avenue_camera.position = avenue_target + Vector3(26.0, 18.0, 30.0)
    game.add_child(avenue_camera)
    avenue_camera.look_at(avenue_target, Vector3.UP)
    avenue_camera.current = true
    await _capture("reports/phase1_maingame_street_integration.png")
    print("PHASE1 MAIN GAME VISUAL AUDIT SAVED: gate, bridge, and avenue. Legacy blockout nodes were hidden only in this disposable audit instance.")
    # Let importer/navigation/audio worker threads finish before SceneTree teardown.
    await create_timer(2.0).timeout
    await process_frame

func _collect_authored_city_bounds(node: Node) -> AABB:
    var accumulator := {
        "minimum": Vector3(INF, INF, INF),
        "maximum": Vector3(-INF, -INF, -INF),
        "has_bounds": false
    }
    _collect_authored_bounds_recursive(node, accumulator)
    if not accumulator["has_bounds"]:
        return AABB(Vector3.ZERO, Vector3.ZERO)
    var minimum: Vector3 = accumulator["minimum"]
    var maximum: Vector3 = accumulator["maximum"]
    return AABB(minimum, maximum - minimum)

func _collect_authored_bounds_recursive(node: Node, accumulator: Dictionary) -> void:
    var label := node.name.to_lower()
    var exclude_visual := label.contains("mountainmassif") or label.contains("perimeterground") or label.contains("valleyenvironment")
    if node is VisualInstance3D and not exclude_visual:
        var visual := node as VisualInstance3D
        var aabb := visual.get_aabb()
        for index in range(8):
            var point := visual.global_transform * aabb.get_endpoint(index)
            var minimum: Vector3 = accumulator["minimum"]
            var maximum: Vector3 = accumulator["maximum"]
            accumulator["minimum"] = Vector3(minf(minimum.x, point.x), minf(minimum.y, point.y), minf(minimum.z, point.z))
            accumulator["maximum"] = Vector3(maxf(maximum.x, point.x), maxf(maximum.y, point.y), maxf(maximum.z, point.z))
            accumulator["has_bounds"] = true
    for child in node.get_children():
        _collect_authored_bounds_recursive(child, accumulator)

func _tint_landscape(node: Node) -> void:
    if node is MeshInstance3D:
        var instance := node as MeshInstance3D
        var label := (instance.name + " " + (instance.mesh.resource_name if instance.mesh != null else "")).to_lower()
        var tint := Color.WHITE
        var should_tint := true
        if label.contains("perimetergroundcomposite"):
            tint = Color(0.42, 0.58, 0.28)
        elif label.contains("mountainmassif"):
            tint = Color(0.65, 0.62, 0.56)
        elif label.contains("oldcityfoundation"):
            tint = Color(0.62, 0.54, 0.42)
        else:
            should_tint = false
        if should_tint and instance.mesh != null:
            for surface in range(instance.mesh.get_surface_count()):
                var source := instance.get_active_material(surface)
                if source is StandardMaterial3D:
                    var material := (source as StandardMaterial3D).duplicate() as StandardMaterial3D
                    material.albedo_color = tint
                    material.roughness = 0.92
                    instance.set_surface_override_material(surface, material)
    for child in node.get_children():
        _tint_landscape(child)

func _count_mesh_nodes(node: Node) -> int:
    var count := 1 if node is MeshInstance3D else 0
    for child in node.get_children():
        count += _count_mesh_nodes(child)
    return count

func _collect_bounds(node: Node) -> AABB:
    var accumulator := {
        "minimum": Vector3(INF, INF, INF),
        "maximum": Vector3(-INF, -INF, -INF),
        "has_bounds": false
    }
    _collect_bounds_recursive(node, accumulator)
    if not accumulator["has_bounds"]:
        return AABB(Vector3.ZERO, Vector3.ZERO)
    var minimum: Vector3 = accumulator["minimum"]
    var maximum: Vector3 = accumulator["maximum"]
    return AABB(minimum, maximum - minimum)

func _collect_bounds_recursive(node: Node, accumulator: Dictionary) -> void:
    if node is VisualInstance3D:
        var visual := node as VisualInstance3D
        var aabb := visual.get_aabb()
        for index in range(8):
            var point := visual.global_transform * aabb.get_endpoint(index)
            var minimum: Vector3 = accumulator["minimum"]
            var maximum: Vector3 = accumulator["maximum"]
            accumulator["minimum"] = Vector3(
                minf(minimum.x, point.x),
                minf(minimum.y, point.y),
                minf(minimum.z, point.z)
            )
            accumulator["maximum"] = Vector3(
                maxf(maximum.x, point.x),
                maxf(maximum.y, point.y),
                maxf(maximum.z, point.z)
            )
            accumulator["has_bounds"] = true
    for child in node.get_children():
        _collect_bounds_recursive(child, accumulator)

func _capture(output_path: String) -> void:
    await process_frame
    await process_frame
    await process_frame
    var image := get_root().get_viewport().get_texture().get_image()
    var error := image.save_png(output_path)
    if error != OK:
        push_error("Could not save preview: " + output_path)
        quit(4)
