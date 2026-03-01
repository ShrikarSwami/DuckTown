extends Node
# Quest manager - tracks approvals required for party scene

class Approval:
	var npc_id: String
	var npc_name: String
	var is_approved: bool = false
	var required_trust: int = 30  # Trust >= 30 to approve
	var quest_type: String  # "food", "decorations", "safety"
	
	func _init(p_id: String, p_name: String, p_type: String):
		npc_id = p_id
		npc_name = p_name
		quest_type = p_type

var approvals: Dictionary = {}  # npc_id -> Approval
var all_approvals_met: bool = false

signal approval_changed(npc_id: String, is_approved: bool)
signal all_approvals_met_signal()
signal party_triggered()

# NPC references for easy access
var npc_interactions: Dictionary = {}  # npc_id -> npc_interaction node

func _ready():
	# Define the 3 approval gates
	approvals["baker"] = Approval.new("baker", "Baker", "food")
	approvals["merch"] = Approval.new("merch", "Merch", "decorations")
	approvals["guard"] = Approval.new("guard", "Guard", "safety")
	
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
			print("[QuestManager] Connected to %s" % npc_id)
		else:
			# NPCs might not have interaction yet, try the NPC node itself
			if npc.has_signal("relationship_changed"):
				npc_interactions[npc_id] = npc
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
				_check_all_approvals()
			elif not approval.is_approved and was_approved:
				print("[QuestManager] %s approval lost! (trust: %d)" % [approval.npc_name, new_value])
				approval_changed.emit(npc_id, false)
				all_approvals_met = false

func _check_all_approvals() -> void:
	"""Check if all 3 approvals are met"""
	var all_met = true
	for approval in approvals.values():
		if not approval.is_approved:
			all_met = false
			break
	
	if all_met and not all_approvals_met:
		all_approvals_met = true
		print("[QuestManager] ✨ ALL APPROVALS MET! Party unlock!")
		all_approvals_met_signal.emit()
		trigger_party()

func trigger_party():
	"""Trigger the party scene / celebration"""
	print("[QuestManager] 🎉 PARTY TRIGGERED!")
	party_triggered.emit()
	
	# Load party scene
	get_tree().change_scene_to_file("res://scenes/Party.tscn")

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
