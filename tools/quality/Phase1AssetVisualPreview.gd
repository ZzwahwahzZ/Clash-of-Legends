extends SceneTree

const ROOT := "res://assets/environment/phase1"
const COURTYARD := ROOT + "/sapphire/courtyard.glb"
const ARCADE := ROOT + "/sapphire/arcade.glb"
const PAVILION := ROOT + "/sapphire/pavilion.glb"
const OAK := ROOT + "/kenney-nature/tree-oak.glb"
const PINE := ROOT + "/kenney-nature/tree-pinedefaulta.glb"
const ROCK := ROOT + "/kenney-nature/rock-largea.glb"
const BUSH := ROOT + "/kenney-nature/plant-bushdetailed.glb"

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    get_root().get_viewport().size = Vector2i(1600, 900)
    await _render_gallery(
        "World courtyard and architecture",
        [
            {"path": COURTYARD, "position": Vector3.ZERO, "scale": 1.0},
            {"path": PAVILION, "position": Vector3(34, 0, 0), "scale": 0.85},
            {"path": ARCADE, "position": Vector3(-28, 0, 0), "scale": 1.0}
        ],
        "reports/phase1_world_preview.png"
    )
    await _render_gallery(
        "Nature asset set",
        [
            {"path": OAK, "position": Vector3(-7, 0, 0), "scale": 1.0},
            {"path": PINE, "position": Vector3(0, 0, 0), "scale": 1.0},
            {"path": ROCK, "position": Vector3(7, 0, 0), "scale": 1.0},
            {"path": BUSH, "position": Vector3(14, 0, 0), "scale": 1.0}
        ],
        "reports/phase1_nature_preview.png"
    )
    quit(0)

func _render_gallery(_caption: String, entries: Array, output_path: String) -> void:
    var root := Node3D.new()
    root.name = "Phase1VisualAudit"
    get_root().add_child(root)

    var environment_node := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color(0.20, 0.32, 0.48)
    sky_material.sky_horizon_color = Color(0.78, 0.78, 0.72)
    sky.sky_material = sky_material
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.72, 0.75, 0.80)
    environment.ambient_light_energy = 0.8
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment_node.environment = environment
    root.add_child(environment_node)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, 32, 0)
    sun.light_energy = 1.4
    sun.shadow_enabled = true
    root.add_child(sun)

    for entry in entries:
        var resource := load(String(entry["path"]))
        if not (resource is PackedScene):
            push_error("Could not load production asset as PackedScene: " + String(entry["path"]))
            quit(2)
            return
        var instance := (resource as PackedScene).instantiate() as Node3D
        instance.position = entry["position"]
        instance.scale = Vector3.ONE * float(entry["scale"])
        root.add_child(instance)

    var bounds := _collect_bounds(root)
    var center := bounds.position + bounds.size * 0.5
    var span := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
    span = maxf(span, 12.0)

    var floor := MeshInstance3D.new()
    var floor_mesh := PlaneMesh.new()
    floor_mesh.size = Vector2(span * 2.6, span * 2.6)
    floor.mesh = floor_mesh
    var floor_material := StandardMaterial3D.new()
    floor_material.albedo_color = Color(0.24, 0.27, 0.25)
    floor_material.roughness = 0.94
    floor.material_override = floor_material
    floor.position.y = bounds.position.y - 0.15
    root.add_child(floor)

    var camera := Camera3D.new()
    camera.fov = 42.0
    camera.position = center + Vector3(span * 1.05, span * 0.80, span * 1.30)
    camera.look_at(center, Vector3.UP)
    root.add_child(camera)
    camera.current = true

    await process_frame
    await process_frame
    await process_frame
    var image := get_root().get_viewport().get_texture().get_image()
    var err := image.save_png(output_path)
    if err != OK:
        push_error("Could not save preview: " + output_path)
        quit(3)
    root.queue_free()
    await process_frame

func _collect_bounds(node: Node) -> AABB:
    var accumulator := {
        "minimum": Vector3(INF, INF, INF),
        "maximum": Vector3(-INF, -INF, -INF),
        "has_bounds": false
    }
    _collect_bounds_recursive(node, accumulator)
    if not accumulator["has_bounds"]:
        return AABB(Vector3(-10, -1, -10), Vector3(20, 2, 20))
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
