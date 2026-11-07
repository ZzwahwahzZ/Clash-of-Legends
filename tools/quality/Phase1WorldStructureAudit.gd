extends SceneTree

const CITY_PATH := "res://assets/environment/phase1/jianghai/full_city_preview.glb"
const REPORT_PATH := "reports/phase1_world_structure_audit.json"

var counts := {
	"mesh_instances": 0,
	"navigation_regions": 0,
	"collision_objects": 0,
	"static_bodies": 0,
	"collision_shapes": 0
}
var pawnshop_nodes: Array = []
var navigation_nodes: Array = []
var street_nodes: Array = []
var semantic_anchor_nodes: Array = []
var major_city_sections: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load(CITY_PATH) as PackedScene
	if packed == null:
		_fail("Full city preview GLB could not be loaded.")
		return
	var city := packed.instantiate() as Node3D
	if city == null:
		_fail("Full city root is not Node3D.")
		return
	get_root().add_child(city)
	await process_frame
	_walk(city, "")
	var authored_root := city.get_node_or_null("JianghaiOldCityAuthoredScene")
	if authored_root != null:
		for section in authored_root.get_children():
			major_city_sections.append(_summarize_section(section))
	var pawnshop := city.get_node_or_null("JianghaiOldCityAuthoredScene/GuangchangPawnshop") as Node3D
	var candidate := Vector3.ZERO
	var pawnshop_transform := Transform3D.IDENTITY
	if pawnshop != null:
		pawnshop_transform = pawnshop.global_transform
		candidate = pawnshop.global_transform * Vector3(0.0, 0.0, 4.0)
	var anchor_file := FileAccess.open("res://assets/environment/phase1/jianghai/interaction_anchors.json", FileAccess.READ)
	if anchor_file != null:
		var anchor_data: Variant = JSON.parse_string(anchor_file.get_as_text())
		anchor_file.close()
		if anchor_data is Dictionary:
			for definition in anchor_data.get("anchors", []):
				if not (definition is Dictionary):
					continue
				var anchor_path := str(definition.get("node_path", ""))
				var anchor_node := city.get_node_or_null(NodePath(anchor_path))
				var anchor_row := {"id": str(definition.get("id", "")), "node_path": anchor_path, "resolved": anchor_node != null}
				if anchor_node is Node3D:
					anchor_row["type"] = anchor_node.get_class()
					anchor_row["position_global"] = _vector_to_array((anchor_node as Node3D).global_position)
					anchor_row["global_transform"] = _transform_to_array((anchor_node as Node3D).global_transform)
				if anchor_node is Node3D and definition.get("target_offset_local", []) is Array and definition.get("target_offset_local", []).size() == 3:
					var offset_data: Array = definition["target_offset_local"]
					var offset := Vector3(float(offset_data[0]), float(offset_data[1]), float(offset_data[2]))
					anchor_row["target_world"] = _vector_to_array((anchor_node as Node3D).global_transform * offset)
				if anchor_node is MeshInstance3D and (anchor_node as MeshInstance3D).mesh != null:
					var anchor_mesh := anchor_node as MeshInstance3D
					anchor_row["mesh_aabb_local"] = _aabb_to_array(anchor_mesh.get_aabb())
					if definition.get("target_offset_local", []) is Array and definition.get("target_offset_local", []).size() == 3:
						var target_data: Array = definition["target_offset_local"]
						var target_local := Vector3(float(target_data[0]), float(target_data[1]), float(target_data[2]))
						anchor_row["target_inside_anchor_mesh_aabb"] = anchor_mesh.get_aabb().has_point(target_local)
				anchor_row["descendant_meshes"] = []
				_collect_anchor_meshes(anchor_node, anchor_row["descendant_meshes"])
				semantic_anchor_nodes.append(anchor_row)
	var report := {
		"city_scene": CITY_PATH,
		"counts": counts,
		"pawnshop_parent_found": pawnshop != null,
		"pawnshop_parent_path": str(pawnshop.get_path()) if pawnshop != null else "",
		"pawnshop_parent_global_transform": _transform_to_array(pawnshop_transform),
		"pawnshop_candidate_from_local_offset_0_0_4": _vector_to_array(candidate),
		"pawnshop_hierarchy": pawnshop_nodes,
		"navigation_nodes": navigation_nodes,
		"street_network_nodes": street_nodes,
		"semantic_anchor_nodes": semantic_anchor_nodes,
		"major_city_sections": major_city_sections,
		"interpretation": "A NavigationRegion3D count of zero means no authored runtime navigation surface was found in the city GLB. A positive count still requires runtime map synchronization and route connectivity tests."
	}
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		_fail("Could not write " + REPORT_PATH)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("WORLD STRUCTURE AUDIT: ", JSON.stringify(report))
	if pawnshop == null:
		_fail("Pawnshop parent path did not resolve.")
		return
	if int(counts["navigation_regions"]) == 0:
		print("WORLD NAVIGATION STATUS: NO AUTHORED NAVIGATION REGION IN CITY GLB")
	quit(0)

func _walk(node: Node, relative_path: String) -> void:
	var path := relative_path
	if not str(node.name).is_empty():
		path = relative_path + "/" + str(node.name)
	if node is MeshInstance3D:
		counts["mesh_instances"] += 1
	if node is NavigationRegion3D:
		counts["navigation_regions"] += 1
		navigation_nodes.append({"path": path, "navigation_mesh_assigned": node.navigation_mesh != null})
	if node is CollisionObject3D:
		counts["collision_objects"] += 1
	if node is StaticBody3D:
		counts["static_bodies"] += 1
	if node is CollisionShape3D or node is CollisionPolygon3D:
		counts["collision_shapes"] += 1
	if path.contains("GuangchangPawnshop"):
		if node is Node3D:
			var spatial := node as Node3D
			pawnshop_nodes.append({
				"path": path,
				"type": node.get_class(),
				"position_local": _vector_to_array(spatial.position),
				"position_global": _vector_to_array(spatial.global_position),
				"global_transform": _transform_to_array(spatial.global_transform),
				"mesh_aabb_local": _aabb_to_array((node as MeshInstance3D).get_aabb()) if node is MeshInstance3D and (node as MeshInstance3D).mesh != null else []
			})
		else:
			pawnshop_nodes.append({"path": path, "type": node.get_class()})
	if path.contains("AuthoredStreetNetwork"):
		var street_row := {"path": path, "type": node.get_class()}
		if node is Node3D:
			street_row["position_global"] = _vector_to_array((node as Node3D).global_position)
			street_row["global_transform"] = _transform_to_array((node as Node3D).global_transform)
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			street_row["mesh_aabb_local"] = _aabb_to_array((node as MeshInstance3D).get_aabb())
		street_nodes.append(street_row)
	for child in node.get_children():
		_walk(child, path)

func _summarize_section(section: Node) -> Dictionary:
	var meshes: Array = []
	_collect_section_meshes(section, meshes)
	var combined := AABB()
	var has_bounds := false
	var structural: Array = []
	var decorative: Array = []
	for row in meshes:
		var bounds_data: Array = row.get("mesh_aabb_world", [])
		if bounds_data.size() == 2:
			var bounds := AABB(Vector3(float(bounds_data[0][0]), float(bounds_data[0][1]), float(bounds_data[0][2])), Vector3(float(bounds_data[1][0]), float(bounds_data[1][1]), float(bounds_data[1][2])))
			combined = bounds if not has_bounds else combined.merge(bounds)
			has_bounds = true
		var mesh_name := str(row.get("name", "")).to_lower()
		if _looks_structural(mesh_name): structural.append(row)
		else: decorative.append(row)
	return {"name": str(section.name), "path": str(section.get_path()), "node_count": _count_descendants(section), "mesh_count": meshes.size(), "structural_name_candidates": structural, "decorative_or_unclassified_meshes": decorative, "world_bounds": _aabb_to_array(combined) if has_bounds else []}

func _collect_section_meshes(node: Node, rows: Array) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh_node := node as MeshInstance3D
		rows.append({"name": str(mesh_node.name), "path": str(mesh_node.get_path()), "mesh_aabb_world": _aabb_to_array(mesh_node.global_transform * mesh_node.get_aabb())})
	for child in node.get_children(): _collect_section_meshes(child, rows)

func _count_descendants(node: Node) -> int:
	var total := 1
	for child in node.get_children(): total += _count_descendants(child)
	return total

func _looks_structural(mesh_name: String) -> bool:
	for token in ["wall", "roof", "column", "pillar", "foundation", "stair", "gate", "door", "arch", "beam", "bridge", "curb", "railing", "fence"]:
		if mesh_name.contains(token): return true
	return false
func _collect_anchor_meshes(node: Node, rows: Array) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh_node := node as MeshInstance3D
		rows.append({
			"path": str(mesh_node.get_path()),
			"global_position": _vector_to_array(mesh_node.global_position),
			"mesh_aabb_local": _aabb_to_array(mesh_node.get_aabb()),
			"mesh_aabb_world": _aabb_to_array(mesh_node.global_transform * mesh_node.get_aabb())
		})
	for child in node.get_children():
		_collect_anchor_meshes(child, rows)

func _vector_to_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _transform_to_array(value: Transform3D) -> Array:
	return [
		[value.basis.x.x, value.basis.x.y, value.basis.x.z],
		[value.basis.y.x, value.basis.y.y, value.basis.y.z],
		[value.basis.z.x, value.basis.z.y, value.basis.z.z],
		_vector_to_array(value.origin)
	]

func _aabb_to_array(value: AABB) -> Array:
	return [_vector_to_array(value.position), _vector_to_array(value.size)]

func _fail(message: String) -> void:
	push_error("WORLD STRUCTURE AUDIT FAILED: " + message)
	quit(1)
