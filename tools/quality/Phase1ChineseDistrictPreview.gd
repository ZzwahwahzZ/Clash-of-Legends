extends SceneTree

const CITY_PATH := "res://assets/environment/phase1/jianghai/chinese_district.glb"
const SOURCE_GATE_ANCHOR := Vector3(-86.001892, 1.2787764, -122.576271)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    get_root().get_viewport().size = Vector2i(1280, 720)
    var root := Node3D.new()
    root.name = "ChineseDistrictVisualAudit"
    get_root().add_child(root)

    var world := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color(0.12, 0.19, 0.29)
    sky_material.sky_horizon_color = Color(0.63, 0.52, 0.40)
    sky.sky_material = sky_material
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.66, 0.67, 0.69)
    environment.ambient_light_energy = 0.48
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    world.environment = environment
    root.add_child(world)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-42, 28, 0)
    sun.light_energy = 0.92
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

    var horizontal_bounds := _collect_bounds(city)
    var horizontal_span := maxf(horizontal_bounds.size.x, horizontal_bounds.size.z)
    if horizontal_span <= 0.01:
        push_error("Chinese district has no measurable horizontal geometry.")
        quit(3)
        return
    var factor := 480.0 / horizontal_span
    city.scale = Vector3.ONE * factor
    city.position = -SOURCE_GATE_ANCHOR * factor
    _tint_landscape(city)
    await process_frame

    var final_bounds := _collect_bounds(city)
    var final_center := final_bounds.position + final_bounds.size * 0.5
    var span := maxf(final_bounds.size.x, maxf(final_bounds.size.y, final_bounds.size.z))
    print("CHINESE DISTRICT SOURCE GATE ANCHOR ", SOURCE_GATE_ANCHOR)
    print("CHINESE DISTRICT BOUNDS ", final_bounds, " scale=", factor)
    print("CHINESE DISTRICT MESH NODES ", _count_mesh_nodes(city))

    var overview_camera := Camera3D.new()
    overview_camera.fov = 48.0
    overview_camera.position = Vector3(180, 135, 220)
    root.add_child(overview_camera)
    overview_camera.look_at(Vector3(0, 5, -10), Vector3.UP)
    overview_camera.current = true
    await _capture("reports/phase1_chinese_district_preview.png")

    var close_camera := Camera3D.new()
    close_camera.fov = 48.0
    close_camera.position = Vector3(28, 20, 36)
    root.add_child(close_camera)
    close_camera.look_at(Vector3(0, 5, -8), Vector3.UP)
    close_camera.current = true
    await _capture("reports/phase1_chinese_district_closeup.png")
    print("CHINESE DISTRICT PREVIEWS SAVED overview and gate close-up; span=", span)
    quit(0)

func _tint_landscape(node: Node) -> void:
    if node is MeshInstance3D:
        var instance := node as MeshInstance3D
        var label := (instance.name + " " + (instance.mesh.resource_name if instance.mesh != null else "")).to_lower()
        var tint := Color.WHITE
        var should_tint := true
        if label.contains("perimetergroundcomposite"):
            tint = Color(0.48, 0.62, 0.34)
        elif label.contains("mountainmassif"):
            tint = Color(0.68, 0.62, 0.52)
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
