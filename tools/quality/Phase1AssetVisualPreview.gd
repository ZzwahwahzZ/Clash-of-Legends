extends SceneTree

const ROOT := "res://assets/environment/phase1"
const COURTYARD := ROOT + "/sapphire/courtyard.glb"
const ARCADE := ROOT + "/sapphire/arcade.glb"
const PAVILION := ROOT + "/sapphire/pavilion.glb"
const GROUND_TEXTURE := ROOT + "/sapphire/ground.png"
const OAK := ROOT + "/kenney-nature/tree-oak.glb"
const PINE := ROOT + "/kenney-nature/tree-pinedefaulta.glb"
const ROCK := ROOT + "/kenney-nature/rock-largea.glb"
const BUSH := ROOT + "/kenney-nature/plant-bushdetailed.glb"

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    get_root().get_viewport().size = Vector2i(1600, 900)
    await _render_world_preview()
    await _render_nature_preview()
    quit(0)

func _render_world_preview() -> void:
    var root := _create_stage("Phase1WorldPreview")
    var courtyard := _instantiate(COURTYARD, Vector3.ZERO, 0.82)
    _apply_palette(courtyard, "courtyard")
    root.add_child(courtyard)

    var pavilion := _instantiate(PAVILION, Vector3(-14, 0, -30), 1.0)
    _apply_palette(pavilion, "pavilion")
    root.add_child(pavilion)

    var arcade := _instantiate(ARCADE, Vector3(0, 0, -24), 1.0)
    _apply_palette(arcade, "arcade")
    root.add_child(arcade)

    var oak := _instantiate(OAK, Vector3(-25, 0, -15), 2.5)
    _apply_palette(oak, "oak")
    root.add_child(oak)

    var pine := _instantiate(PINE, Vector3(24, 0, -14), 2.5)
    _apply_palette(pine, "pine")
    root.add_child(pine)

    var bush := _instantiate(BUSH, Vector3(-22, 0, -37), 3.0)
    _apply_palette(bush, "bush")
    root.add_child(bush)

    var rock := _instantiate(ROCK, Vector3(22, 0, -39), 3.0)
    _apply_palette(rock, "rock")
    root.add_child(rock)

    var camera := Camera3D.new()
    camera.fov = 48.0
    camera.position = Vector3(42, 29, 18)
    root.add_child(camera)
    camera.look_at(Vector3(0, 5, -29), Vector3.UP)
    camera.current = true

    await _capture(root, "reports/phase1_world_preview.png")

func _render_nature_preview() -> void:
    var root := _create_stage("Phase1NaturePreview")
    var entries := [
        {"path": OAK, "position": Vector3(-9, 0, 0), "scale": 4.0, "kind": "oak"},
        {"path": PINE, "position": Vector3(-1, 0, 0), "scale": 4.0, "kind": "pine"},
        {"path": ROCK, "position": Vector3(7, 0, 0), "scale": 5.0, "kind": "rock"},
        {"path": BUSH, "position": Vector3(15, 0, 0), "scale": 5.0, "kind": "bush"}
    ]
    for entry in entries:
        var instance := _instantiate(String(entry["path"]), entry["position"], float(entry["scale"]))
        _apply_palette(instance, String(entry["kind"]))
        root.add_child(instance)

    var camera := Camera3D.new()
    camera.fov = 42.0
    camera.position = Vector3(10, 11, 29)
    root.add_child(camera)
    camera.look_at(Vector3(3, 3, 0), Vector3.UP)
    camera.current = true

    await _capture(root, "reports/phase1_nature_preview.png")

func _create_stage(stage_name: String) -> Node3D:
    var root := Node3D.new()
    root.name = stage_name
    get_root().add_child(root)

    var environment_node := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color(0.17, 0.27, 0.40)
    sky_material.sky_horizon_color = Color(0.78, 0.76, 0.68)
    sky.sky_material = sky_material
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.78, 0.77, 0.70)
    environment.ambient_light_energy = 0.9
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment_node.environment = environment
    root.add_child(environment_node)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, 32, 0)
    sun.light_energy = 1.55
    sun.shadow_enabled = true
    root.add_child(sun)

    var floor := MeshInstance3D.new()
    var floor_mesh := PlaneMesh.new()
    floor_mesh.size = Vector2(260, 260)
    floor.mesh = floor_mesh
    var floor_material := StandardMaterial3D.new()
    floor_material.albedo_color = Color(0.22, 0.25, 0.22)
    floor_material.roughness = 0.96
    floor.material_override = floor_material
    floor.position.y = -0.3
    root.add_child(floor)
    return root

func _instantiate(path: String, position: Vector3, scale_factor: float) -> Node3D:
    var resource := load(path)
    if not (resource is PackedScene):
        push_error("Could not load production asset: " + path)
        quit(2)
        return Node3D.new()
    var instance := (resource as PackedScene).instantiate() as Node3D
    if instance == null:
        push_error("Production asset root is not Node3D: " + path)
        quit(2)
        return Node3D.new()
    instance.position = position
    instance.scale = Vector3.ONE * scale_factor
    return instance

func _apply_palette(root: Node, kind: String) -> void:
    for child in root.get_children():
        if child is MeshInstance3D:
            var mesh_instance := child as MeshInstance3D
            var mesh := mesh_instance.mesh
            if mesh == null:
                continue
            for surface in range(mesh.get_surface_count()):
                var source_material := mesh.surface_get_material(surface)
                var name := ""
                if source_material != null:
                    name = source_material.resource_name.to_lower()
                var material := _material_for(kind, name, surface)
                if material != null:
                    mesh_instance.set_surface_override_material(surface, material)
        _apply_palette(child, kind)

func _material_for(kind: String, source_name: String, surface: int) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.metallic = 0.0
    material.roughness = 0.82
    material.vertex_color_use_as_albedo = kind in ["courtyard", "arcade"]

    match kind:
        "courtyard":
            match surface:
                0:
                    material.albedo_color = Color.WHITE
                    material.albedo_texture = load(GROUND_TEXTURE) as Texture2D
                    material.uv1_scale = Vector3(1.0, 1.0, 1.0)
                1:
                    material.albedo_color = Color(0.43, 0.36, 0.28)
                2:
                    material.albedo_color = Color(0.76, 0.68, 0.54)
                3:
                    material.albedo_color = Color(0.70, 0.48, 0.36)
                4:
                    material.albedo_color = Color(0.95, 0.67, 0.30)
                    material.emission_enabled = true
                    material.emission = Color(0.75, 0.30, 0.08)
                    material.emission_energy_multiplier = 1.1
        "arcade":
            if source_name.to_lower().contains("stone") or surface == 0:
                material.albedo_color = Color(0.76, 0.69, 0.56)
            else:
                material.albedo_color = Color(0.78, 0.68, 0.57)
        "pavilion":
            match surface:
                0:
                    material.albedo_color = Color(0.28, 0.045, 0.035)
                    material.roughness = 0.48
                1:
                    material.albedo_color = Color(0.34, 0.16, 0.08)
                2:
                    material.albedo_color = Color(0.075, 0.095, 0.13)
                    material.roughness = 0.72
                3:
                    material.albedo_color = Color(0.13, 0.15, 0.18)
                4:
                    material.albedo_color = Color(0.68, 0.65, 0.57)
                5:
                    material.albedo_color = Color(0.55, 0.12, 0.08)
        "oak":
            material.albedo_color = Color(0.15, 0.34, 0.16) if surface == 0 else Color(0.25, 0.13, 0.07)
        "pine":
            material.albedo_color = Color(0.09, 0.25, 0.16) if surface == 0 else Color(0.20, 0.11, 0.07)
        "rock":
            material.albedo_color = Color(0.31, 0.27, 0.22) if surface == 0 else Color(0.20, 0.34, 0.15)
        "bush":
            material.albedo_color = Color(0.17, 0.36, 0.16)
        _:
            return null
    return material

func _capture(root: Node3D, output_path: String) -> void:
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
