extends SceneTree
const CITY_PATH := "res://assets/environment/phase1/jianghai/chinese_district.glb"
const ANCHOR := Vector3(-86.001892, 1.2787764, -122.576271)
const CANDIDATES := [
 ["WestNorthArcade","JianghaiDensity_WestInfill01",-52.0,48.0,1.1],
 ["WestNorthHall","JianghaiDensity_WestInfill00",-70.0,48.0,1.05],
 ["EastNorthArcade","JianghaiDensity_EastInfill01",52.0,48.0,1.1],
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
 get_root().get_viewport().size = Vector2i(1280,720)
 var packed := load(CITY_PATH) as PackedScene
 if packed == null:
  push_error("City GLB import missing.")
  quit(2)
  return
 var city := packed.instantiate() as Node3D
 city.position = -ANCHOR
 get_root().add_child(city)
 await process_frame
 for c in CANDIDATES:
  var template := city.find_child(c[1],true,false) as Node3D
  if template == null:
   push_error("Missing template: "+str(c[1]))
   quit(3)
   return
  var clone := template.duplicate() as Node3D
  clone.name = "AUDIT_ONLY_"+str(c[0])
  city.add_child(clone)
  clone.position = Vector3(float(c[2]),0.03,float(c[3]))
  clone.scale = template.scale * float(c[4])
 print("AUDIT ONLY INFILL CLONES: ",CANDIDATES.size())
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees=Vector3(-48,32,0)
 sun.shadow_enabled=true
 get_root().add_child(sun)
 var cam:=Camera3D.new()
 cam.projection=Camera3D.PROJECTION_ORTHOGONAL
 cam.size=360.0
 cam.position=Vector3(0,360,-55)
 get_root().add_child(cam)
 cam.look_at(Vector3(0,0,-55),Vector3.FORWARD)
 cam.current=true
 await _capture("reports/phase1_urban_infill_topdown.png")
 var cam2:=Camera3D.new()
 cam2.fov=48.0
 cam2.position=Vector3(190,145,225)
 get_root().add_child(cam2)
 cam2.look_at(Vector3(0,4,-55),Vector3.UP)
 cam2.current=true
 await _capture("reports/phase1_urban_infill_oblique.png")
 quit(0)
func _capture(path:String)->void:
 await process_frame
 await process_frame
 await process_frame
 var img:=get_root().get_viewport().get_texture().get_image()
 if img.save_png(path)!=OK:
  push_error("Could not save "+path)
  quit(4)
