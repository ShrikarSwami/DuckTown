extends Node
# Quest manager - tracks approvals required for party scene

const VERBOSE_DEBUG := false

class Approval:
	var npc_id: String
	var npc_name: String
	var is_approved: bool = false
	var required_trust: int = 15  # Trust >= 15 to approve
	var quest_type: String  # "food", "decorations", "safety"
	
	func _init(p_id: String, p_name: String, p_type: String):
		npc_id = p_id
		npc_name = p_name
		quest_type = p_type

var approvals: Dictionary = {}  # npc_id -> Approval
var all_approvals_met: bool = false
var _victory_triggered: bool = false

# Demo path tracking
var demo_phase: int = 0  # 0=start, 1=talked_to_baker, 2=talked_to_merch, 3=ready_for_guard
var demo_path_active: bool = true
var _demo_flags := {
	"baker_help_requested": false,
	"baker_approved": false,
	"merch_concern_revealed": false,
	"merch_approved": false,
	"guard_approved": false
}

# Fallback responses if AI deviates from demo script
var _demo_fallback_responses := {
	"baker_initial": "I can help with party food! What kind of cake would you like?",
	"baker_duck_cupcakes": "Duck cupcakes it is! I'll make them special. Count me in for the party!",
	"merch_initial": "I'd love to bring merch, but... I heard the nice guard is handling security. That doesn't feel safe.",
	"merch_reassured": "Oh, if the mean guard is protecting us, then I'm in! Their strength gives me confidence.",
	"guard_accept": "Fine, I'll guard your party. Unlike the nice guard, I actually know how to handle trouble.",
	"redirect_to_baker": "You should talk to Baker first about the party food.",
	"redirect_to_merch": "Talk to Merch next about party decorations.",
	"redirect_to_guard": "We need Mean Guard to secure the party. Go recruit them."
}

signal approval_changed(npc_id: String, is_approved: bool)
signal approvals_updated(baker_ok: bool, merch_ok: bool, mean_guard_ok: bool, approvals_count: int)
signal all_approvals_met_signal()
signal party_triggered()
signal demo_phase_changed(new_phase: int)

# NPC references for easy access
var npc_interactions: Dictionary = {}  # npc_id -> npc_interaction node

func _ready():
	# Define the 3 approval gates
	approvals["baker"] = Approval.new("baker", "Baker", "food")
	approvals["merch"] = Approval.new("merch", "Merch", "decorations")
	approvals["meanGuard"] = Approval.new("meanGuard", "Mean Guard", "safety")
	
	if VERBOSE_DEBUG:
		print("[QuestManager] Initialized with 3 approval gates")
	
	# Find NPC interaction nodes (deferred to let Main.gd create them first)
	call_deferred("_find_npc_interactions")

func _find_npc_interactions() -> void:
	"""Find all NPC interaction components"""
	await get_tree().create_timer(0.5).timeout  # Give Main.gd time to setup
	
	for npc in get_tree().get_nodes_in_group("npc"):
		var npc_id_value = npc.get("npc_id")
		var npc_id = str(npc_id_value) if npc_id_value != null else "unknown"
		
		# Look for interaction component
		var interaction = npc.get_node_or_null("NPC_Interaction")
		if interaction and interaction.has_signal("relationship_changed"):
			npc_interactions[npc_id] = interaction
			interaction.relationship_changed.connect(_on_npc_relationship_changed)
			if VERBOSE_DEBUG:
				print("[QuestManager] Connected to %s" % npc_id)
		else:
			# NPCs might not have interaction yet, try the NPC node itself
			if npc.has_signal("relationship_changed"):
				npc_interactions[npc_id] = npc
				if VERBOSE_DEBUG:
					print("[QuestManager] Connected directly to NPC %s" % npc_id)

func _on_npc_relationship_changed(npc_id: String, new_value: int, delta: int):
	"""Called when an NPC's relationship changes"""
	
	# Check each approval gate
	for approval_id in approvals.keys():
		var approval = approvals[approval_id]
		if approval.npc_id == npc_id:
			# Check if they've reached the approval threshold
			var was_approved = approval.is_approved
			approval.is_approved = (new_value >= approval.required_trust)
			
			if approval.is_approved and not was_approved:
				print("[QuestManager] %s approved! (trust: %d)" % [approval.npc_name, new_value])
				approval_changed.emit(npc_id, true)
				_emit_approvals_updated()
				_check_all_approvals()
			elif not approval.is_approved and was_approved:
				print("[QuestManager] %s approval lost! (trust: %d)" % [approval.npc_name, new_value])
				approval_changed.emit(npc_id, false)
				_emit_approvals_updated()
				all_approvals_met = false

func _emit_approvals_updated() -> void:
	"""Emit the approvals_updated signal with current approval states"""
	var baker_approval: Approval = approvals.get("baker") as Approval
	var merch_approval: Approval = approvals.get("merch") as Approval
	var mean_guard_approval: Approval = approvals.get("meanGuard") as Approval
	var baker_ok: bool = baker_approval != null and baker_approval.is_approved
	var merch_ok: bool = merch_approval != null and merch_approval.is_approved
	var mean_guard_ok: bool = mean_guard_approval != null and mean_guard_approval.is_approved
	var count = get_approval_progress()
	
	approvals_updated.emit(baker_ok, merch_ok, mean_guard_ok, count)
	if VERBOSE_DEBUG:
		print("[QuestManager] approvals_updated emitted: baker=%s merch=%s meanGuard=%s count=%d" % [baker_ok, merch_ok, mean_guard_ok, count])

func _check_all_approvals() -> void:
	"""Check if all 3 required approvals are met."""
	var baker_approval: Approval = approvals.get("baker") as Approval
	var merch_approval: Approval = approvals.get("merch") as Approval
	var mean_guard_approval: Approval = approvals.get("meanGuard") as Approval
	var baker_ok: bool = baker_approval != null and baker_approval.is_approved
	var merch_ok: bool = merch_approval != null and merch_approval.is_approved
	var mean_guard_ok: bool = mean_guard_approval != null and mean_guard_approval.is_approved
	var all_met: bool = baker_ok and merch_ok and mean_guard_ok

	if all_met and not all_approvals_met:
		all_approvals_met = true
		print("[DemoPhase] ✨ ALL APPROVALS MET! Party unlock!")
		all_approvals_met_signal.emit()
		trigger_victory()

func trigger_victory() -> void:
	"""Single-fire transition to Party scene when all approvals are met."""
	if _victory_triggered:
		if VERBOSE_DEBUG:
			print("[QuestManager] Victory already triggered, ignoring duplicate call")
		return

	_victory_triggered = true
	print("[VERIFY] All approvals met -> starting Party scene")
	party_triggered.emit()

	var err := get_tree().change_scene_to_file("res://scenes/Party.tscn")
	if err != OK:
		push_error("[QuestManager] Failed to load Party scene")
		_victory_triggered = false

func get_approval(npc_id: String) -> Approval:
	"""Get approval status for an NPC"""
	for approval in approvals.values():
		if approval.npc_id == npc_id:
			return approval
	return null

func is_approved(npc_id: String) -> bool:
	"""Check if a specific NPC has approved"""
	var approval = get_approval(npc_id)
	return approval != null and approval.is_approved

func get_all_approvals() -> Dictionary:
	"""Get all approval statuses"""
	return approvals.duplicate()

func get_approval_progress() -> int:
	"""Return number of approvals obtained (0-3)"""
	var count = 0
	for approval in approvals.values():
		if approval.is_approved:
			count += 1
	return count

func get_open_task_descriptions() -> Array[String]:
	"""Return readable task descriptions for incomplete approvals"""
	var tasks: Array[String] = []
	for approval in approvals.values():
		if not approval.is_approved:
			tasks.append("Earn %s approval for %s" % [approval.npc_name, approval.quest_type])
	return tasks

func get_completed_task_descriptions() -> Array[String]:
	"""Return readable task descriptions for completed approvals"""
	var tasks: Array[String] = []
	for approval in approvals.values():
		if approval.is_approved:
			tasks.append("%s approval secured" % approval.npc_name)
	return tasks

func get_focus_npc_ids() -> Array[String]:
	"""Return current focus NPC ids for this demo configuration"""
	var ids: Array[String] = []
	for approval in approvals.values():
		ids.append(approval.npc_id)
	return ids

func get_demo_phase() -> int:
	"""Get current demo phase"""
	return demo_phase

func get_demo_options_for_npc(npc_id: String) -> Array[String]:
	"""Return deterministic phase-aware dialogue options (2-4 choices)."""
	if not demo_path_active:
		return []

	if demo_phase == 0:
		if npc_id != "baker":
			return [
				"I should talk to Baker first.",
				"Who is helping with party food?"
			]
		if not bool(_demo_flags.get("baker_help_requested", false)):
			return [
				"Can you help with the party?",
				"What food should we serve at the party?"
			]
		return [
			"Duck cupcakes, please.",
			"Maybe a large cake instead?"
		]

	if demo_phase == 1:
		if npc_id != "merch":
			return [
				"I should talk to Merch next.",
				"Who can handle party merch?"
			]
		if not bool(_demo_flags.get("merch_concern_revealed", false)):
			return [
				"Will you bring merch to the party?",
				"Can you set up a booth at the party?"
			]
		return [
			"The mean guard will guard the party.",
			"Security is handled by mean guard."
		]

	if demo_phase == 2:
		if npc_id != "meanGuard":
			return [
				"I should recruit Mean Guard now.",
				"Who can secure the party?"
			]
		return [
			"Will you guard the party?",
			"We need your protection at the party."
		]

	return [
		"Thanks for helping with the party!",
		"See you at the party."
	]

func process_demo_player_message(npc_id: String, player_message: String) -> Dictionary:
	"""Evaluate a player message against deterministic demo script and return scripted outcome."""
	var text = player_message.strip_edges().to_lower()
	var outcome = {
		"is_scripted_turn": false,
		"script_instruction": "",
		"fallback_response": "",
		"force_relationship_delta": null,
		"advance_to_phase": -1,
		"suppress_rumor": true,
		"approval_key": ""
	}

	if not demo_path_active:
		return outcome

	# Phase 0: Baker must agree to help and ask about cake type
	if demo_phase == 0 and npc_id == "baker":
		if text.find("help") != -1 and text.find("party") != -1:
			_demo_flags["baker_help_requested"] = true
			outcome["is_scripted_turn"] = true
			outcome["script_instruction"] = "YOU MUST: (1) Eagerly agree to help with party food. (2) Ask what type of cake they want. Be warm and helpful. Keep response under 160 chars."
			outcome["fallback_response"] = _demo_fallback_responses["baker_initial"]
			print("[Demo] Baker: help requested, asking about cake type")
			return outcome
		if bool(_demo_flags.get("baker_help_requested", false)) and text.find("duck") != -1:
			_demo_flags["baker_approved"] = true
			outcome["is_scripted_turn"] = true
			outcome["script_instruction"] = "YOU MUST: (1) Enthusiastically confirm Duck cupcakes. (2) Say you'll make them special. (3) Agree to join party prep. Express excitement. Keep under 160 chars."
			outcome["fallback_response"] = _demo_fallback_responses["baker_duck_cupcakes"]
			outcome["force_relationship_delta"] = 35
			outcome["advance_to_phase"] = 1
			outcome["approval_key"] = "baker"
			print("[DemoRule] baker duck keyword detected")

	# Phase 1: Merch must mention rumor about nice guard and feel unsafe
	if demo_phase == 1 and npc_id == "merch":
		if text.find("bring merch") != -1 or text.find("booth") != -1 or text.find("party") != -1:
			_demo_flags["merch_concern_revealed"] = true
			outcome["is_scripted_turn"] = true
			outcome["script_instruction"] = "YOU MUST: (1) Say you'd love to help BUT (2) Mention you heard the nice guard is handling security (3) Clearly say that makes you feel unsafe. Be worried but willing if convinced. Keep under 160 chars."
			outcome["fallback_response"] = _demo_fallback_responses["merch_initial"]
			print("[Demo] Merch: concern revealed about nice guard security")
			return outcome
		if bool(_demo_flags.get("merch_concern_revealed", false)) and text.find("mean guard") != -1:
			_demo_flags["merch_approved"] = true
			outcome["is_scripted_turn"] = true
			outcome["script_instruction"] = "YOU MUST: (1) Express relief that mean guard will protect the party. (2) Say you now feel safe and agree to bring merch. (3) Show confidence in mean guard's strength. Keep under 160 chars."
			outcome["fallback_response"] = _demo_fallback_responses["merch_reassured"]
			outcome["force_relationship_delta"] = 35
			outcome["advance_to_phase"] = 2
			outcome["approval_key"] = "merch"
			print("[Demo] Approval set for merch (Mean guard reassurance)")
			return outcome

	# Phase 2: Mean Guard must agree to guard (flexible conditions)
	if demo_phase == 2 and npc_id == "meanGuard":
		var mentions_guard = text.find("guard") != -1 or text.find("protect") != -1 or text.find("security") != -1
		var mentions_party = text.find("party") != -1 or text.find("event") != -1
		var is_recruitment = mentions_guard and mentions_party
		
		# Also accept if player criticizes nice guard
		var criticizes_nice_guard = text.find("nice guard") != -1 and (text.find("weak") != -1 or text.find("soft") != -1 or text.find("bad") != -1)
		
		if is_recruitment or criticizes_nice_guard:
			_demo_flags["guard_approved"] = true
			outcome["is_scripted_turn"] = true
			outcome["script_instruction"] = "YOU MUST: (1) Agree to guard the party. (2) Show confidence in your strength. (3) Optionally mention you're better than nice guard. Keep under 160 chars. Be direct and accepting."
			outcome["fallback_response"] = _demo_fallback_responses["guard_accept"]
			outcome["force_relationship_delta"] = 40
			outcome["advance_to_phase"] = 3
			outcome["approval_key"] = "meanGuard"
			print("[Demo] Approval set for meanGuard")
			return outcome

	# Redirect to correct NPC if talking to wrong one
	if demo_phase == 0 and npc_id != "baker":
		outcome["is_scripted_turn"] = true
		outcome["script_instruction"] = "Politely redirect player to talk to Baker first about party food. Keep it brief and friendly."
		outcome["fallback_response"] = _demo_fallback_responses["redirect_to_baker"]
		return outcome
	if demo_phase == 1 and npc_id != "merch":
		outcome["is_scripted_turn"] = true
		outcome["script_instruction"] = "Politely redirect player to talk to Merch next about party decorations. Keep it brief."
		outcome["fallback_response"] = _demo_fallback_responses["redirect_to_merch"]
		return outcome
	if demo_phase == 2 and npc_id != "meanGuard":
		outcome["is_scripted_turn"] = true
		outcome["script_instruction"] = "Politely redirect player to recruit Mean Guard next for security. Keep it brief."
		outcome["fallback_response"] = _demo_fallback_responses["redirect_to_guard"]
		return outcome

	return outcome

func commit_demo_outcome(npc_id: String, outcome: Dictionary) -> void:
	"""Apply deterministic phase transitions after a scripted turn resolves."""
	if not demo_path_active:
		return
	if not bool(outcome.get("is_scripted_turn", false)):
		return

	var target_phase = int(outcome.get("advance_to_phase", -1))
	if target_phase >= 0 and target_phase != demo_phase:
		var old_phase = demo_phase
		demo_phase = target_phase
		print("[DemoPhase] Phase %d -> %d (via %s)" % [old_phase, demo_phase, npc_id])
		print("[VERIFY] Demo phase current: %d" % demo_phase)
		demo_phase_changed.emit(demo_phase)

func get_demo_prompt_context(npc_id: String, player_message: String = "") -> Dictionary:
	"""Get context hints for deterministic scripted dialogue turns."""
	var outcome = process_demo_player_message(npc_id, player_message)
	var context = {
		"demo_active": demo_path_active,
		"current_phase": demo_phase,
		"target_npc": _get_phase_target_npc(),
		"next_objective": "",
		"script_instruction": str(outcome.get("script_instruction", "")),
		"fallback_response": str(outcome.get("fallback_response", "")),
		"is_scripted_turn": bool(outcome.get("is_scripted_turn", false)),
		"approval_key": str(outcome.get("approval_key", ""))
	}

	if demo_phase == 0:
		if not bool(_demo_flags.get("baker_help_requested", false)):
			context["next_objective"] = "Ask Baker for party help."
		else:
			context["next_objective"] = "Pick Duck cupcakes with Baker to secure approval."
	elif demo_phase == 1:
		if not bool(_demo_flags.get("merch_concern_revealed", false)):
			context["next_objective"] = "Ask Merch to join party setup."
		else:
			context["next_objective"] = "Reassure Merch that mean guard will guard."
	elif demo_phase == 2:
		context["next_objective"] = "Recruit Mean Guard for party security."
	else:
		context["next_objective"] = "All demo approvals complete."

	return context

func _get_phase_target_npc() -> String:
	if demo_phase == 0:
		return "baker"
	if demo_phase == 1:
		return "merch"
	if demo_phase == 2:
		return "meanGuard"
	return ""

func get_demo_fallback_response(key: String) -> String:
	"""Get fallback response for a demo scenario."""
	return _demo_fallback_responses.get(key, "I'm here to help with the party!")
