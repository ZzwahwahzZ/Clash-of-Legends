extends SceneTree

func _initialize() -> void:
	call_deferred("_run_travel_test")

func _run_travel_test() -> void:
	var source_catalog := QuestSourceCatalog.new()
	if not source_catalog.load_catalog():
		_fail("Source-backed Mobile quest catalog could not be loaded: " + source_catalog.status)
		return
	var source_counts: Dictionary = source_catalog.get_counts()
	if int(source_counts.get("missions", 0)) != 2509:
		_fail("Expected 2509 unique source missions, got %s." % str(source_counts.get("missions", 0)))
		return
	if int(source_counts.get("maps", 0)) != 411:
		_fail("Expected 411 unique source map records, got %s." % str(source_counts.get("maps", 0)))
		return
	var source_mission := source_catalog.get_mission("650")
	if source_mission.is_empty() or str(source_mission.get("finish_npc", {}).get("npc_id", "")) != "0004":
		_fail("Source mission 650 did not preserve its Armorer turn-in NPC reference.")
		return
	if source_catalog.get_map("1002").is_empty():
		_fail("Twin City source map ID 1002 is missing from the imported map catalog.")
		return
	if source_catalog.get_missions_for_npc("4", "finish_npc").is_empty():
		_fail("Exact source NPC lookup did not resolve the Armorer mission.")
		return
	print("QUEST SOURCE CATALOG AUDIT PASSED: ", source_counts)

	var quest_graph := QuestRuntimeGraph.new()
	if not quest_graph.load_graph():
		_fail("Source quest dependency graph failed to load.")
		return
	var graph_summary: Dictionary = quest_graph.get_world_summary()
	if int(graph_summary.get("missions", 0)) != 2509 or int(graph_summary.get("map_ids", 0)) != 411:
		_fail("Quest graph counts are inconsistent: %s" % str(graph_summary))
		return
	var city_hubs: Array = graph_summary.get("city_hubs", [])
	if city_hubs.size() != 6:
		_fail("Expected Twin City plus five source-named smaller city hubs, got %d." % city_hubs.size())
		return
	var has_main_city := false
	var minor_city_count := 0
	var missing_city_maps: Array[String] = []
	for hub in city_hubs:
		if str(hub.get("map_id", "")) == "1002" and str(hub.get("kind", "")) == "main":
			has_main_city = true
		if str(hub.get("kind", "")) == "minor":
			minor_city_count += 1
		if str(hub.get("status", "")).contains("MAP_RESOURCE_INDEX_MISSING"):
			missing_city_maps.append(str(hub.get("map_id", "")))
	if not has_main_city or minor_city_count != 5:
		_fail("Main/minor city hierarchy is incomplete: %s" % str(city_hubs))
		return
	if quest_graph.is_available("650", [], 8, "10"):
		_fail("Mission 650 bypassed its prerequisite mission 608.")
		return
	if not quest_graph.is_available("650", ["608"], 8, "10"):
		_fail("Mission 650 did not unlock for a valid level/profession after prerequisite 608.")
		return
	if quest_graph.is_available("650", ["608"], 7, "10") or quest_graph.is_available("650", ["608"], 8, "99"):
		_fail("Mission 650 ignored its source level or profession restrictions.")
		return
	var npc_offers := quest_graph.get_available_at_npc("2001", ["608"], 8, "10")
	var armorer_offer_found := false
	for offer in npc_offers:
		if str(offer.get("id", "")) == "650":
			armorer_offer_found = true
	if not armorer_offer_found:
		_fail("Source NPC 2001 did not expose the unlocked Armorer quest.")
		return
	var blacksmith_placements := quest_graph.get_npc_placements("0005", "1002")
	if blacksmith_placements.is_empty() or str(blacksmith_placements[0].get("name", "")) != "Blacksmith":
		_fail("Source NPC placement crosswalk did not resolve Blacksmith 0005 in Twin City.")
		return
	var armorer_placements := quest_graph.get_npc_placements("0004", "1002")
	if armorer_placements.is_empty():
		_fail("Source NPC placement crosswalk did not resolve Armorer 0004 in Twin City.")
		return
	var armorer_route := quest_graph.get_route("650", true)
	if str(armorer_route.get("npc_id", "")) != "0004" or str(armorer_route.get("map_id", "")) != "1002":
		_fail("Source quest graph did not resolve mission 650 turn-in route.")
		return
	print("QUEST GRAPH AUDIT PASSED: ", graph_summary, " | city map IDs missing resource index: ", missing_city_maps)

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
