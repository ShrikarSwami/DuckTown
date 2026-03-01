extends Node2D
# Main.gd - Initializes all game systems and NPCs

const VERBOSE_DEBUG := false

const PARTY_VIDEO_PATH := "res://assets/Video/Party.webm"
const PARTY_AUDIO_PATH := "res://assets/Audio/Party.wav"
const PARTY_VIDEO_CACHE_KEY := "party_video_stream"
const PARTY_AUDIO_CACHE_KEY := "party_audio_stream"

# Demo run tracking
var demo_run_count: int = 0

func _ready():
	print("\n🦆 DuckTown Starting...\n")
	_preload_party_media()
	
	# Check if this is a restart
	if get_tree().root.has_meta("demo_run_count"):
		demo_run_count = get_tree().root.get_meta("demo_run_count")
	demo_run_count += 1
	get_tree().root.set_meta("demo_run_count", demo_run_count)
	
	print("=== DEMO RUN #%d ===" % demo_run_count)
	
	# Initialize core systems
	_setup_gemini_client()
	_setup_rumor_system()
	_setup_quest_manager()
	_setup_trust_hud()
	_setup_npcs()
	_setup_debug_overlay()
	_show_intro_message()
	
	print("[Main] Pond collision enabled")
	print("✅ All systems initialized\n")

func _preload_party_media() -> void:
	"""Preload party media to avoid first-play hitch, and cache references on SceneTree root."""
	var root = get_tree().root

	var cached_video: VideoStream = null
	if root.has_meta(PARTY_VIDEO_CACHE_KEY):
		cached_video = root.get_meta(PARTY_VIDEO_CACHE_KEY) as VideoStream
	if cached_video == null:
		cached_video = load(PARTY_VIDEO_PATH) as VideoStream
		if cached_video != null:
			root.set_meta(PARTY_VIDEO_CACHE_KEY, cached_video)

	var cached_audio: AudioStream = null
	if root.has_meta(PARTY_AUDIO_CACHE_KEY):
		cached_audio = root.get_meta(PARTY_AUDIO_CACHE_KEY) as AudioStream
	if cached_audio == null:
		cached_audio = load(PARTY_AUDIO_PATH) as AudioStream
		if cached_audio != null:
			root.set_meta(PARTY_AUDIO_CACHE_KEY, cached_audio)

	if cached_video == null:
		push_warning("[Main] Failed to preload party video: %s" % PARTY_VIDEO_PATH)
	if cached_audio == null:
		push_warning("[Main] Failed to preload party audio: %s" % PARTY_AUDIO_PATH)

	if cached_video != null and cached_audio != null:
		print("✓ Party media preloaded and cached")

func get_demo_run_count() -> int:
	"""Get the current demo run count"""
	return demo_run_count

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return

	var key_event := event as InputEventKey
	if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F9:
		_print_demo_status_snapshot()

func _print_demo_status_snapshot() -> void:
	var player_name := "Player"
	if get_tree().root.has_meta("player_name"):
		player_name = str(get_tree().root.get_meta("player_name"))

	var trust := _get_demo_trust_snapshot()

	var baker_approved := false
	var merch_approved := false
	var mean_guard_approved := false
	var demo_phase := -1

	var quest_manager = get_node_or_null("QuestManager")
	if quest_manager:
		if quest_manager.has_method("is_approved"):
			baker_approved = bool(quest_manager.is_approved("baker"))
			merch_approved = bool(quest_manager.is_approved("merch"))
			mean_guard_approved = bool(quest_manager.is_approved("meanGuard"))
		if quest_manager.has_method("get_demo_phase"):
			demo_phase = int(quest_manager.get_demo_phase())

	var scene_name := "Unknown"
	var current_scene = get_tree().get_current_scene()
	if current_scene:
		scene_name = current_scene.name

	print("[F9] player=%s trust{baker:%d merch:%d meanGuard:%d} approvals{bakerApproved:%s merchApproved:%s meanGuardApproved:%s} phase=%d scene=%s" % [
		player_name,
		int(trust["baker"]),
		int(trust["merch"]),
		int(trust["meanGuard"]),
		_bool_to_tf(baker_approved),
		_bool_to_tf(merch_approved),
		_bool_to_tf(mean_guard_approved),
		demo_phase,
		scene_name
	])

func _get_demo_trust_snapshot() -> Dictionary:
	var trust := {
		"baker": 0,
		"merch": 0,
		"meanGuard": 0
	}

	for npc in get_tree().get_nodes_in_group("npc"):
		var npc_id_value = npc.get("npc_id")
		var npc_id = str(npc_id_value) if npc_id_value != null else ""
		if not trust.has(npc_id):
			continue

		var trust_value: int = 0
		var interaction = npc.get_node_or_null("NPC_Interaction")
		if interaction:
			var current_relationship = interaction.get("current_relationship")
			if typeof(current_relationship) == TYPE_INT or typeof(current_relationship) == TYPE_FLOAT:
				trust_value = int(current_relationship)
		elif npc.has_method("get_relationship"):
			trust_value = int(npc.get_relationship())

		trust[npc_id] = trust_value

	return trust

func _bool_to_tf(value: bool) -> String:
	return "T" if value else "F"

func _setup_gemini_client() -> void:
	"""Create and initialize the Gemini API client"""
	var gemini = Node.new()
	gemini.name = "GeminiClient"
	gemini.set_script(load("res://scripts/gemini_client.gd"))
	add_child(gemini)
	if VERBOSE_DEBUG:
		print("✓ GeminiClient initialized")

func _setup_rumor_system() -> void:
	"""Create and initialize the rumor propagation system"""
	var rumor_system = Node.new()
	rumor_system.name = "RumorSystem"
	rumor_system.set_script(load("res://scripts/rumor_system.gd"))
	add_child(rumor_system)
	if VERBOSE_DEBUG:
		print("✓ RumorSystem initialized")

func _setup_quest_manager() -> void:
	"""Create and initialize the quest/approval tracker"""
	var quest_manager = Node.new()
	quest_manager.name = "QuestManager"
	quest_manager.set_script(load("res://scripts/quest_manager.gd"))
	add_child(quest_manager)
	if VERBOSE_DEBUG:
		print("✓ QuestManager initialized")

func _setup_trust_hud() -> void:
	"""Create the pinned trust HUD for demo"""
	var trust_hud_layer = CanvasLayer.new()
	trust_hud_layer.name = "TrustHUDLayer"
	trust_hud_layer.layer = 99  # Below debug overlay
	add_child(trust_hud_layer)
	
	# Create main HUD container
	var hud_panel = PanelContainer.new()
	hud_panel.name = "TrustHUD"
	hud_panel.position = Vector2(10, 10)
	hud_panel.custom_minimum_size = Vector2(200, 120)
	trust_hud_layer.add_child(hud_panel)
	
	# Create VBox for labels
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	hud_panel.add_child(vbox)
	
	# Title label
	var title_label = Label.new()
	title_label.text = "=== DEMO HUD ==="
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color(1, 0.8, 0))
	vbox.add_child(title_label)
	
	# NPC trust labels
	var demo_npcs = ["baker", "merch", "meanGuard"]
	
	var trust_controller = Control.new()
	trust_controller.name = "TrustController"
	trust_controller.set_script(load("res://scripts/trust_hud.gd"))
	hud_panel.add_child(trust_controller)
	
	for npc_id in demo_npcs:
		var label = Label.new()
		label.name = npc_id.capitalize() + "Label"
		label.text = "%s: 0" % npc_id.capitalize()
		label.add_theme_font_size_override("font_size", 12)
		vbox.add_child(label)
		
		# Register label with controller
		trust_controller.call_deferred("register_npc", npc_id, label)
	
	if VERBOSE_DEBUG:
		print("✓ Trust HUD created")

func _setup_npcs() -> void:
	"""Set NPC properties for the controlled demo path"""
	# Wait for scene to be fully loaded
	await get_tree().create_timer(0.1).timeout
	
	# Get the dialogue UI (should exist from UI scene instance)
	var dialogue_ui = get_tree().get_first_node_in_group("dialogue_ui")
	if dialogue_ui == null:
		push_error("[Main] No DialogueUI found in group! Make sure UI.tscn is instantiated and DialogueUI is in 'dialogue_ui' group.")
	else:
		if VERBOSE_DEBUG:
			print("[Main] Found DialogueUI successfully")
	
	var npcs = get_tree().get_nodes_in_group("npc")
	var town_roam_points = _collect_town_roam_points()
	print("Found %d NPCs in scene" % npcs.size())
	
	# Define NPCs we need for the demo (matching scene node names)
	var npc_configs = {
		"Npc_Baker": { "npc_id": "baker", "traits": ["hospitable", "hardworking"], "initial_trust": 0 },
		"Npc_Mom": { "npc_id": "mom", "traits": ["gossipy", "caring"], "initial_trust": 10 },
		"Npc_merchGuy": { "npc_id": "merch", "traits": ["business-minded"], "initial_trust": 0 },
		"Npc_niceGuard": { "npc_id": "guard", "traits": ["duty-bound", "fair"], "initial_trust": 0 },
		"Npc_meanGuard": { "npc_id": "meanGuard", "traits": ["tough", "protective"], "initial_trust": -10 },
		"Npc_Mayor": { "npc_id": "mayor", "traits": ["diplomatic"], "initial_trust": -20 }
	}
	
	for npc in npcs:
		var npc_name = npc.name
		if npc.has_method("set_roam_points"):
			npc.set_roam_points(town_roam_points)
		npc.wander_radius = 220.0
		npc.change_dir_time = randf_range(0.9, 1.6)
		npc.speed = randf_range(55.0, 75.0)

		if npc_name in npc_configs:
			var config = npc_configs[npc_name]
			npc.npc_id = config["npc_id"]
			npc.display_name = config["npc_id"].capitalize()
			
			# Update name tag if it exists
			var name_tag = npc.get_node_or_null("NameTag")
			if name_tag and name_tag is Label:
				name_tag.text = npc.display_name
			
			# Add (or reuse) interaction component
			var interaction: Node2D = npc.get_node_or_null("NPC_Interaction") as Node2D
			if interaction == null:
				interaction = Node2D.new()
				interaction.name = "NPC_Interaction"
				interaction.set_script(load("res://scripts/npc_interaction.gd"))
				npc.add_child(interaction)

			interaction.npc_id = config["npc_id"]
			interaction.npc_name = config["npc_id"].capitalize()
			interaction.personality_traits = config["traits"]
			interaction.initial_relationship = config["initial_trust"]
			interaction.current_relationship = config["initial_trust"]

			# Inject single authoritative DialogueUI for all NPC interactions
			interaction.dialogue_ui = dialogue_ui
			if dialogue_ui == null:
				push_error("[Main] Could not inject dialogue_ui into %s - dialogue_ui is null" % npc_name)
			else:
				print("[Main] Injected dialogue_ui into %s" % npc_name)
			
			print("✓ Configured NPC: %s (id: %s, trust: %d)" % [npc_name, config["npc_id"], config["initial_trust"]])
		else:
			# Configure generic NPCs
			if npc.npc_id == "npc_generic":
				npc.npc_id = npc.name.to_lower().replace("npc_", "")
			print("✓ Generic NPC: %s" % npc.name)

func _collect_town_roam_points() -> Array[Vector2]:
	"""Collect marker positions so NPCs can drift across town square"""
	var points: Array[Vector2] = []
	var marker_nodes = get_tree().get_nodes_in_group("npc_spawn_marker")
	if marker_nodes.is_empty():
		var fallback_parent = get_node_or_null("NPCSpawns")
		if fallback_parent:
			marker_nodes = _find_marker_children(fallback_parent)

	for marker in marker_nodes:
		if marker is Marker2D:
			points.append((marker as Marker2D).global_position)

	if points.is_empty():
		points = [
			Vector2(250, 225), Vector2(520, 225), Vector2(820, 225), Vector2(1120, 225),
			Vector2(240, 620), Vector2(560, 620), Vector2(860, 620), Vector2(1350, 720),
			Vector2(1400, 400)
		]

	return points

func _find_marker_children(root: Node) -> Array:
	var nodes: Array = []
	for child in root.get_children():
		if child is Marker2D:
			nodes.append(child)
		nodes.append_array(_find_marker_children(child))
	return nodes

func _setup_debug_overlay() -> void:
	"""Create debug overlay for showing game state"""
	var debug_overlay = CanvasLayer.new()
	debug_overlay.name = "DebugOverlay"
	debug_overlay.layer = 100
	add_child(debug_overlay)
	
	var debug_label = Label.new()
	debug_label.name = "DebugLabel"
	debug_label.set_script(load("res://scripts/debug_overlay.gd"))
	debug_label.text = "[Press Q to toggle debug info]"
	debug_label.add_theme_font_size_override("font_size", 12)
	debug_label.position = Vector2(10, 10)
	debug_label.size = Vector2(400, 600)
	debug_overlay.add_child(debug_label)
	
	print("✓ Debug overlay created")

func _show_intro_message() -> void:
	"""Show a Gemini-powered intro message when the game starts"""
	await get_tree().create_timer(0.5).timeout  # Wait for systems to initialize
	
	var player_name = "Player"
	if get_tree().root.has_meta("player_name"):
		player_name = str(get_tree().root.get_meta("player_name"))
	
	var gemini_client = get_node_or_null("GeminiClient")
	if gemini_client == null:
		_show_fallback_intro(player_name)
		return
	
	# Build a simple request for the intro message
	var request_data = {
		"npc_id": "narrator",
		"npc_name": "Narrator",
		"player_name": player_name,
		"npc_personality": {
			"traits": ["helpful", "enthusiastic"],
			"speech_pattern": "encouraging",
			"current_mood": "excited"
		},
		"player_message": "Write a short 3-5 sentence welcome to DuckTown addressed to %s. You MUST mention Baker, Merch, and the Guard. Keep the meaning the same but vary the wording and tone slightly each run. End with a clear instruction to talk to Baker first. Output plain text only. Variation seed: %s" % [player_name, str(Time.get_unix_time_from_system())],
		"player_relationship": 100,
		"dialogue_history": [],
		"known_rumors": [],
		"town_context": {
			"party_goal": "Context: This is a short hackathon demo. The player is new to DuckTown and must help the Mayor set up the duck party by getting approval from Baker, Merch, and the Guard. The intro should explicitly reference these three roles by name."
		}
	}
	
	# Connect to response signal
	if gemini_client.has_signal("request_completed"):
		gemini_client.request_completed.connect(_on_intro_gemini_response, CONNECT_ONE_SHOT)
		gemini_client.request_failed.connect(_on_intro_gemini_failed, CONNECT_ONE_SHOT)
		gemini_client.call_api(request_data)
		print("[Main] Requesting intro message from Gemini...")
	else:
		_show_fallback_intro(player_name)

func _on_intro_gemini_response(response: Dictionary) -> void:
	"""Handle the intro message from Gemini"""
	var intro_text = ""
	
	if response.get("success", false):
		intro_text = response.get("npc_reply", "")
	
	if intro_text == "":
		var player_name = "Player"
		if get_tree().root.has_meta("player_name"):
			player_name = str(get_tree().root.get_meta("player_name"))
		_show_fallback_intro(player_name)
		return
	
	_display_intro_message(intro_text)
	print("[Main] Gemini intro message received")

func _on_intro_gemini_failed(error: String) -> void:
	"""Handle failed intro request"""
	print("[Main] Gemini intro failed: %s" % error)
	var player_name = "Player"
	if get_tree().root.has_meta("player_name"):
		player_name = str(get_tree().root.get_meta("player_name"))
	_show_fallback_intro(player_name)

func _show_fallback_intro(player_name: String) -> void:
	"""Show a hardcoded intro message if Gemini fails"""
	var intro_text = "Welcome to DuckTown, %s! The Mayor needs your help with the big duck party. Your first stop is the Baker, then check in with Merch, and make sure the Guard situation is handled. Go talk to the Baker to get started!" % player_name
	_display_intro_message(intro_text)

func _display_intro_message(message: String) -> void:
	"""Display the intro message in a temporary popup"""
	var intro_layer = CanvasLayer.new()
	intro_layer.name = "IntroMessageLayer"
	intro_layer.layer = 98
	add_child(intro_layer)
	
	# Create a centered panel
	var panel = PanelContainer.new()
	panel.position = Vector2(300, 350)
	panel.custom_minimum_size = Vector2(1000, 200)
	intro_layer.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	vbox.add_child(margin)
	
	var message_label = Label.new()
	message_label.text = message
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	message_label.custom_minimum_size = Vector2(960, 100)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 14)
	margin.add_child(message_label)
	
	var close_button = Button.new()
	close_button.text = "Got it!"
	close_button.custom_minimum_size = Vector2(200, 40)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(close_button)
	
	close_button.pressed.connect(func():
		intro_layer.queue_free()
		print("[Main] Intro message closed")
	)
	
	# Auto-close after 10 seconds
	get_tree().create_timer(10.0).timeout.connect(func():
		if intro_layer and is_instance_valid(intro_layer):
			intro_layer.queue_free()
	)
	
	print("[Main] Intro message displayed")
