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
