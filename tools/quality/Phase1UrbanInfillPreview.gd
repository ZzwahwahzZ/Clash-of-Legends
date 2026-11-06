extends SceneTree

const CITY_PATH := "res://assets/environment/phase1/jianghai/full_city_preview.glb"
const SOURCE_GATE_ANCHOR := Vector3(-86.001892, 1.2787764, -122.576271)
const CANDIDATES := [
 ["WestNorthArcade","JianghaiDensity_WestInfill01",-52.0,48.0,1.10],
 ["WestNorthHall","JianghaiDensity_WestInfill00",-70.0,48.0,1.05],
 ["EastNorthArcade","JianghaiDensity_EastInfill01",52.0,48.0,1.10],
 ["EastNorthHall","JianghaiDensity_EastInfill00",70.0,48.0,1.05],
 ["WestMidArcade","JianghaiDensity_WestInfill01",-52.0,-62.0,1.08],
 ["WestMidShop","JianghaiDensity_EastInfill02",-70.0,-62.0,0.92],
 ["EastMidArcade","JianghaiDensity_EastInfill01",52.0,-62.0,1.08],
 ["EastMidShop","JianghaiDensity_WestInfill02",70.0,-62.0,0.92],
 ["WestSouthArcade","JianghaiDensity_WestInfill03",-52.0,-145.0,1.05],
 ["WestSouthHall","JianghaiDensity_EastInfill04",-70.0,-145.0,0.88],
 ["EastSouthArcade","JianghaiDensity_EastInfill03",52.0,-145.0,1.05],
 ["EastSouthHall","JianghaiDensity_WestInfill04",70.0,-145.0,0.88]
]

func _initialize() -> void:
 call_deferred("_run")

func _run() -> void:
 get_root().get_viewport().size=Vector2i(960,540)
 var root:=Node3D.new()
 root.name="UrbanInfillAuditOnly"
 get_root().add_child(root)
 _add_audit_environment(root)
 var packed:=load(CITY_PATH) as PackedScene
 if packed==null:
  push_error("Full city preview GLB did not import.")
  quit(2)
  return
 var city:=packed.instantiate() as Node3D
 if city==null:
  push_error("Full city root is not Node3D.")
  quit(2)
  return
 root.add_child(city)
 await process_frame
 city.position=-SOURCE_GATE_ANCHOR
 _tint_landscape(city)
 await process_frame
 var placed:=0
 for c in CANDIDATES:
  var template:=city.find_child(str(c[1]),true,false) as Node3D
  if template==null:
   push_error("Missing source template: "+str(c[1]))
   quit(3)
   return
  var original_parent:=template.get_parent()
  if original_parent==null:
   push_error("Template has no authored parent: "+str(c[1]))
   quit(3)
   return
  var clone:=template.duplicate() as Node3D
  if clone==null:
   push_error("Template duplication failed: "+str(c[1]))
   quit(3)
   return
  clone.name="AUDIT_ONLY_"+str(c[0])
  original_parent.add_child(clone)
  clone.transform=template.transform
  clone.position=Vector3(float(c[2]),float(template.position.y),float(c[3]))
  clone.scale=template.scale*float(c[4])
  placed+=1
 print("AUDIT ONLY INFILL CLONES: ",placed)
 print("Candidate placements use the original JianghaiTenementDistrict parent coordinate system.")
 var district:=city.find_child("JianghaiTenementDistrict",true,false)
 if district==null:
  push_error("JianghaiTenementDistrict not found for bounds audit.")
  quit(5)
  return
 var district_bounds:=_subtree_bounds(district)
 if district_bounds.size==Vector3.ZERO:
  push_error("Could not calculate district bounds.")
  quit(5)
  return
 _write_bounds_audit(district,root)
 var focus:=district_bounds.get_center()
 var top:=Camera3D.new()
 top.projection=Camera3D.PROJECTION_ORTHOGONAL
 top.size=maxf(district_bounds.size.x,district_bounds.size.z)*1.18
 top.position=Vector3(focus.x,focus.y+360.0,focus.z)
 root.add_child(top)
 top.look_at(focus,Vector3.FORWARD)
 top.current=true
 await _capture("reports/phase1_urban_infill_topdown.png")
 var oblique:=Camera3D.new()
 oblique.fov=50.0
 oblique.position=focus+Vector3(95,75,115)
 root.add_child(oblique)
 oblique.look_at(focus+Vector3(0,5,0),Vector3.UP)
 oblique.current=true
 await _capture("reports/phase1_urban_infill_oblique.png")
 quit(0)

func _add_audit_environment(root:Node3D)->void:
 var world:=WorldEnvironment.new()
 var environment:=Environment.new()
 environment.background_mode=Environment.BG_SKY
 var sky:=Sky.new()
 var mat:=ProceduralSkyMaterial.new()
 mat.sky_top_color=Color(0.12,0.36,0.68)
 mat.sky_horizon_color=Color(0.55,0.72,0.86)
 mat.sky_curve=0.22
 mat.ground_bottom_color=Color(0.09,0.12,0.14)
 mat.ground_horizon_color=Color(0.40,0.48,0.52)
 mat.ground_curve=0.18
 mat.sky_energy_multiplier=1.0
 mat.ground_energy_multiplier=0.55
 sky.sky_material=mat
 environment.sky=sky
 environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 environment.ambient_light_color=Color(0.55,0.66,0.82)
 environment.ambient_light_energy=1.0
 environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
 environment.fog_enabled=true
 environment.fog_light_color=Color(0.55,0.68,0.76)
 environment.fog_light_energy=0.38
 environment.fog_density=0.001
 environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
 environment.tonemap_exposure=0.98
 world.environment=environment
 root.add_child(world)
 var sun:=DirectionalLight3D.new()
 sun.rotation_degrees=Vector3(-42,28,0)
 sun.light_color=Color(0.98,0.90,0.78)
 sun.light_energy=1.03
 sun.shadow_enabled=true
 root.add_child(sun)
 var fill:=DirectionalLight3D.new()
 fill.rotation_degrees=Vector3(-18,-148,0)
 fill.light_color=Color(0.55,0.66,0.82)
 fill.light_energy=0.62
 root.add_child(fill)

func _tint_landscape(node:Node)->void:
 if node is MeshInstance3D:
  var instance:=node as MeshInstance3D
  var label=(instance.name+" "+(instance.mesh.resource_name if instance.mesh!=null else "")).to_lower()
  var tint:=Color.WHITE
  var apply:=true
  if label.contains("perimetergroundcomposite"):
   tint=Color(0.42,0.58,0.28)
  elif label.contains("mountainmassif"):
   tint=Color(0.65,0.62,0.56)
  elif label.contains("oldcityfoundation"):
   tint=Color(0.62,0.54,0.42)
  else:
   apply=false
  if apply and instance.mesh!=null:
   for surface in range(instance.mesh.get_surface_count()):
    var source:=instance.get_active_material(surface)
    if source is StandardMaterial3D:
     var material:StandardMaterial3D=(source as StandardMaterial3D).duplicate()
     material.albedo_color=tint
     material.roughness=0.92
     instance.set_surface_override_material(surface,material)
 for child in node.get_children():
  _tint_landscape(child)

func _capture(path:String)->void:
 await process_frame
 await process_frame
 await process_frame
 var image:=get_root().get_viewport().get_texture().get_image()
 if image.save_png(path)!=OK:
  push_error("Could not save preview: "+path)
  quit(4)

func _subtree_bounds(node:Node)->AABB:
 var found:=false
 var result:=AABB()
 if node is MeshInstance3D:
  var mesh_node:=node as MeshInstance3D
  if mesh_node.mesh!=null:
   result=mesh_node.global_transform*mesh_node.get_aabb()
   found=true
 for child in node.get_children():
  var child_bounds:=_subtree_bounds(child)
  if child_bounds.size!=Vector3.ZERO:
   result=result.merge(child_bounds) if found else child_bounds
   found=true
 return result if found else AABB()

func _write_bounds_audit(district:Node,root:Node3D)->void:
 var rows:Array=[]
 var authored_meshes:Array=[]
 _collect_authored_mesh_bounds(root,authored_meshes)
 for child in district.get_children():
  if str(child.name).begins_with("AUDIT_ONLY_"):
   var b:=_subtree_bounds(child)
   var building_overlaps:Array=[]
   var street_overlaps:Array=[]
   var terrain_overlaps:Array=[]
   for source in authored_meshes:
    var sb:AABB=source["bounds"]
    var overlap_x:=minf(b.end.x,sb.end.x)-maxf(b.position.x,sb.position.x)
    var overlap_z:=minf(b.end.z,sb.end.z)-maxf(b.position.z,sb.position.z)
    if overlap_x<=0.35 or overlap_z<=0.35:
     continue
    var overlap_y:=minf(b.end.y,sb.end.y)-maxf(b.position.y,sb.position.y)
    var volume:=maxf(0.0,overlap_x)*maxf(0.0,overlap_y)*maxf(0.0,overlap_z)
    if bool(source["terrain"]):
     terrain_overlaps.append({"path":source["path"],"name":source["name"],"overlap_xz_area":snappedf(overlap_x*overlap_z,0.01)})
    elif bool(source["road"]):
     street_overlaps.append({"path":source["path"],"name":source["name"],"overlap_xz_area":snappedf(overlap_x*overlap_z,0.01)})
    elif overlap_y>0.35 and volume>0.5:
     building_overlaps.append({"path":source["path"],"name":source["name"],"overlap_volume":snappedf(volume,0.01)})
   rows.append({
    "candidate":str(child.name),
    "center":[b.get_center().x,b.get_center().y,b.get_center().z],
    "size":[b.size.x,b.size.y,b.size.z],
    "min":[b.position.x,b.position.y,b.position.z],
    "max":[b.end.x,b.end.y,b.end.z],
    "authored_building_overlap_count":building_overlaps.size(),
    "authored_building_overlaps":building_overlaps,
    "street_network_overlap_count":street_overlaps.size(),
    "street_network_overlaps":street_overlaps,
    "terrain_overlap_count":terrain_overlaps.size(),
    "terrain_overlaps":terrain_overlaps,
    "placement_status":"REJECT" if building_overlaps.size()>0 or street_overlaps.size()>0 else "REVIEW_VISUAL_AND_NAV",\n    "_audit_aabb":b,\n    "candidate_overlaps":[]
   })
 for i in range(rows.size()):
  for j in range(i+1,rows.size()):
   var a:AABB=rows[i]["_audit_aabb"]
   var b:AABB=rows[j]["_audit_aabb"]
   var ox:=minf(a.end.x,b.end.x)-maxf(a.position.x,b.position.x)
   var oz:=minf(a.end.z,b.end.z)-maxf(a.position.z,b.position.z)
   var oy:=minf(a.end.y,b.end.y)-maxf(a.position.y,b.position.y)
   if ox>0.35 and oz>0.35 and oy>0.35:
    var detail={"other_candidate":rows[j]["candidate"],"overlap_volume":snappedf(ox*oy*oz,0.01)}
    var reverse={"other_candidate":rows[i]["candidate"],"overlap_volume":snappedf(ox*oy*oz,0.01)}
    rows[i]["candidate_overlaps"].append(detail)
    rows[j]["candidate_overlaps"].append(reverse)
 for row in rows:
  if row["candidate_overlaps"].size()>0:
   row["placement_status"]="REJECT"
  row.erase("_audit_aabb")
 var report={
  "district_bounds":_aabb_dict(_subtree_bounds(district)),
  "candidate_bounds":rows,
  "authored_mesh_count":authored_meshes.size(),
  "audit_method":"World-space transformed mesh AABBs; building overlap requires XZ overlap >0.35, Y overlap >0.35 and volume >0.5. Road and terrain overlaps are classified separately. Any building or road overlap rejects the candidate pending visual review.",
  "note":"All candidate clones are audit-only and are not written to the source GLB."
 }
 var file:=FileAccess.open("reports/phase1_urban_infill_bounds.json",FileAccess.WRITE)
 if file==null:
  push_error("Could not write bounds audit JSON.")
  return
 file.store_string(JSON.stringify(report,"  "))
 file.close()
 print("URBAN INFILL BOUNDS AUDIT: ",JSON.stringify(report))

func _collect_authored_mesh_bounds(node:Node,rows:Array)->void:
 if node is MeshInstance3D and not _has_audit_ancestor(node):
  var instance:=node as MeshInstance3D
  if instance.mesh!=null:
   var label: String=(str(instance.name)+" "+str(instance.get_path())+" "+instance.mesh.resource_name).to_lower()
   var terrain:=label.contains("terrain") or label.contains("groundcomposite") or label.contains("foundation") or label.contains("utilitycable")
   var road:=label.contains("authoredstreetnetwork") or label.contains("street") or label.contains("road") or label.contains("avenue") or label.contains("curb") or label.contains("cross") or label.contains("lane") or label.contains("bridge") or label.contains("ramp") or label.contains("pawnshopapproach")
   rows.append({"name":str(instance.name),"path":str(instance.get_path()),"road":road and not terrain,"terrain":terrain,"bounds":instance.global_transform*instance.get_aabb()})
 for child in node.get_children():
  _collect_authored_mesh_bounds(child,rows)

func _has_audit_ancestor(node:Node)->bool:
 var current:Node=node
 while current!=null:
  if str(current.name).begins_with("AUDIT_ONLY_"):
   return true
  current=current.get_parent()
 return false

func _aabb_dict(b:AABB)->Dictionary:
 return {"min":[b.position.x,b.position.y,b.position.z],"max":[b.end.x,b.end.y,b.end.z],"size":[b.size.x,b.size.y,b.size.z],"center":[b.get_center().x,b.get_center().y,b.get_center().z]}
