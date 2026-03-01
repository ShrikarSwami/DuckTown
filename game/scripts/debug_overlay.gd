extends Label
# Debug overlay - shows system state for judges

const VERBOSE_DEBUG := false

var _debug_visible: bool = false
var _rumor_system: Node
var _quest_manager: Node
var _npc_interactions: Dictionary = {}
var _key_pressed_last_frame: bool = false

func _ready():
	text = ""
	visible = false
	_rumor_system = get_tree().root.get_node_or_null("Main/RumorSystem")
	_quest_manager = get_tree().root.get_node_or_null("Main/QuestManager")
	
	# Find all NPCs (will find interaction components when they're ready)
	call_deferred("_find_npc_interactions")
	
	if VERBOSE_DEBUG:
		print("[DebugOverlay] Initialized")

func _find_npc_interactions():
	"""Find all NPC interaction nodes"""
	for npc in get_tree().get_nodes_in_group("npc"):
		var npc_id_value = npc.get("npc_id")
		var npc_id = str(npc_id_value) if npc_id_value != null else "unknown"
		_npc_interactions[npc_id] = npc
	if VERBOSE_DEBUG:
		print("[DebugOverlay] Found %d NPCs" % _npc_interactions.size())

func _process(delta):
	# Toggle debug with Q key (just pressed check)
	var key_pressed = Input.is_key_pressed(KEY_Q)
	if key_pressed and not _key_pressed_last_frame:
		_debug_visible = !_debug_visible
		visible = _debug_visible
		if _debug_visible:
			_find_npc_interactions()  # Refresh NPC list
			_update_debug_display()
	_key_pressed_last_frame = key_pressed
	
	# Auto-update debug display every frame when visible
	if _debug_visible:
		_update_debug_display()

func _update_debug_display():
	"""Update the debug information display"""
	var lines: Array[String] = []
	var player_name := "Player"
	if get_tree().root.has_meta("player_name"):
		player_name = str(get_tree().root.get_meta("player_name"))
	
	lines.append("=== 🦆 DUCKTOWN DEBUG ===")
	lines.append("Player: %s" % player_name)
	lines.append("")
	
	# NPC Trust Scores
	lines.append("📊 NPC TRUST:")
	for npc_id in _npc_interactions.keys():
		var npc = _npc_interactions[npc_id]
		var trust = npc.get_relationship() if npc.has_method("get_relationship") else 0
		var bar = _make_trust_bar(trust)
		lines.append("  %s: %d %s" % [npc_id, trust, bar])
	
	lines.append("")
	
	# Approvals
	if _quest_manager:
		lines.append("✅ APPROVALS:")
		var approvals = _quest_manager.get_all_approvals()
		for approval_id in approvals.keys():
			var approval = approvals[approval_id]
			var status = "✓" if approval.is_approved else "✗"
			lines.append("  [%s] %s (trust: %d/%d)" % [status, approval.npc_name, 30, approval.required_trust])
		
		var progress = _quest_manager.get_approval_progress()
		lines.append("")
		lines.append("Progress: %d/3 approvals" % progress)
	
	lines.append("")
	
	# Active Rumors
	if _rumor_system:
		var rumors = _rumor_system.get_all_rumors()
		lines.append("💬 RUMORS (%d):" % rumors.size())
		if rumors.is_empty():
			lines.append("  (none)")
		else:
			for rumor_id in rumors.keys():
				var rumor = rumors[rumor_id]
				var spreads = rumor.believer_npcs.size()
				var text_short = rumor.text.substr(0, 40) + ("..." if rumor.text.length() > 40 else "")
				lines.append("  • %s [%d NPCs]" % [text_short, spreads])
	
	lines.append("")
	lines.append("Press Q to hide debug info")
	
	text = "\n".join(lines)

func _make_trust_bar(trust: int) -> String:
	"""Create a visual trust bar"""
	var normalized = (trust + 100) / 20  # Convert [-100, 100] to [0, 10]
	normalized = clampi(normalized, 0, 10)
	var bar = "[" + "█".repeat(normalized) + "░".repeat(10 - normalized) + "]"
	return bar
