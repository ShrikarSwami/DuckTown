extends Control
# Trust HUD - Always visible display of NPC trust values and demo progress

var _trust_labels: Dictionary = {}  # npc_id -> Label
var _quest_manager: Node = null
var _npc_interactions: Dictionary = {}  # npc_id -> NPC_Interaction node
var _last_trust_values: Dictionary = {}  # npc_id -> last known trust

var _popup_layer: Control
var _popup_label: Label
var _popup_queue: Array[Dictionary] = []
var _is_popup_active: bool = false

const _POPUP_MAX_QUEUE := 3
const _POPUP_DURATION := 0.8
const _TRACKED_POPUP_NPCS := {
	"baker": "Baker",
	"merch": "Merch",
	"meanGuard": "Mean Guard",
	"mean_guard": "Mean Guard"
}

func _ready() -> void:
	# Find quest manager
	call_deferred("_initialize")

func _initialize() -> void:
	await get_tree().create_timer(0.5).timeout
	_setup_popup_ui()
	
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
	var previous_value: int = int(_last_trust_values.get(npc_id, new_value - delta))
	var actual_delta: int = new_value - previous_value
	_update_npc_trust(npc_id, new_value)

	if actual_delta != 0:
		_enqueue_trust_popup(npc_id, actual_delta)

func _update_npc_trust(npc_id: String, trust_value: int) -> void:
	"""Update the trust display for a specific NPC"""
	_last_trust_values[npc_id] = trust_value

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

func _setup_popup_ui() -> void:
	if _popup_layer != null:
		return

	_popup_layer = Control.new()
	_popup_layer.name = "TrustPopupLayer"
	_popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_popup_layer)

	_popup_label = Label.new()
	_popup_label.name = "TrustPopupLabel"
	_popup_label.visible = false
	_popup_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_label.position = Vector2(8, -18)
	_popup_label.add_theme_font_size_override("font_size", 14)
	_popup_label.add_theme_constant_override("outline_size", 6)
	_popup_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_popup_layer.add_child(_popup_label)

func _enqueue_trust_popup(npc_id: String, delta: int) -> void:
	if not _TRACKED_POPUP_NPCS.has(npc_id):
		return

	var popup_text := "%+d Trust (%s)" % [delta, _TRACKED_POPUP_NPCS[npc_id]]
	_popup_queue.append({
		"text": popup_text,
		"positive": delta > 0
	})

	if _popup_queue.size() > _POPUP_MAX_QUEUE:
		_popup_queue.pop_front()

	if not _is_popup_active:
		_show_next_popup()

func _show_next_popup() -> void:
	if _popup_queue.is_empty() or _popup_label == null:
		_is_popup_active = false
		if _popup_label != null:
			_popup_label.visible = false
		return

	_is_popup_active = true
	var next_popup: Dictionary = _popup_queue.pop_front()

	_popup_label.visible = true
	_popup_label.text = str(next_popup.get("text", ""))
	_popup_label.modulate = Color(0.35, 1.0, 0.45, 1.0) if bool(next_popup.get("positive", false)) else Color(1.0, 0.4, 0.4, 1.0)
	_popup_label.position = Vector2(8, -18)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_popup_label, "position:y", -42.0, _POPUP_DURATION)
	tween.tween_property(_popup_label, "modulate:a", 0.0, _POPUP_DURATION)
	tween.set_parallel(false)
	tween.finished.connect(_on_popup_tween_finished)

func _on_popup_tween_finished() -> void:
	if _popup_label != null:
		_popup_label.visible = false
	_show_next_popup()
