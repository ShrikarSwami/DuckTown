extends Node2D
# NPC interaction system - handles dialogue and relationship tracking

signal dialogue_started(npc_id: String)
signal dialogue_ended(npc_id: String)
signal relationship_changed(npc_id: String, new_value: int, delta: int)
signal rumor_generated(npc_id: String, rumor: Dictionary)

@export var npc_id: String = "unknown"
@export var npc_name: String = "Unknown NPC"
@export var personality_traits: Array = []  # Untyped to accept JSON arrays
@export var initial_relationship: int = 0

var current_relationship: int = 0
var dialogue_history: Array[Dictionary] = []
var known_rumors: Array[String] = []
var gemini_client: Node
var rumor_system: Node
var dialogue_ui: Node

var _waiting_for_gemini: bool = false

func _ready():
	current_relationship = initial_relationship
	
	# Find systems in the tree
	gemini_client = get_tree().root.get_node_or_null("Main/GeminiClient")
	dialogue_ui = get_tree().get_first_node_in_group("dialogue_ui")
	rumor_system = get_tree().root.get_node_or_null("Main/RumorSystem")
	
	if gemini_client and gemini_client.has_signal("request_completed"):
		gemini_client.request_completed.connect(_on_gemini_response)
		gemini_client.request_failed.connect(_on_gemini_error)
	
	print("[NPC %s] Initialized with %d initial relationship" % [npc_name, current_relationship])

func start_dialogue(player_message: String):
	"""
	Initiate dialogue with this NPC via Gemini API.
	Results come back asynchronously via signals.
	"""
	if _waiting_for_gemini:
		print("[NPC %s] Already waiting for response" % npc_name)
		return
	
	dialogue_started.emit(npc_id)
	
	# Add player message to history
	var player_entry = {
		"role": "player",
		"text": player_message
	}
	dialogue_history.append(player_entry)
	
	print("[NPC %s] Starting dialogue: '%s'" % [npc_name, player_message])
	
	# Build request to backend
	var quest_manager = get_tree().root.get_node_or_null("Main/QuestManager")
	var player_name = "Player"
	if get_tree().root.has_meta("player_name"):
		player_name = str(get_tree().root.get_meta("player_name"))

	var open_tasks: Array[String] = []
	var completed_tasks: Array[String] = []
	var focus_npcs: Array[String] = ["baker", "merch", "guard"]
	if quest_manager:
		if quest_manager.has_method("get_open_task_descriptions"):
			open_tasks = quest_manager.get_open_task_descriptions()
		if quest_manager.has_method("get_completed_task_descriptions"):
			completed_tasks = quest_manager.get_completed_task_descriptions()
		if quest_manager.has_method("get_focus_npc_ids"):
			focus_npcs = quest_manager.get_focus_npc_ids()

	var request_data = {
		"npc_id": npc_id,
		"npc_name": npc_name,
		"player_name": player_name,
		"npc_personality": {
			"traits": personality_traits,
			"speech_pattern": "natural",
			"current_mood": "neutral"
		},
		"player_message": player_message,
		"player_relationship": current_relationship,
		"dialogue_history": dialogue_history.slice(-10),  # Last 10 messages only
		"known_rumors": known_rumors,
		"active_tasks": open_tasks,
		"town_context": {
			"open_tasks": open_tasks,
			"completed_tasks": completed_tasks,
			"demo_focus": focus_npcs,
			"party_goal": "Help the mayor secure approvals for the duck party"
		}
	}
	
	_waiting_for_gemini = true
	print("[NPC %s] Calling Gemini API..." % npc_name)
	gemini_client.call_api(request_data)

func _on_gemini_response(response: Dictionary):
	"""Handle successful response from Gemini API"""
	if not _waiting_for_gemini:
		return
	
	_waiting_for_gemini = false
	
	if not response.get("success", false):
		print("[NPC %s] Gemini returned error: %s" % [npc_name, response.get("error", "unknown")])
		return
	
	print("[NPC %s] Gemini response received" % npc_name)
	
	# Extract dialogue
	var npc_reply = response.get("npc_reply", "...")
	print("[NPC %s] Reply: %s" % [npc_name, npc_reply])
	
	# Add NPC response to history
	var npc_entry = {
		"role": "npc",
		"text": npc_reply
	}
	dialogue_history.append(npc_entry)
	
	# Update relationship
	var rel_delta = response.get("relationship_delta", 0)
	if rel_delta != 0:
		update_relationship(rel_delta)
	
	# Handle rumor if present
	if response.has("rumor") and response["rumor"] != null:
		var rumor = response["rumor"]
		rumor_generated.emit(npc_id, rumor)
		if rumor_system:
			rumor_system.add_rumor(
				"%s_rumor_%d" % [npc_id, dialogue_history.size()],
				rumor.get("text", ""),
				npc_id,
				rumor.get("tags", [])
			)
	
	# Tell dialogue UI to show this response
	if dialogue_ui and dialogue_ui.has_method("set_npc_reply"):
		dialogue_ui.call("set_npc_reply", npc_reply)
	
	# Emit completion
	dialogue_ended.emit(npc_id)

func _on_gemini_error(error: String):
	"""Handle error from Gemini API"""
	_waiting_for_gemini = false
	print("[NPC %s] ERROR: %s" % [npc_name, error])
	
	if dialogue_ui and dialogue_ui.has_method("show_error"):
		dialogue_ui.call("show_error", error)

func update_relationship(delta: int):
	"""Update relationship score and clamp to [-100, 100]"""
	var old_value = current_relationship
	current_relationship = clampi(current_relationship + delta, -100, 100)
	
	print("[NPC %s] Relationship: %d → %d (delta: %+d)" % [npc_name, old_value, current_relationship, delta])
	
	relationship_changed.emit(npc_id, current_relationship, delta)

func get_relationship() -> int:
	"""Get current relationship score"""
	return current_relationship

func get_dialogue_options() -> Array[String]:
	"""Get suggested dialogue options for this NPC"""
	# TODO: Generate contextual options based on relationship and known rumors
	return [
		"Tell me about yourself",
		"Have you heard any rumors?",
		"I'd like to help"
	]

func end_dialogue():
	"""Called when player closes dialogue with this NPC"""
	# Rumor may auto-spread after dialogue ends
	dialogue_ended.emit(npc_id)

