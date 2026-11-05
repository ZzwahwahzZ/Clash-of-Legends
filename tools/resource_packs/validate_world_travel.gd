extends SceneTree

func _initialize() -> void:
	call_deferred("_run_travel_test")

func _run_travel_test() -> void:
	var player := CharacterBody3D.new()
	player.name = "TravelTestPlayer"
	get_root().add_child(player)
	var game_manager := get_root().get_node_or_null("GameManager")
	if game_manager == null:
		game_manager = Node.new()
		game_manager.name = "GameManager"
		game_manager.set_script(load("res://tools/resource_packs/TravelTestGameManager.gd"))
		get_root().add_child(game_manager)
	game_manager.call("register_player", player)
	var manager: Node = (load("res://scripts/world/WorldTravelManager.gd") as Script).new()
	get_root().add_child(manager)
	await process_frame
	var destinations: Dictionary = manager.get_destinations()
	if destinations.size() < 7:
		_fail("World travel catalog must expose at least seven regions.")
		return
	if not manager.travel_to("twin_plains", "manual"):
		_fail("Manual instant travel to Twin Plains was rejected.")
		return
	if manager.get_current_destination_id() != "twin_plains" or player.global_position.distance_to(Vector3(20.0, 0.15, 16.0)) > 0.01:
		_fail("Manual instant travel did not move the player to the registered destination.")
		return
	if not manager.travel_to("mountain_summit", "quest"):
		_fail("Quest instant travel to Mountain Summit was rejected.")
		return
	if manager.get_current_destination_id() != "mountain_summit" or player.global_position.distance_to(Vector3(38.0, 0.15, -35.0)) > 0.01:
		_fail("Quest instant travel did not move the player to the quest region.")
		return
	if manager.travel_to("unknown_city", "manual"):
		_fail("Unknown travel destination was incorrectly accepted.")
		return
	var hud := load("res://scenes/ui/MainHUD.tscn") as PackedScene
	if hud == null:
		_fail("Main HUD scene could not be loaded.")
		return
	var hud_instance := hud.instantiate()
	var travel_button := hud_instance.get_node_or_null("TopRight/MenuButtons/TravelBtn")
	if travel_button == null:
		_fail("World map travel button is missing from the main HUD.")
		return
	print("WORLD TRAVEL AUDIT PASSED: ", destinations.size(), " destinations; manual teleport, quest teleport, invalid-destination rejection and HUD access verified.")
	hud_instance.free()
	manager.free()
	player.free()
	quit(0)

func _fail(message: String) -> void:
	push_error("WORLD TRAVEL AUDIT FAILED: " + message)
	quit(1)
