#!/usr/bin/env python3
"""Render source C3 equipment GLBs for visual review; never approves assets."""
import argparse, json, sys
from pathlib import Path

import bpy
from mathutils import Vector

def world_bounds(objects):
    points = []
    for obj in objects:
        if obj.type != "MESH" or obj.data is None:
            continue
        points.extend(obj.matrix_world @ Vector(corner) for corner in obj.bound_box)
    if not points:
        return None
    lo = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    hi = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return lo, hi

def add_area_light(name, location, target, energy, size):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.shape = "DISK"
    data.size = size
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()
    return obj

def render_one(src: Path, root: Path, out_root: Path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(src))
    scene = bpy.context.scene
    mesh_objects = [o for o in scene.objects if o.type == "MESH" and o.data is not None]
    if not mesh_objects:
        return {"source": str(src), "status": "NO_MESH_OBJECTS"}
    bounds = world_bounds(mesh_objects)
    if bounds is None:
        return {"source": str(src), "status": "NO_GEOMETRY_BOUNDS"}
    lo, hi = bounds
    center = (lo + hi) * 0.5
    dims = hi - lo
    scale = max(dims.x, dims.y, dims.z, 0.001)
    material_count = 0
    uv_layer_count = 0
    vertex_count = polygon_count = 0
    for obj in mesh_objects:
        vertex_count += len(obj.data.vertices)
        polygon_count += len(obj.data.polygons)
        uv_layer_count += len(obj.data.uv_layers)
        for slot in obj.material_slots:
            if slot.material is not None:
                material_count += 1
        if not obj.data.materials:
            mat = bpy.data.materials.new(name="Diagnostic_Neutral_Material")
            mat.diffuse_color = (0.52, 0.56, 0.62, 1.0)
            mat.use_nodes = True
            bsdf = mat.node_tree.nodes.get("Principled BSDF")
            if bsdf:
                bsdf.inputs["Base Color"].default_value = (0.52, 0.56, 0.62, 1.0)
                bsdf.inputs["Roughness"].default_value = 0.62
            obj.data.materials.append(mat)
    world = bpy.data.worlds.new("EquipmentPreviewWorld")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.035, 0.045, 0.065, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.65
    engine_items = bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items
    engine_ids = {item.identifier for item in engine_items}
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engine_ids else "BLENDER_EEVEE"
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "Medium High Contrast"
    camera_data = bpy.data.cameras.new("EquipmentPreviewCamera")
    camera = bpy.data.objects.new("EquipmentPreviewCamera", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = scale * 1.55
    camera.location = center + Vector((scale * 2.25, -scale * 2.25, scale * 1.35))
    camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.lens = 55
    camera_data.clip_start = max(scale * 0.001, 0.001)
    camera_data.clip_end = scale * 100.0
    add_area_light("Key", center + Vector((scale * 2.0, -scale * 2.5, scale * 3.0)), center, scale * scale * 95, scale * 1.6)
    add_area_light("Fill", center + Vector((-scale * 2.0, -scale * 0.5, scale * 1.4)), center, scale * scale * 40, scale * 2.0)
    add_area_light("Rim", center + Vector((scale * 0.5, scale * 2.2, scale * 2.2)), center, scale * scale * 70, scale * 1.4)
    rel = src.relative_to(root)
    family = rel.parts[0] if len(rel.parts) > 1 else "unclassified"
    out = out_root / family / (src.stem + ".png")
    out.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(out)
    bpy.ops.render.render(write_still=True)
    return {
        "source": str(src), "relative_source": str(rel), "family": family,
        "preview": str(out), "status": "RENDERED_DIAGNOSTIC",
        "mesh_object_count": len(mesh_objects), "vertex_count": vertex_count,
        "polygon_count": polygon_count, "material_slot_count": material_count,
        "uv_layer_count": uv_layer_count,
        "armature_count": sum(1 for o in scene.objects if o.type == "ARMATURE"),
        "action_count": len(bpy.data.actions),
        "dimensions": [round(dims.x, 6), round(dims.y, 6), round(dims.z, 6)],
        "material_binding_verified": False,
        "socket_fit_verified": False,
        "source_identity_verified": False,
        "acceptance": "VISUAL_CANDIDATE_ONLY",
    }

def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--input-root", type=Path, required=True)
    ap.add_argument("--output-root", type=Path, required=True)
    ap.add_argument("--report", type=Path, required=True)
    args = ap.parse_args(argv)
    root = args.input_root.resolve()
    files = sorted(root.rglob("*.glb"))
    records = []
    for i, src in enumerate(files, 1):
        try:
            records.append(render_one(src, root, args.output_root))
            print(f"PREVIEW {i}/{len(files)} {src}")
        except Exception as exc:
            records.append({"source": str(src), "status": "RENDER_FAILED", "error": repr(exc)})
            print(f"PREVIEW_FAILED {src}: {exc}", file=sys.stderr)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps({
        "schema_version": "1.0.0", "candidate_count": len(files),
        "rendered_count": sum(1 for r in records if r["status"] == "RENDERED_DIAGNOSTIC"),
        "failed_count": sum(1 for r in records if r["status"] != "RENDERED_DIAGNOSTIC"),
        "production_acceptance": "BLOCKED_NOT_APPROVED",
        "policy": "Neutral studio previews are visual inspection evidence only; they do not prove source identity, texture correctness, attachment fit or runtime acceptance.",
        "records": records,
    }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if not files:
        raise SystemExit("No equipment candidate GLBs found")
    if any(r["status"] != "RENDERED_DIAGNOSTIC" for r in records):
        raise SystemExit("One or more equipment candidate previews failed")

if __name__ == "__main__":
    main()
