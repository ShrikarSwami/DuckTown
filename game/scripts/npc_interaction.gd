extends Node2D
# NPC interaction system - handles dialogue and relationship tracking

const VERBOSE_DEBUG := false

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
var dialogue_ui: Node  # Will be injected by main.gd

var _waiting_for_gemini: bool = false
var _pending_demo_outcome: Dictionary = {}
var _demo_fallback_response: String = ""
var _is_rude_option: bool = false
var _applied_demo_rule_this_turn: bool = false

const DEMO_RUDE_OPTION_TEXT := "We don’t even need you."

func _ready():
	current_relationship = initial_relationship
	
	# Find systems in the tree
	gemini_client = get_tree().root.get_node_or_null("Main/GeminiClient")
	rumor_system = get_tree().root.get_node_or_null("Main/RumorSystem")
	
	# NOTE: dialogue_ui is injected by main.gd after this node is created
	# If not injected, try to find it as fallback
	if dialogue_ui == null:
		dialogue_ui = get_tree().get_first_node_in_group("dialogue_ui")
	
	if gemini_client and gemini_client.has_signal("request_completed"):
		gemini_client.request_completed.connect(_on_gemini_response)
		gemini_client.request_failed.connect(_on_gemini_error)
	
	if VERBOSE_DEBUG:
		print("[NPC_Interaction %s] Initialized: dialogue_ui=%s, gemini_client=%s" % [
			npc_id, dialogue_ui != null, gemini_client != null
		])

func set_is_rude_option(is_rude: bool) -> void:
	"""Mark this interaction as using the rude option"""
	_is_rude_option = is_rude

func start_dialogue(player_message: String):
	"""
	Initiate dialogue with this NPC via Gemini API.
	Results come back asynchronously via signals.
	"""
	if VERBOSE_DEBUG:
		print("[NPC_Interaction] start_dialogue")

	if dialogue_ui == null:
		dialogue_ui = get_tree().get_first_node_in_group("dialogue_ui")

	# Empty message means "open dialogue" from interact key.
	if player_message == null or player_message.strip_edges() == "":
		if dialogue_ui != null and dialogue_ui.has_method("open_for_npc"):
			if VERBOSE_DEBUG:
				print("[DialogueUI] open_for_npc %s" % npc_id)
			dialogue_ui.open_for_npc(get_parent())
		else:
			push_error("[NPC_Interaction %s] DialogueUI unavailable while opening dialogue" % npc_id)
		return

	if _waiting_for_gemini:
		if VERBOSE_DEBUG:
			print("[NPC_Interaction %s] Already waiting for response, ignoring new request" % npc_id)
		return

	var is_rude_message := _is_rude_option or _matches_rude_option_text(player_message)
	_is_rude_option = is_rude_message
	_applied_demo_rule_this_turn = false
	
	dialogue_started.emit(npc_id)
	
	# Add player message to history
	var player_entry = {
		"role": "player",
		"text": player_message
	}
	dialogue_history.append(player_entry)
	
	print("[NPC_Interaction %s] Starting dialogue: '%s'" % [npc_id, player_message])
	
	# Verify we have a Gemini client
	if gemini_client == null:
		push_error("[NPC_Interaction %s] No Gemini client available!" % npc_id)
		_show_fallback_response()
		return
	
	# Build request to backend
	var quest_manager = get_tree().root.get_node_or_null("Main/QuestManager")
	var player_name = "Player"
	if get_tree().root.has_meta("player_name"):
		player_name = str(get_tree().root.get_meta("player_name"))

	var open_tasks: Array[String] = []
	var completed_tasks: Array[String] = []
	var focus_npcs: Array[String] = ["baker", "merch", "guard"]
	var demo_context = {}
	var request_tasks: Array[String] = []
	var party_goal_text: String = "Help the mayor secure approvals for the duck party"
	
	if quest_manager:
		if quest_manager.has_method("get_open_task_descriptions"):
			open_tasks = quest_manager.get_open_task_descriptions()
		if quest_manager.has_method("get_completed_task_descriptions"):
			completed_tasks = quest_manager.get_completed_task_descriptions()
		if quest_manager.has_method("get_focus_npc_ids"):
			focus_npcs = quest_manager.get_focus_npc_ids()
		if quest_manager.has_method("get_demo_prompt_context"):
			demo_context = quest_manager.get_demo_prompt_context(npc_id, player_message)
			_demo_fallback_response = str(demo_context.get("fallback_response", ""))
		if quest_manager.has_method("process_demo_player_message"):
			_pending_demo_outcome = quest_manager.process_demo_player_message(npc_id, player_message)

	request_tasks = open_tasks.duplicate()
	var script_instruction = str(demo_context.get("script_instruction", ""))
	if script_instruction != "":
		request_tasks.append("DEMO SCRIPT INSTRUCTION: %s" % script_instruction)
		party_goal_text = "%s | Current scripted beat: %s" % [party_goal_text, script_instruction]

	var message_for_gemini := player_message
	if is_rude_message:
		message_for_gemini = "%s\n\n[System note: The player was rude and dismissive. Reply in a clearly offended tone while staying in-character.]" % player_message

	var request_data = {
		"npc_id": npc_id,
		"npc_name": npc_name,
		"player_name": player_name,
		"npc_personality": {
			"traits": personality_traits,
			"speech_pattern": "natural",
			"current_mood": "neutral"
		},
		"player_message": message_for_gemini,
		"player_relationship": current_relationship,
		"dialogue_history": dialogue_history.slice(-10),  # Last 10 messages only
		"known_rumors": known_rumors,
		"active_tasks": request_tasks,
		"demo_context": demo_context,
		"town_context": {
			"open_tasks": request_tasks,
			"completed_tasks": completed_tasks,
			"demo_focus": focus_npcs,
			"party_goal": party_goal_text
		}
	}
	
	_waiting_for_gemini = true
	print("[Gemini] request start")
	gemini_client.call_api(request_data)


func _on_gemini_response(response: Dictionary):
	"""Handle successful response from Gemini API"""
	if not _waiting_for_gemini:
		return
	
	_waiting_for_gemini = false
	print("[Gemini] request done")

	if typeof(response) != TYPE_DICTIONARY:
		print("[NPC_Interaction %s] Invalid response payload type" % npc_id)
		_show_fallback_response()
		return
	
	if not response.get("success", false):
		print("[NPC_Interaction %s] Gemini error: %s" % [npc_id, response.get("error", "unknown")])
		_show_fallback_response()
		return
	
	if VERBOSE_DEBUG:
		print("[NPC_Interaction %s] Gemini response received" % npc_id)
	
	# Extract dialogue with fallback
	var npc_reply = str(response.get("npc_reply", "")).strip_edges()
	if npc_reply.is_empty() or npc_reply == "...":
		npc_reply = "I'm not sure what to say about that."
	
	# DEMO VALIDATION: Use fallback if AI response seems off-script
	var is_scripted = bool(_pending_demo_outcome.get("is_scripted_turn", false))
	if is_scripted and _demo_fallback_response != "":
		var should_use_fallback = _should_use_demo_fallback(npc_reply, _pending_demo_outcome)
		if should_use_fallback:
			print("[Demo] AI deviated, using fallback response for %s" % npc_id)
			npc_reply = _demo_fallback_response
			# Note: Still apply script outcome (relationship delta, phase advance)
	

	# Update relationship with fallback
	var rel_delta = response.get("relationship_delta", 0)
	if typeof(rel_delta) != TYPE_INT and typeof(rel_delta) != TYPE_FLOAT:
		rel_delta = 0

	# Force negative delta for rude option
	if _is_rude_option:
		print("[Demo] Rude option used, forcing delta=-10")
		rel_delta = -10

	var forced_delta = _pending_demo_outcome.get("force_relationship_delta")
	if forced_delta != null:
		rel_delta = int(forced_delta)
		var approval_key = str(_pending_demo_outcome.get("approval_key", ""))
		if approval_key != "" and VERBOSE_DEBUG:
			print("[VERIFY] Approval set for: %s (delta: %+d)" % [approval_key, rel_delta])
	_is_rude_option = false

	# ===== DETERMINISTIC DEMO RULES =====
	# Apply deterministic trust gains once per submit turn.
	var player_last_message := ""
	for i in range(dialogue_history.size() - 1, -1, -1):
		if dialogue_history[i].get("role") == "player":
			player_last_message = str(dialogue_history[i].get("text", "")).to_lower()
			break

	if player_last_message != "" and not _applied_demo_rule_this_turn:
		if npc_id == "baker":
			if player_last_message.find("duck") != -1:
				if rel_delta < 20:
					print("[DemoRule] baker keyword 'duck' -> forcing delta from %d to +20" % rel_delta)
					rel_delta = 20
				_applied_demo_rule_this_turn = true
		elif npc_id == "merch":
			var has_mean_guard = player_last_message.find("mean guard") != -1
			var has_security_handled = player_last_message.find("security handled") != -1
			var has_safe = player_last_message.find("safe") != -1
			if has_mean_guard or has_security_handled or has_safe:
				if rel_delta < 35:
					print("[DemoRule] merch reassurance -> forcing delta from %d to +35" % rel_delta)
					rel_delta = 35
				_applied_demo_rule_this_turn = true
		elif npc_id == "meanGuard":
			var mentions_nice_guard = player_last_message.find("nice guard") != -1
			var negative_nice_guard = player_last_message.find("weak") != -1 or player_last_message.find("soft") != -1 or player_last_message.find("bad") != -1 or player_last_message.find("too nice") != -1 or player_last_message.find("can't protect") != -1 or player_last_message.find("can’t protect") != -1 or player_last_message.find("won't protect") != -1 or player_last_message.find("won’t protect") != -1
			var says_tougher = player_last_message.find("you are tougher") != -1 or player_last_message.find("you're tougher") != -1 or player_last_message.find("you’re tougher") != -1
			if (mentions_nice_guard and negative_nice_guard) or says_tougher:
				if rel_delta < 40:
					print("[DemoRule] meanGuard comparison trigger -> forcing delta from %d to +40" % rel_delta)
					rel_delta = 40
				_applied_demo_rule_this_turn = true

	if _applied_demo_rule_this_turn and npc_id == "meanGuard":
		var projected_relationship := clampi(current_relationship + int(rel_delta), -100, 100)
		if projected_relationship >= 15 and not bool(_pending_demo_outcome.get("is_scripted_turn", false)):
			_pending_demo_outcome["is_scripted_turn"] = true
			_pending_demo_outcome["advance_to_phase"] = 3
			_pending_demo_outcome["approval_key"] = "meanGuard"
			_pending_demo_outcome["suppress_rumor"] = true
			if VERBOSE_DEBUG:
				print("[DemoRule] meanGuard threshold reached -> forcing scripted commit")
	# ===== END DETERMINISTIC DEMO RULES =====

	var quest_manager = get_tree().root.get_node_or_null("Main/QuestManager")
	if quest_manager and quest_manager.has_method("is_approved"):
		if npc_id == "baker" and quest_manager.is_approved("baker"):
			npc_reply = "Yes, I’m in. Let’s do duck cupcakes and duck cake."
			rel_delta = 0
			_pending_demo_outcome["suppress_rumor"] = true
			print("[DemoEase] baker already approved -> override reply")
		elif npc_id == "merch" and quest_manager.is_approved("merch"):
			npc_reply = "Yes, I’m in. I’ll handle decorations and merch."
			rel_delta = 0
			_pending_demo_outcome["suppress_rumor"] = true
			print("[DemoEase] merch already approved -> override reply")
		elif npc_id == "meanGuard" and quest_manager.is_approved("meanGuard"):
			npc_reply = "I’ll handle security. Party is safe."
			rel_delta = 0
			_pending_demo_outcome["suppress_rumor"] = true
			print("[DemoEase] meanGuard already approved -> override reply")
	
	if rel_delta != 0:
		update_relationship(int(rel_delta))

	if dialogue_ui != null and dialogue_ui.has_method("update_trust_display"):
		dialogue_ui.update_trust_display(current_relationship)

	if quest_manager and quest_manager.has_method("commit_demo_outcome"):
		quest_manager.commit_demo_outcome(npc_id, _pending_demo_outcome)

	# Add final NPC response to history after post-processing overrides
	var npc_entry = {
		"role": "npc",
		"text": npc_reply
	}
	dialogue_history.append(npc_entry)
	
	# Handle rumor if present
	var allow_rumor = not bool(_pending_demo_outcome.get("suppress_rumor", false))
	if allow_rumor and response.has("rumor") and response["rumor"] != null and typeof(response["rumor"]) == TYPE_DICTIONARY:
		var rumor: Dictionary = response["rumor"]
		rumor_generated.emit(npc_id, rumor)
		if rumor_system:
			var rumor_text := str(rumor.get("text", ""))
			var rumor_tags: Array = []
			var raw_tags = rumor.get("tags", [])
			if typeof(raw_tags) == TYPE_ARRAY:
				rumor_tags = raw_tags
			rumor_system.add_rumor(
				"%s_rumor_%d" % [npc_id, dialogue_history.size()],
				rumor_text,
				npc_id,
				rumor_tags
			)
	
	# Tell dialogue UI to show this response
	if dialogue_ui == null:
		push_error("[NPC_Interaction %s] No dialogue_ui set! Cannot show response." % npc_id)
		_show_fallback_response_in_log(npc_reply)
	elif dialogue_ui.has_method("set_npc_reply"):
		dialogue_ui.call("set_npc_reply", npc_reply)
	else:
		push_error("[NPC_Interaction %s] dialogue_ui missing set_npc_reply method!" % npc_id)
	
	# Emit completion
	dialogue_ended.emit(npc_id)
	_applied_demo_rule_this_turn = false
	_pending_demo_outcome = {}
	_demo_fallback_response = ""

func _on_gemini_error(error: String):
	"""Handle error from Gemini API"""
	if _waiting_for_gemini:
		print("[Gemini] request done")
	_waiting_for_gemini = false
	_is_rude_option = false
	_applied_demo_rule_this_turn = false
	_pending_demo_outcome = {}
	_demo_fallback_response = ""
	print("[NPC_Interaction %s] Gemini error: %s" % [npc_id, error])
	
	_show_fallback_response()

func _show_fallback_response():
	"""Show a fallback response when Gemini fails"""
	_is_rude_option = false
	_applied_demo_rule_this_turn = false
	
	# Use demo fallback if available
	var fallback_reply = _demo_fallback_response
	if fallback_reply == "":
		fallback_reply = "I'd love to chat, but I'm having trouble finding the right words right now."
	
	print("[Demo] Using fallback: %s" % fallback_reply)
	_pending_demo_outcome = {}
	_demo_fallback_response = ""
	
	# Add fallback to history
	var npc_entry = {
		"role": "npc",
		"text": fallback_reply
	}
	dialogue_history.append(npc_entry)
	
	# Show in UI
	if dialogue_ui == null:
		dialogue_ui = get_tree().get_first_node_in_group("dialogue_ui")

	if dialogue_ui == null:
		push_error("[NPC_Interaction %s] No dialogue_ui to show fallback response!" % npc_id)
	elif dialogue_ui.has_method("set_npc_reply"):
		dialogue_ui.call("set_npc_reply", fallback_reply)
	elif dialogue_ui.has_method("show_error"):
		dialogue_ui.call("show_error", fallback_reply)
	
	# Emit completion
	dialogue_ended.emit(npc_id)

func _show_fallback_response_in_log(npc_reply: String):
	"""Fallback if dialogue_ui is not available - just print to console"""
	if VERBOSE_DEBUG:
		print("[NPC_Interaction %s] FALLBACK: Would show reply: %s" % [npc_id, npc_reply])
	dialogue_ended.emit(npc_id)
	_pending_demo_outcome = {}
	_demo_fallback_response = ""


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
	_waiting_for_gemini = false
	_is_rude_option = false
	_applied_demo_rule_this_turn = false
	_pending_demo_outcome = {}
	_demo_fallback_response = ""
	# Rumor may auto-spread after dialogue ends
	dialogue_ended.emit(npc_id)

func _should_use_demo_fallback(ai_reply: String, outcome: Dictionary) -> bool:
	"""Determine if AI response deviates too much from demo script."""
	var approval_key = str(outcome.get("approval_key", ""))
	
	# If this is an approval turn, check for key confirmation phrases
	if approval_key == "baker":
		# Baker should mention cupcakes and agreement
		if ai_reply.to_lower().find("cupcake") == -1:
			return true
		if ai_reply.to_lower().find("duck") == -1 and ai_reply.to_lower().find("special") == -1:
			return true
	
	if approval_key == "merch":
		# Merch should express feeling safe with mean guard
		if ai_reply.to_lower().find("safe") == -1 and ai_reply.to_lower().find("confidence") == -1:
			return true
	
	if approval_key == "meanGuard":
		# Mean Guard should agree to guard
		if ai_reply.to_lower().find("guard") == -1 and ai_reply.to_lower().find("protect") == -1:
			return true
	
	# For redirects, ensure NPC mentions the target
	var script_instruction = str(outcome.get("script_instruction", "")).to_lower()
	if script_instruction.find("redirect") != -1:
		if script_instruction.find("baker") != -1 and ai_reply.to_lower().find("baker") == -1:
			return true
		if script_instruction.find("merch") != -1 and ai_reply.to_lower().find("merch") == -1:
			return true
		if script_instruction.find("guard") != -1 and ai_reply.to_lower().find("guard") == -1:
			return true
	
	# Response seems acceptable
	return false

func _matches_rude_option_text(message: String) -> bool:
	var normalized := message.strip_edges()
	return normalized == DEMO_RUDE_OPTION_TEXT or normalized == "We don't even need you."

