import bpy, math
from pathlib import Path
from mathutils import Vector

source_dir = Path("reports/mounts")
preview_dir = source_dir / "previews"
preview_dir.mkdir(parents=True, exist_ok=True)
files = sorted(source_dir.glob("*_conservative_repair_candidate.glb"))
if not files:
    raise SystemExit("No repaired mount candidate GLBs found")

def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)

def aim(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

def add_area(name, location, energy, size, target):
    data = bpy.data.lights.new(name, type="AREA")
    data.energy = energy
    data.shape = "DISK"
    data.size = size
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    aim(obj, target)
    return obj

for path in files:
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=str(path))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        print("PREVIEW_SKIP_NO_MESH", path.name)
        continue
    corners = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    minimum = Vector((min(v.x for v in corners), min(v.y for v in corners), min(v.z for v in corners)))
    maximum = Vector((max(v.x for v in corners), max(v.y for v in corners), max(v.z for v in corners)))
    center = (minimum + maximum) * 0.5
    extent = maximum - minimum
    radius = max(extent.x, extent.y, extent.z, 0.01)
    # Neutral studio ground and world, preserving imported materials.
    world = bpy.data.worlds.new("MountPreviewWorld")
    bpy.context.scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.055, 0.065, 0.08, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.7
    ground_mesh = bpy.data.meshes.new("PreviewGroundMesh")
    ground_mesh.from_pydata([
        (center.x-radius*3, center.y-radius*3, minimum.z-radius*0.03),
        (center.x+radius*3, center.y-radius*3, minimum.z-radius*0.03),
        (center.x+radius*3, center.y+radius*3, minimum.z-radius*0.03),
        (center.x-radius*3, center.y+radius*3, minimum.z-radius*0.03),
    ], [], [(0,1,2,3)])
    ground = bpy.data.objects.new("PreviewGround", ground_mesh)
    bpy.context.collection.objects.link(ground)
    ground_mat = bpy.data.materials.new("PreviewGroundMat")
    ground_mat.diffuse_color = (0.18, 0.19, 0.21, 1.0)
    ground.data.materials.append(ground_mat)
    # Three-point studio lighting.
    add_area("Key", center + Vector((radius*2.0, -radius*2.2, radius*2.5)), 1400, radius*2.0, center)
    add_area("Fill", center + Vector((-radius*2.0, -radius*0.8, radius*1.2)), 850, radius*2.5, center)
    add_area("Rim", center + Vector((radius*0.4, radius*2.0, radius*2.0)), 1200, radius*1.5, center)
    camera_data = bpy.data.cameras.new("MountPreviewCamera")
    camera = bpy.data.objects.new("MountPreviewCamera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.location = center + Vector((radius*2.1, -radius*2.6, radius*1.45))
    aim(camera, center)
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = radius * 2.0
    scene = bpy.context.scene
    scene.camera = camera
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.eevee.taa_render_samples = 64
    scene.render.resolution_x = 1200
    scene.render.resolution_y = 1200
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.render.filepath = str(preview_dir / (path.stem + ".png"))
    bpy.ops.render.render(write_still=True)
    print("MOUNT_PREVIEW_RENDERED", path.name, scene.render.filepath, "bounds", tuple(round(x,4) for x in extent))
