import bpy, bmesh, json, os, sys, math
from mathutils import Vector

def mesh_stats(obj):
    bm=bmesh.new(); bm.from_mesh(obj.data); bm.verts.ensure_lookup_table(); bm.edges.ensure_lookup_table(); bm.faces.ensure_lookup_table()
    unseen=set(bm.verts); components=[]
    while unseen:
        seed=unseen.pop(); stack=[seed]; verts=[seed]
        while stack:
            v=stack.pop()
            for e in v.link_edges:
                other=e.other_vert(v)
                if other in unseen:
                    unseen.remove(other); stack.append(other); verts.append(other)
        face_ids={f.index for v in verts for f in v.link_faces}
        components.append({"vertices":len(verts),"faces":len(face_ids)})
    area=sum(f.calc_area() for f in bm.faces)
    degenerate=sum(1 for f in bm.faces if f.calc_area() <= 1e-12)
    boundary=sum(1 for e in bm.edges if len(e.link_faces)==1)
    nonmanifold=sum(1 for e in bm.edges if not e.is_manifold)
    loose=sum(1 for v in bm.verts if not v.link_edges)
    out={"vertices":len(bm.verts),"edges":len(bm.edges),"faces":len(bm.faces),"components":len(components),"component_sizes":sorted(components,key=lambda x:x["faces"],reverse=True),"surface_area":area,"degenerate_faces":degenerate,"boundary_edges":boundary,"nonmanifold_edges":nonmanifold,"loose_vertices":loose}
    bm.free(); return out

def mesh_bounds(objects):
    pts=[]
    for o in objects:
        if o.type=="MESH":
            pts.extend([o.matrix_world @ Vector(c) for c in o.bound_box])
    if not pts: return 0.0
    return max((max(p[i] for p in pts)-min(p[i] for p in pts) for i in range(3)),default=0.0)

def main():
    args=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    source_dir,out_dir=args[0],args[1]; os.makedirs(out_dir,exist_ok=True)
    records=[]
    for name in sorted(os.listdir(source_dir)):
        if not name.lower().endswith(".glb"): continue
        src=os.path.join(source_dir,name)
        bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete(use_global=False)
        bpy.ops.import_scene.gltf(filepath=src)
        meshes=[o for o in bpy.context.scene.objects if o.type=="MESH"]
        before=[mesh_stats(o) for o in meshes]
        bbox=mesh_bounds(meshes); eps=max(bbox*1e-8,1e-10)
        # Conservative, non-destructive cleanup: weld only near-identical vertices and dissolve only zero-length/degenerate edges.
        cleaned=[]
        for obj in meshes:
            bm=bmesh.new(); bm.from_mesh(obj.data)
            bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=eps)
            bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=eps)
            if bm.faces:
                bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
            bm.to_mesh(obj.data); bm.free(); obj.data.update()
            cleaned.append(mesh_stats(obj))
        out=os.path.join(out_dir,name.replace(".glb","_conservative_repair_candidate.glb"))
        bpy.ops.object.select_all(action="SELECT")
        bpy.ops.export_scene.gltf(filepath=out,export_format="GLB",use_selection=False,export_apply=False)
        records.append({"file":name,"source":src,"output":out,"bbox_diagonal":bbox,"weld_tolerance":eps,"mesh_count":len(meshes),"materials":[{"mesh":o.name,"slots":[m.name if m else None for m in o.material_slots]} for o in meshes],"before":before,"after":cleaned,"status":"CANDIDATE_REQUIRES_VISUAL_REVIEW"})
    with open(os.path.join(out_dir,"mount_repair_audit.json"),"w") as f: json.dump({"tool":"Blender bmesh conservative cleanup","blender_version":bpy.app.version_string,"policy":"Only near-coincident vertices and degenerate edges are processed; no disconnected islands are deleted; original files remain untouched.","records":records},f,indent=2)
    print("MOUNT_REPAIR_AUDIT_COUNT",len(records))
if __name__=="__main__": main()
