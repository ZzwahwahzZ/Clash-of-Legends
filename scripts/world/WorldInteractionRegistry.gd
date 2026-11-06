extends RefCounted
class_name WorldInteractionRegistry

## Resolves stable semantic world IDs to authored scene nodes.
## The returned position is a reference only; quest movement must project it
## onto a validated NavigationRegion3D before issuing a movement command.

const REGISTRY_PATH := "res://assets/environment/phase1/jianghai/interaction_anchors.json"

var _world_root: Node3D
var _anchors: Dictionary = {}

func bind_world(world_root: Node3D) -> bool:
	if world_root == null:
		push_error("WorldInteractionRegistry requires a world root.")
		return false
	_world_root = world_root
	var file := FileAccess.open(REGISTRY_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open interaction anchor registry: " + REGISTRY_PATH)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary) or not (parsed.get("anchors", []) is Array):
		push_error("Interaction anchor registry has an invalid schema.")
		return false
	_anchors.clear()
	for entry in parsed["anchors"]:
		if not (entry is Dictionary):
			continue
		var anchor_id := str(entry.get("id", ""))
		var node_path := str(entry.get("node_path", ""))
		if anchor_id.is_empty() or node_path.is_empty() or _anchors.has(anchor_id):
			push_error("Invalid or duplicate interaction anchor entry: " + anchor_id)
			return false
		_anchors[anchor_id] = entry.duplicate(true)
	return true

func get_anchor_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for anchor_id in _anchors.keys():
		ids.append(str(anchor_id))
	ids.sort()
	return ids

func get_anchor_definition(anchor_id: String) -> Dictionary:
	if not _anchors.has(anchor_id):
		return {}
	return (_anchors[anchor_id] as Dictionary).duplicate(true)

func resolve_anchor_node(anchor_id: String) -> Node3D:
	if _world_root == null or not _anchors.has(anchor_id):
		return null
	var definition: Dictionary = _anchors[anchor_id]
	var node := _world_root.get_node_or_null(NodePath(str(definition.get("node_path", ""))))
	return node as Node3D

func get_anchor_target(anchor_id: String) -> Dictionary:
	var definition := get_anchor_definition(anchor_id)
	var node := resolve_anchor_node(anchor_id)
	if definition.is_empty() or node == null:
		return {"ok": false, "anchor_id": anchor_id}
	return {
		"ok": true,
		"anchor_id": anchor_id,
		"node": node,
		"reference_position": node.global_position,
		"requires_navmesh_projection": bool(definition.get("requires_navmesh_projection", true)),
		"requires_runtime_trigger": bool(definition.get("requires_runtime_trigger", true)),
		"interaction_enabled": bool(definition.get("interaction_enabled", false)),
		"npc_spawn_anchor": bool(definition.get("npc_spawn_anchor", false))
	}

func validate_world_bindings() -> PackedStringArray:
	var missing := PackedStringArray()
	for anchor_id in get_anchor_ids():
		if resolve_anchor_node(anchor_id) == null:
			missing.append(anchor_id)
	return missing

func is_interaction_enabled(anchor_id: String) -> bool:
	var definition := get_anchor_definition(anchor_id)
	return not definition.is_empty() and bool(definition.get("interaction_enabled", false))

func get_navigation_path(anchor_id: String, from_world_position: Vector3, navigation_map: RID, max_projection_distance: float = 8.0) -> Dictionary:
	if not navigation_map.is_valid():
		return {"ok": false, "reason": "navigation_map_unavailable", "anchor_id": anchor_id}
	var target := get_anchor_target(anchor_id)
	if not bool(target.get("ok", false)):
		return {"ok": false, "reason": "anchor_unresolved", "anchor_id": anchor_id}
	var projected_start := NavigationServer3D.map_get_closest_point(navigation_map, from_world_position)
	var projected_target := NavigationServer3D.map_get_closest_point(navigation_map, target["reference_position"])
	if projected_start.distance_to(from_world_position) > max_projection_distance:
		return {"ok": false, "reason": "start_outside_navigation_surface", "anchor_id": anchor_id}
	if projected_target.distance_to(target["reference_position"]) > max_projection_distance:
		return {"ok": false, "reason": "anchor_outside_navigation_surface", "anchor_id": anchor_id}
	var path := NavigationServer3D.map_get_path(navigation_map, projected_start, projected_target, true, 1)
	if path.size() < 2:
		return {"ok": false, "reason": "no_connected_route", "anchor_id": anchor_id}
	return {
		"ok": true,
		"anchor_id": anchor_id,
		"path": path,
		"start": projected_start,
		"target": projected_target,
		"waypoint_count": path.size()
	}

func get_npc_spawn_candidate(anchor_id: String) -> Dictionary:
	var definition := get_anchor_definition(anchor_id)
	var node := resolve_anchor_node(anchor_id)
	if definition.is_empty() or node == null or not definition.has("npc_id"):
		return {"ok": false, "reason": "npc_anchor_unavailable", "anchor_id": anchor_id}
	var offset_data: Array = definition.get("spawn_offset_local", [0.0, 0.0, 0.0])
	if offset_data.size() != 3:
		return {"ok": false, "reason": "invalid_spawn_offset", "anchor_id": anchor_id}
	var local_offset := Vector3(float(offset_data[0]), float(offset_data[1]), float(offset_data[2]))
	var candidate_position := node.global_transform * local_offset
	return {
		"ok": true,
		"npc_id": str(definition.get("npc_id", "")),
		"role": str(definition.get("role", "")),
		"anchor_id": anchor_id,
		"candidate_position": candidate_position,
		"spawn_enabled": bool(definition.get("spawn_enabled", false)),
		"requires_navmesh_projection": bool(definition.get("requires_navmesh_projection", true)),
		"requires_clearance_validation": bool(definition.get("requires_clearance_validation", true))
	}
