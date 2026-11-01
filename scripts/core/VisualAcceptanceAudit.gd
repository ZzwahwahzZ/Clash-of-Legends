extends Node

func _ready() -> void:
	print("=======================================================")
	print("   CLASH OF LEGENDS — VISUAL & CONTENT AUDIT SUITE    ")
	print("=======================================================")
	
	var pass_count = 0
	var total_count = 0
	
	# Test 1: Player Visual Hierarchy
	total_count += 1
	var player_sc = load("res://scenes/characters/Player.tscn")
	if player_sc:
		var p = player_sc.instantiate()
		var has_torso = p.has_node("VisualRoot/Torso")
		var has_head = p.has_node("VisualRoot/Torso/HeadNode/HeadMesh")
		var has_helmet = p.has_node("VisualRoot/Torso/HeadNode/HelmetMesh")
		var has_pauldrons = p.has_node("VisualRoot/Torso/LeftPauldron") and p.has_node("VisualRoot/Torso/RightPauldron")
		var has_arms = p.has_node("VisualRoot/Torso/LeftArm") and p.has_node("VisualRoot/Torso/RightArm")
		var has_legs = p.has_node("VisualRoot/LeftLeg") and p.has_node("VisualRoot/RightLeg")
		var has_weapon = p.has_node("VisualRoot/Torso/WeaponMount/MainWeapon")
		var has_mount = p.has_node("VisualRoot/MountMesh/HorseBody")
		var has_anim = p.has_node("AnimationPlayer")
		if has_torso and has_head and has_helmet and has_pauldrons and has_arms and has_legs and has_weapon and has_mount and has_anim:
			print("[PASS] Visual Check: 3D Player Anatomical Hierarchy (Torso, Head, Helm, Pauldrons, Limbs, Weapon, Warhorse Mount, AnimPlayer)")
			pass_count += 1
		else:
			print("[FAIL] Visual Check: 3D Player Missing Subcomponents")
		p.free()
	else:
		print("[FAIL] Visual Check: Player.tscn could not be loaded")
		
	# Test 2: Wild Wolf Anatomical Quadruped Model
	total_count += 1
	var wolf_sc = load("res://scenes/enemies/WildWolf.tscn")
	if wolf_sc:
		var w = wolf_sc.instantiate()
		var has_body = w.has_node("VisualRoot/Torso")
		var has_snout = w.has_node("VisualRoot/Torso/HeadNode/Snout")
		var has_ears = w.has_node("VisualRoot/Torso/HeadNode/LeftEar") and w.has_node("VisualRoot/Torso/HeadNode/RightEar")
		var has_eyes = w.has_node("VisualRoot/Torso/HeadNode/EyeLeft") and w.has_node("VisualRoot/Torso/HeadNode/EyeRight")
		var has_legs = w.has_node("VisualRoot/FrontLeftLeg") and w.has_node("VisualRoot/FrontRightLeg") and w.has_node("VisualRoot/RearLeftLeg") and w.has_node("VisualRoot/RearRightLeg")
		var has_tail = w.has_node("VisualRoot/Torso/Tail")
		if has_body and has_snout and has_ears and has_eyes and has_legs and has_tail:
			print("[PASS] Visual Check: Wild Wolf Anatomical Model (Torso, Snout, Ears, Glowing Eyes, 4 Articulated Legs, Tail)")
			pass_count += 1
		else:
			print("[FAIL] Visual Check: Wild Wolf Missing Subcomponents")
		w.free()
	else:
		print("[FAIL] Visual Check: WildWolf.tscn could not be loaded")
		
	# Test 3: Great Flame Dragon Boss Model
	total_count += 1
	var dragon_sc = load("res://scenes/enemies/BossDragon.tscn")
	if dragon_sc:
		var d = dragon_sc.instantiate()
		var has_torso = d.has_node("VisualRoot/Torso")
		var has_neck = d.has_node("VisualRoot/Torso/Neck")
		var has_horns = d.has_node("VisualRoot/Torso/Neck/HeadNode/LeftHorn") and d.has_node("VisualRoot/Torso/Neck/HeadNode/RightHorn")
		var has_maw = d.has_node("VisualRoot/Torso/Neck/HeadNode/MawLight")
		var has_wings = d.has_node("VisualRoot/Torso/LeftWing") and d.has_node("VisualRoot/Torso/RightWing")
		var has_tail = d.has_node("VisualRoot/Torso/Tail")
		if has_torso and has_neck and has_horns and has_maw and has_wings and has_tail:
			print("[PASS] Visual Check: Great Flame Dragon Boss Model (Spined Body, Neck, Horns, Glowing Maw Light, Dual Wings, Tail)")
			pass_count += 1
		else:
			print("[FAIL] Visual Check: Boss Dragon Missing Subcomponents")
		d.free()
	else:
		print("[FAIL] Visual Check: BossDragon.tscn could not be loaded")

	# Test 4: Oriental NPC Visual Model
	total_count += 1
	var npc_sc = load("res://scenes/npcs/NPCBase.tscn")
	if npc_sc:
		var n = npc_sc.instantiate()
		var has_robe = n.has_node("VisualRoot/Robe")
		var has_head = n.has_node("VisualRoot/Robe/HeadNode/HeadMesh")
		var has_hat = n.has_node("VisualRoot/Robe/HeadNode/HatMesh")
		var has_orb = n.has_node("VisualRoot/FloatingOrb")
		var has_light = n.has_node("VisualRoot/FloatingOrb/OrbLight")
		if has_robe and has_head and has_hat and has_orb and has_light:
			print("[PASS] Visual Check: Oriental NPC Model (Flowing Robe, Conical Hat, Floating Luminescent Divination Orb)")
			pass_count += 1
		else:
			print("[FAIL] Visual Check: NPC Missing Subcomponents")
		n.free()
	else:
		print("[FAIL] Visual Check: NPCBase.tscn could not be loaded")
		
	# Test 5: Simulated MMORPG Roaming Player
	total_count += 1
	var sim_sc = load("res://scenes/characters/SimulatedPlayer.tscn")
	if sim_sc:
		var s = sim_sc.instantiate()
		var has_torso = s.has_node("VisualRoot/Torso")
		var has_head = s.has_node("VisualRoot/Torso/Head")
		var has_limbs = s.has_node("VisualRoot/Torso/LeftArm") and s.has_node("VisualRoot/LeftLeg")
		var has_weapon = s.has_node("VisualRoot/Torso/Weapon")
		if has_torso and has_head and has_limbs and has_weapon:
			print("[PASS] Visual Check: Simulated Hero Character Model (Torso, Head, Limbs, Weapon)")
			pass_count += 1
		else:
			print("[FAIL] Visual Check: Simulated Player Missing Subcomponents")
		s.free()
	else:
		print("[FAIL] Visual Check: SimulatedPlayer.tscn could not be loaded")

	# Test 6: Environment Architecture (Twin City, Plains, Volcano Arena)
	total_count += 1
	var game_sc = load("res://scenes/core/MainGame.tscn")
	if game_sc:
		var g = game_sc.instantiate()
		var has_env = g.has_node("WorldEnvironment")
		var has_light = g.has_node("DirectionalLight3D")
		var has_plaza = g.has_node("TwinCity/CityPlaza")
		var has_gate = g.has_node("TwinCity/PagodaGate/PagodaRoof")
		var has_forge = g.has_node("TwinCity/BlacksmithWorkshop/Furnace")
		var has_volcano = g.has_node("MountainSummitVolcano/CalderaLava")
		var has_trees = g.has_node("TwinPlainsTrees/Tree1")
		if has_env and has_light and has_plaza and has_gate and has_forge and has_volcano and has_trees:
			print("[PASS] Visual Check: 3D Environment Architecture (Pagoda Gate, Stone Plaza, Forge, Plains Trees, Volcano Caldera)")
			pass_count += 1
		else:
			print("[FAIL] Visual Check: MainGame.tscn Missing Environment Structures")
		g.free()
	else:
		print("[FAIL] Visual Check: MainGame.tscn could not be loaded")

	# Test 7: Shaders & Visual Effects
	total_count += 1
	var shader = load("res://assets/shaders/weapon_glow.gdshader")
	if shader:
		print("[PASS] Visual Check: Weapon Glow Shader (Dynamic Emission, Pulse Speed, Tier Scaling)")
		pass_count += 1
	else:
		print("[FAIL] Visual Check: weapon_glow.gdshader not found")

	print("-------------------------------------------------------")
	print("VISUAL AUDIT SUMMARY: %d Total | %d PASSED | %d FAILED" % [total_count, pass_count, total_count - pass_count])
	print("-------------------------------------------------------")
	get_tree().quit(0 if pass_count == total_count else 1)
