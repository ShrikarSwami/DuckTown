extends Node2D
# Main.gd - Initializes all game systems and NPCs

func _ready():
	print("\n🦆 DuckTown Starting...\n")
	
	# Initialize core systems
	_setup_gemini_client()
	_setup_rumor_system()
	_setup_quest_manager()
	_setup_npcs()
	_setup_debug_overlay()
	
	print("✅ All systems initialized\n")

func _setup_gemini_client() -> void:
	"""Create and initialize the Gemini API client"""
	var gemini = Node.new()
	gemini.name = "GeminiClient"
	gemini.set_script(load("res://scripts/gemini_client.gd"))
	add_child(gemini)
	print("✓ GeminiClient initialized")

func _setup_rumor_system() -> void:
	"""Create and initialize the rumor propagation system"""
	var rumor_system = Node.new()
	rumor_system.name = "RumorSystem"
	rumor_system.set_script(load("res://scripts/rumor_system.gd"))
	add_child(rumor_system)
	print("✓ RumorSystem initialized")

func _setup_quest_manager() -> void:
	"""Create and initialize the quest/approval tracker"""
	var quest_manager = Node.new()
	quest_manager.name = "QuestManager"
	quest_manager.set_script(load("res://scripts/quest_manager.gd"))
	add_child(quest_manager)
	print("✓ QuestManager initialized")

func _setup_npcs() -> void:
	"""Set NPC properties for the controlled demo path"""
	# Wait for scene to be fully loaded
	await get_tree().create_timer(0.1).timeout
	
	var npcs = get_tree().get_nodes_in_group("npc")
	print("Found %d NPCs in scene" % npcs.size())
	
	# Define NPCs we need for the demo (matching scene node names)
	var npc_configs = {
		"Npc_Baker": { "npc_id": "baker", "traits": ["hospitable", "hardworking"], "initial_trust": 0 },
		"Npc_Mom": { "npc_id": "mom", "traits": ["gossipy", "caring"], "initial_trust": 10 },
		"Npc_merchGuy": { "npc_id": "merch", "traits": ["business-minded"], "initial_trust": 0 },
		"Npc_niceGuard": { "npc_id": "guard", "traits": ["duty-bound", "fair"], "initial_trust": 0 },
		"Npc_Mayor": { "npc_id": "mayor", "traits": ["diplomatic"], "initial_trust": -20 }
	}
	
	for npc in npcs:
		var npc_name = npc.name
		if npc_name in npc_configs:
			var config = npc_configs[npc_name]
			npc.npc_id = config["npc_id"]
			npc.display_name = config["npc_id"].capitalize()
			
			# Add interaction component
			if not npc.has_node("NPC_Interaction"):
				var interaction = Node2D.new()
				interaction.name = "NPC_Interaction"
				interaction.set_script(load("res://scripts/npc_interaction.gd"))
				npc.add_child(interaction)
				
				interaction.npc_id = config["npc_id"]
				interaction.npc_name = config["npc_id"].capitalize()
				interaction.personality_traits = config["traits"]
				interaction.initial_relationship = config["initial_trust"]
				interaction.current_relationship = config["initial_trust"]
			
			print("✓ Configured NPC: %s (id: %s, trust: %d)" % [npc_name, config["npc_id"], config["initial_trust"]])
		else:
			# Configure generic NPCs
			if npc.npc_id == "npc_generic":
				npc.npc_id = npc.name.to_lower().replace("npc_", "")
			print("✓ Generic NPC: %s" % npc.name)

func _setup_debug_overlay() -> void:
	"""Create debug overlay for showing game state"""
	var debug_overlay = CanvasLayer.new()
	debug_overlay.name = "DebugOverlay"
	debug_overlay.layer = 100
	add_child(debug_overlay)
	
	var debug_label = Label.new()
	debug_label.name = "DebugLabel"
	debug_label.set_script(load("res://scripts/debug_overlay.gd"))
	debug_label.text = "[Press D to toggle debug info]"
	debug_label.add_theme_font_size_override("font_size", 12)
	debug_label.position = Vector2(10, 10)
	debug_label.size = Vector2(400, 600)
	debug_overlay.add_child(debug_label)
	
	print("✓ Debug overlay created")
