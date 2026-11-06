extends SceneTree

const CITY_PATH := "res://assets/environment/phase1/jianghai/chinese_district.glb"

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    get_root().get_viewport().size = Vector2i(1600, 900)
    var root := Node3D.new()
    root.name = "ChineseDistrictVisualAudit"
    get_root().add_child(root)

    var world := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color(0.18, 0.25, 0.38)
    sky_material.sky_horizon_color = Color(0.72, 0.68, 0.60)
    sky.sky_material = sky_material
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.72, 0.74, 0.78)
    environment.ambient_light_energy = 0.65
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    world.environment = environment
    root.add_child(world)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, 28, 0)
    sun.light_energy = 1.25
    sun.shadow_enabled = true
    root.add_child(sun)

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

    var initial_bounds := _collect_bounds(city)
    var center := initial_bounds.position + initial_bounds.size * 0.5
    var horizontal_span := maxf(initial_bounds.size.x, initial_bounds.size.z)
    if horizontal_span <= 0.01:
        push_error("Chinese district has no measurable horizontal geometry.")
        quit(3)
        return
    var target_span := 150.0
    var factor := target_span / horizontal_span
    city.scale = Vector3.ONE * factor
    city.position = Vector3(-center.x * factor, -initial_bounds.position.y * factor, -center.z * factor)
    await process_frame

    var final_bounds := _collect_bounds(city)
    var final_center := final_bounds.position + final_bounds.size * 0.5
    var span := maxf(final_bounds.size.x, maxf(final_bounds.size.y, final_bounds.size.z))
    print("CHINESE DISTRICT BOUNDS ", final_bounds, " scale=", factor)
    print("CHINESE DISTRICT MESH NODES ", _count_mesh_nodes(city))

    var floor := MeshInstance3D.new()
    var floor_mesh := PlaneMesh.new()
    floor_mesh.size = Vector2(220, 220)
    floor.mesh = floor_mesh
    var floor_material := StandardMaterial3D.new()
    floor_material.albedo_color = Color(0.22, 0.25, 0.22)
    floor_material.roughness = 0.95
    floor.material_override = floor_material
    floor.position.y = final_bounds.position.y - 0.25
    root.add_child(floor)

    var camera := Camera3D.new()
    camera.fov = 48.0
    camera.position = final_center + Vector3(span * 1.05, span * 0.72, span * 1.25)
    root.add_child(camera)
    camera.look_at(final_center, Vector3.UP)
    camera.current = true

    await process_frame
    await process_frame
    await process_frame
    var image := get_root().get_viewport().get_texture().get_image()
    var error := image.save_png("reports/phase1_chinese_district_preview.png")
    if error != OK:
        push_error("Could not save Chinese district preview.")
        quit(4)
        return
    quit(0)

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
