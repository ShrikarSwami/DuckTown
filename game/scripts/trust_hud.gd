extends Control
# Trust HUD - Always visible display of NPC trust values and demo progress

var _trust_labels: Dictionary = {}  # npc_id -> Label
var _quest_manager: Node = null
var _npc_interactions: Dictionary = {}  # npc_id -> NPC_Interaction node

func _ready() -> void:
	# Find quest manager
	call_deferred("_initialize")

func _initialize() -> void:
	await get_tree().create_timer(0.5).timeout
	
	_quest_manager = get_tree().root.get_node_or_null("Main/QuestManager")
	
	# Find all NPC interactions
	for npc in get_tree().get_nodes_in_group("npc"):
		var interaction = npc.get_node_or_null("NPC_Interaction")
		if interaction:
			var npc_id = interaction.get("npc_id")
			if npc_id:
				_npc_interactions[npc_id] = interaction
				# Connect to relationship changes
				if interaction.has_signal("relationship_changed"):
					interaction.relationship_changed.connect(_on_relationship_changed)
	
	# Force initial update
	_update_display()
	
	print("[TrustHUD] Initialized with %d NPCs" % _npc_interactions.size())

func _update_display() -> void:
	"""Update all trust values in the HUD"""
	for npc_id in _npc_interactions.keys():
		var interaction = _npc_interactions[npc_id]
		if interaction:
			var trust_value = interaction.get("current_relationship")
			if trust_value != null:
				_update_npc_trust(npc_id, trust_value)

func _on_relationship_changed(npc_id: String, new_value: int, delta: int) -> void:
	"""Called when any NPC's trust changes"""
	_update_npc_trust(npc_id, new_value)

func _update_npc_trust(npc_id: String, trust_value: int) -> void:
	"""Update the trust display for a specific NPC"""
	if _trust_labels.has(npc_id) and _trust_labels[npc_id]:
		var label: Label = _trust_labels[npc_id]
		label.text = "%s: %d" % [npc_id.capitalize(), trust_value]
		
		# Color code based on trust value
		if trust_value >= 30:
			label.modulate = Color(0.2, 1.0, 0.2)  # Green
		elif trust_value >= 0:
			label.modulate = Color(1.0, 1.0, 0.2)  # Yellow
		else:
			label.modulate = Color(1.0, 0.2, 0.2)  # Red

func _process(_delta: float) -> void:
	# Update display periodically
	if Engine.get_frames_drawn() % 60 == 0:  # Every 60 frames
		_update_display()

func register_npc(npc_id: String, label: Label) -> void:
	"""Register a label to display trust for a specific NPC"""
	_trust_labels[npc_id] = label
	print("[TrustHUD] Registered label for %s" % npc_id)
