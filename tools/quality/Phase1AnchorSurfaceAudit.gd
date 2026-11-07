extends SceneTree

const CITY_PATH := "res://assets/environment/phase1/jianghai/full_city_preview.glb"
const REPORT_PATH := "reports/phase1_anchor_surface_candidates.json"
const TARGETS := {
	"jianghai.hotel_frontage": Vector3(-11.6, 0.0, -34.5),
	"jianghai.medicine_frontage": Vector3(11.6, 0.0, -48.0),
	"jianghai.tea_frontage": Vector3(11.6, 0.0, -8.0)
}

var _floor_meshes: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load(CITY_PATH) as PackedScene
	if packed == null:
		_fail("Could not load city GLB.")
		return
	var city := packed.instantiate() as Node3D
	if city == null:
		_fail("City root is not Node3D.")
		return
	get_root().add_child(city)
	await process_frame
	_collect_floor_meshes(city)
	var target_rows: Array[Dictionary] = []
	for anchor_id in TARGETS:
		var target: Vector3 = TARGETS[anchor_id]
		var candidates: Array[Dictionary] = []
		for row in _floor_meshes:
			var bounds: AABB = row["bounds"]
			var probe := Vector3(target.x, bounds.get_center().y, target.z)
			var closest := bounds.get_closest_point(probe)
			var horizontal_distance := Vector2(closest.x, closest.z).distance_to(Vector2(target.x, target.z))
			var vertical_distance := absf(bounds.get_center().y - target.y)
			var score := horizontal_distance + vertical_distance * 0.75
			if horizontal_distance <= 12.0:
				candidates.append({
					"path": row["path"],
					"name": row["name"],
					"world_bounds": _aabb(bounds),
					"closest_point": _vec(closest),
					"horizontal_distance": horizontal_distance,
					"vertical_distance": vertical_distance,
					"score": score
				})
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) < float(b["score"]))
		var top: Array = candidates.slice(0, mini(15, candidates.size()))
		target_rows.append({
			"anchor_id": anchor_id,
			"current_reference": _vec(target),
			"candidate_count_within_12m": candidates.size(),
			"nearest_walk_surface_candidates": top
		})
	var report := {
		"city_scene": CITY_PATH,
		"floor_like_mesh_count": _floor_meshes.size(),
		"selection_rule": "Mesh AABB vertical thickness <= 0.45 and horizontal area >= 0.75; candidates sorted by horizontal plus weighted vertical distance. This is a discovery audit, not proof of walkability.",
		"targets": target_rows
	}
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		_fail("Could not write surface candidate report.")
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("PHASE1 ANCHOR SURFACE CANDIDATES: ", JSON.stringify(report))
	quit(0)

func _collect_floor_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh != null:
			var bounds := mesh_node.global_transform * mesh_node.get_aabb()
			var horizontal_area := bounds.size.x * bounds.size.z
			if bounds.size.y <= 0.45 and horizontal_area >= 0.75:
				_floor_meshes.append({
					"path": str(mesh_node.get_path()),
					"name": str(mesh_node.name),
					"bounds": bounds
				})
	for child in node.get_children():
		_collect_floor_meshes(child)

func _vec(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _aabb(value: AABB) -> Array:
	return [_vec(value.position), _vec(value.size)]

func _fail(message: String) -> void:
	push_error("PHASE1 ANCHOR SURFACE AUDIT FAILED: " + message)
	quit(1)
