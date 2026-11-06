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
 var top:=Camera3D.new()
 top.projection=Camera3D.PROJECTION_ORTHOGONAL
 top.size=360.0
 top.position=Vector3(0,360,-55)
 root.add_child(top)
 top.look_at(Vector3(0,0,-55),Vector3.FORWARD)
 top.current=true
 await _capture("reports/phase1_urban_infill_topdown.png")
 var oblique:=Camera3D.new()
 oblique.fov=50.0
 oblique.position=Vector3(90,65,110)
 root.add_child(oblique)
 oblique.look_at(Vector3(0,5,-10),Vector3.UP)
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
