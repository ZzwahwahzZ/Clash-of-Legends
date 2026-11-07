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
	var localized_mission := source_catalog.get_mission("650")
	if str(localized_mission.get("name_ar", "")) != "تاجر الملابس الحربية" or str(localized_mission.get("content_ar", "")).is_empty():
		_fail("Arabic localized mission title/content were not preserved in the runtime catalog.")
		return
	var source_mission := localized_mission
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
	var expected_city_ids := ["1002", "1000", "1010", "1011", "1015", "1020"]
	var found_city_ids: Array[String] = []
	for hub in city_hubs:
		found_city_ids.append(str(hub.get("map_id", "")))
	for expected_city_id in expected_city_ids:
		if not found_city_ids.has(expected_city_id):
			_fail("Source city hub %s is missing from the runtime city registry." % expected_city_id)
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
	if not quest_graph.is_available_for_class("650", ["608"], 8, "Monk"):
		_fail("Source profession ID 10 did not resolve the Monk quest restriction.")
		return
	if not quest_graph.is_available_for_class("650", ["608"], 8, "Pirate") or not quest_graph.is_available_for_class("650", ["608"], 8, "DragonWarrior"):
		_fail("Source profession IDs 12/14 did not resolve their class quest restrictions.")
		return
	if quest_graph.is_available_for_class("650", ["608"], 8, "Trojan") or quest_graph.is_available_for_class("650", ["608"], 8, "Thunderstriker"):
		_fail("Quest profession filtering admitted a class without a matching verified source ID.")
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
	if int(graph_summary.get("map_directory", 0)) != 92:
		_fail("Expected 92 source map directory entries, got %s." % str(graph_summary.get("map_directory", 0)))
		return
	var desert_city := quest_graph.get_map_directory_entry("1000")
	var bird_island := quest_graph.get_map_directory_entry("1015")
	var ape_city := quest_graph.get_map_directory_entry("1020")
	var birth_village := quest_graph.get_map_directory_entry("1010")
	if str(desert_city.get("resource_path", "")) != "map/map/desert.7z" or str(bird_island.get("resource_path", "")) != "map/map/island.7z" or str(ape_city.get("resource_path", "")) != "map/map/canyon.7z":
		_fail("Source map directory did not resolve the smaller-city resource paths.")
		return
	if str(birth_village.get("status", "")) != "MAP_RESOURCE_MISSING_FROM_INDEX":
		_fail("Birth Village missing-map status was not preserved.")
		return
	var whorf_dialogue := quest_graph.get_dialogue_links("5455")
	if whorf_dialogue.is_empty():
		_fail("Source dialogue linkage for mission 5455 was not imported.")
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
	var source_agent := QuestNavigationAgent.new()
	get_root().add_child(source_agent)
	await process_frame
	source_agent.completed_source_mission_ids.append("608")
	if not source_agent.select_source_mission_at_npc("650", "2001", 8, "Monk"):
		_fail("Source quest 650 could not be accepted at its exact start NPC for an eligible class.")
		return
	source_agent.on_source_npc_talked("0004")
	var source_active_state: Dictionary = source_agent.get_source_active_state()
	if not bool(source_active_state.get("ready_to_turn_in", false)):
		_fail("Source NPC objective did not move mission 650 to ready-to-turn-in.")
		return
	if not source_agent.select_source_mission_at_npc("650", "0004", 8, "Monk"):
		_fail("Source quest 650 could not be turned in at its exact Armorer NPC.")
		return
	if not source_agent.completed_source_mission_ids.has("650"):
		_fail("Source quest turn-in did not record mission 650 as completed.")
		return
	source_agent.queue_free()
	print("QUEST GRAPH AUDIT PASSED: ", graph_summary, " | city map IDs missing resource index: ", missing_city_maps)

	var source_agent := QuestNavigationAgent.new()
	get_root().add_child(source_agent)
	await process_frame
	source_agent.completed_source_mission_ids.append("608")
	if not source_agent.activate_source_mission("650", 8, "10"):
		_fail("Source mission 650 could not be accepted after its prerequisite and profession gate.")
		return
	source_agent.on_source_npc_talked("0004")
	var source_state: Dictionary = source_agent.get_source_active_state()
	if not bool(source_state.get("ready_to_turn_in", false)):
		_fail("Source NPC objective did not move mission 650 to ready-to-turn-in.")
		return
	if not source_agent.complete_source_mission_turnin("650", "0004"):
		_fail("Source mission 650 was not safely turned in to its designated Armorer NPC.")
		return
	if not source_agent.completed_source_mission_ids.has("650"):
		_fail("Source mission 650 completion was not persisted in the runtime agent.")
		return
	print("SOURCE QUEST RUNTIME AUDIT PASSED: accept -> exact NPC objective -> designated turn-in.")
	source_agent.queue_free()

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
	var world_city_hubs: Array[Dictionary] = manager.get_source_city_hubs()
	if world_city_hubs.size() != 6:
		_fail("WorldTravelManager did not expose the six source city hubs.")
		return
	var desert_map: Dictionary = manager.get_source_map_directory_entry("1000")
	if str(desert_map.get("resource_path", "")) != "map/map/desert.7z":
		_fail("WorldTravelManager did not expose Desert City source map metadata.")
		return
	var destinations: Dictionary = manager.get_destinations()
	for city_id in expected_city_ids:
		var city_destination_id := "city_" + city_id
		if not destinations.has(city_destination_id):
			_fail("World map UI is missing source city destination %s." % city_destination_id)
			return
		var city_destination: Dictionary = destinations[city_destination_id]
		if city_id == "1002" and not bool(city_destination.get("enabled", false)):
			_fail("Main Twin City must remain an available world destination.")
			return
		if city_id != "1002" and bool(city_destination.get("enabled", false)):
			_fail("A minor city was exposed as travel-ready without a dedicated runtime scene: %s." % city_id)
			return
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
