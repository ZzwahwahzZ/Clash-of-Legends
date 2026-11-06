extends SceneTree

const REQUIRED_SCENES := [
	"res://scenes/characters/Player.tscn",
	"res://scenes/enemies/WildWolf.tscn",
	"res://scenes/enemies/BossDragon.tscn"
]

func _initialize() -> void:
	call_deferred("_run_audit")

func _run_audit() -> void:
	var passed := 0
	var shape_total := 0
	for scene_path in REQUIRED_SCENES:
		var packed := ResourceLoader.load(scene_path) as PackedScene
		if packed == null:
			_fail("Could not load physics test scene: " + scene_path)
			return
		var body := packed.instantiate()
		if not body is CollisionObject3D:
			_fail("Scene root is not a CollisionObject3D: " + scene_path)
			body.free()
			return
		var collision_body := body as CollisionObject3D
		if collision_body.collision_layer == 0 or collision_body.collision_mask == 0:
			_fail("Collision layer or mask is zero: " + scene_path)
			body.free()
			return
		var shapes := body.find_children("*", "CollisionShape3D", true, false)
		var valid_shapes := 0
		for node in shapes:
			var collision_shape := node as CollisionShape3D
			if collision_shape == null or collision_shape.disabled or collision_shape.shape == null:
				continue
			if not _shape_has_valid_dimensions(collision_shape.shape):
				continue
			var ancestor := collision_shape.get_parent()
			while ancestor != null and not ancestor is CollisionObject3D:
				ancestor = ancestor.get_parent()
			if ancestor == null:
				continue
			valid_shapes += 1
		if valid_shapes == 0:
			_fail("No valid enabled collision shapes found: " + scene_path)
			body.free()
			return
		var visual_meshes := body.find_children("*", "MeshInstance3D", true, false)
		var valid_meshes := 0
		for node in visual_meshes:
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
				var bounds := mesh_instance.get_aabb()
				if bounds.size.x > 0.0001 and bounds.size.y > 0.0001 and bounds.size.z > 0.0001:
					valid_meshes += 1
		var deferred_c3_visual := false
		if valid_meshes == 0 and scene_path == "res://scenes/characters/Player.tscn":
			var visual_root := body.get_node_or_null("VisualRoot")
			var vat_animator := body.get_node_or_null("C3VatAnimator")
			var animator_script: Script = null
			if vat_animator != null:
				animator_script = vat_animator.get_script() as Script
			deferred_c3_visual = visual_root is Node3D and animator_script != null and animator_script.resource_path.ends_with("C3VatCharacterAnimator.gd")
		if valid_meshes == 0 and not deferred_c3_visual:
			_fail("No renderable visual meshes or validated deferred C3 model loader found beside physics body: " + scene_path)
			body.free()
			return
		shape_total += valid_shapes
		var visual_status := "deferred_source_C3_VAT_loader" if deferred_c3_visual else str(valid_meshes)
		print("PHYSICS SCENE OK: ", scene_path, " | collision_shapes=", valid_shapes, " | visual_meshes=", visual_status, " | layer=", collision_body.collision_layer, " | mask=", collision_body.collision_mask)
		passed += 1
		body.free()
	print("PHYSICS SHAPE AUDIT PASSED: ", passed, "/", REQUIRED_SCENES.size(), " scenes; ", shape_total, " enabled collision shapes.")
	quit(0)

func _shape_has_valid_dimensions(shape: Shape3D) -> bool:
	if shape is CapsuleShape3D:
		return shape.radius > 0.0 and shape.height >= shape.radius * 2.0
	if shape is BoxShape3D:
		return shape.size.x > 0.0 and shape.size.y > 0.0 and shape.size.z > 0.0
	if shape is CylinderShape3D:
		return shape.radius > 0.0 and shape.height > 0.0
	if shape is SphereShape3D:
		return shape.radius > 0.0
	return true

func _fail(message: String) -> void:
	push_error("PHYSICS SHAPE AUDIT FAILED: " + message)
	quit(1)
