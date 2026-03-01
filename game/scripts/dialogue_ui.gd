# dialogue_ui.gd - Complete dialogue interface with options, rumor feed, and trust display
extends Control

@export var hint_label_path: NodePath
@export var dialogue_panel_path: NodePath
@export var npc_name_label_path: NodePath

var _hint_label: Label
var _dialogue_panel: Control
var _npc_name_label: Label

# Dialogue panel child nodes we'll create/find
var _npc_reply_label: Label
var _options_container: VBoxContainer
var _rumor_feed_panel: PanelContainer
var _rumor_feed_label: Label
var _trust_meter: ProgressBar

var _dialogue_open: bool = false
var _current_npc: Node = null
var _rumor_system: Node = null

# Dialogue state
var _pending_options: Array[String] = []


func _ready() -> void:
	_hint_label = _resolve_hint_label()
	_dialogue_panel = _resolve_dialogue_panel()
	_npc_name_label = _resolve_npc_name_label()
	_rumor_system = get_tree().root.get_node_or_null("Main/RumorSystem")

	print("DialogueUI ready")
	
	if _dialogue_panel == null:
		push_error("DialogueUI: DialoguePanel not found!")
		return
	
	# Find or create child UI components
	_setup_dialogue_panel()
	
	_dialogue_panel.hide()
	if _hint_label != null:
		_hint_label.hide()


func _setup_dialogue_panel() -> void:
	"""Set up all child UI elements inside the dialogue panel"""
	
	# NPC reply text
	_npc_reply_label = _dialogue_panel.find_child("NPCReplyLabel", true, false) as Label
	if _npc_reply_label == null:
		_npc_reply_label = Label.new()
		_npc_reply_label.name = "NPCReplyLabel"
		_npc_reply_label.text = "NPC dialogue will appear here..."
		_npc_reply_label.custom_minimum_size = Vector2(400, 80)
		_npc_reply_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		_dialogue_panel.add_child(_npc_reply_label)
	
	# Options container
	_options_container = _dialogue_panel.find_child("OptionsContainer", true, false) as VBoxContainer
	if _options_container == null:
		_options_container = VBoxContainer.new()
		_options_container.name = "OptionsContainer"
		_options_container.custom_minimum_size = Vector2(400, 100)
		_dialogue_panel.add_child(_options_container)
	
	# Rumor feed panel
	_rumor_feed_panel = _dialogue_panel.find_child("RumorFeedPanel", true, false) as PanelContainer
	if _rumor_feed_panel == null:
		_rumor_feed_panel = PanelContainer.new()
		_rumor_feed_panel.name = "RumorFeedPanel"
		_rumor_feed_panel.custom_minimum_size = Vector2(400, 100)
		
		var scroll = ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(400, 100)
		
		_rumor_feed_label = Label.new()
		_rumor_feed_label.text = "No rumors yet..."
		_rumor_feed_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		
		scroll.add_child(_rumor_feed_label)
		_rumor_feed_panel.add_child(scroll)
		_dialogue_panel.add_child(_rumor_feed_panel)
	else:
		_rumor_feed_label = _rumor_feed_panel.find_child("RumorFeedLabel", true, false) as Label


func show_hint(text: String) -> void:
	if _dialogue_open:
		return
	if _hint_label == null:
		return
	
	_hint_label.text = text
	_hint_label.show()


func hide_hint() -> void:
	if _hint_label == null:
		return
	_hint_label.hide()


func open_for_npc(npc: Node) -> void:
	"""Open dialogue with an NPC and query for conversation options"""
	_current_npc = npc
	_dialogue_open = true

	var npc_name: String = npc.name if npc != null else "Unknown"
	print("[DialogueUI] Opening dialogue with %s" % npc_name)

	hide_hint()

	if _dialogue_panel == null:
		push_error("DialogueUI: DialoguePanel is null")
		return

	_dialogue_panel.show()

	if _npc_name_label != null:
		_npc_name_label.text = npc_name
	
	# Clear previous content
	_clear_options()
	_npc_reply_label.text = "(Waiting for response...)"
	
	# Get interaction component and start dialogue
	if npc.has_method("start_dialogue"):
		# TODO: Get suggested options from NPC
		_show_dialogue_options(["Tell me about yourself", "Have you heard any rumors?", "I'd like to help"])


func _show_dialogue_options(options: Array[String]) -> void:
	"""Display dialogue options as interactive buttons"""
	_pending_options = options
	_clear_options()
	
	for option_text in options:
		var button = Button.new()
		button.text = option_text
		button.custom_minimum_size = Vector2(400, 30)
		button.pressed.connect(func(): _on_option_selected(option_text))
		_options_container.add_child(button)
	
	print("[DialogueUI] Showing %d options" % options.size())


func _on_option_selected(option_text: String) -> void:
	"""Called when player clicks a dialogue option"""
	print("[DialogueUI] Selected: %s" % option_text)
	
	if _current_npc and _current_npc.has_method("start_dialogue"):
		_current_npc.start_dialogue(option_text)
	
	_clear_options()


func set_npc_reply(reply_text: String) -> void:
	"""Set the NPC's reply text"""
	if _npc_reply_label:
		_npc_reply_label.text = reply_text
		print("[DialogueUI] Set NPC reply: %s" % reply_text)


func show_error(error_msg: String) -> void:
	"""Display an error message"""
	if _npc_reply_label:
		_npc_reply_label.text = "[ERROR] " + error_msg


func update_trust_display(trust_value: int) -> void:
	"""Update the trust meter display"""
	if _trust_meter == null:
		return
	
	# Map [-100, 100] relationship to [0, 200] progress range
	var progress = int((trust_value + 100) / 2.0)
	_trust_meter.value = clampi(progress, 0, 200)


func update_rumor_feed(rumors: Array) -> void:
	"""Update the rumor feed display with active rumors"""
	if _rumor_feed_label == null:
		return
	
	if rumors.is_empty():
		_rumor_feed_label.text = "No rumors spreading..."
		return
	
	var rumor_texts: Array[String] = []
	for rumor in rumors:
		if rumor is Dictionary:
			rumor_texts.append("• " + rumor.get("text", "???"))
		else:
			rumor_texts.append("• " + str(rumor))
	
	_rumor_feed_label.text = "\n".join(rumor_texts)


func close_dialogue() -> void:
	"""Close the dialogue panel and resume game"""
	print("[DialogueUI] Closing dialogue")

	_dialogue_open = false
	_current_npc = null
	_clear_options()

	if _dialogue_panel != null:
		_dialogue_panel.hide()


func is_dialogue_open() -> bool:
	return _dialogue_open


func _clear_options() -> void:
	"""Remove all option buttons"""
	for child in _options_container.get_children():
		child.queue_free()
	_pending_options.clear()


func _resolve_hint_label() -> Label:
	var n: Node = null
	if hint_label_path != NodePath():
		n = get_node_or_null(hint_label_path)
	if n == null:
		n = find_child("HintLabel", true, false)
	return n as Label


func _resolve_dialogue_panel() -> Control:
	var n: Node = null
	if dialogue_panel_path != NodePath():
		n = get_node_or_null(dialogue_panel_path)
	if n == null:
		n = find_child("DialoguePanel", true, false)
	return n as Control


func _resolve_npc_name_label() -> Label:
	var n: Node = null
	if npc_name_label_path != NodePath():
		n = get_node_or_null(npc_name_label_path)
	if n == null:
		n = find_child("NPCNameLabel", true, false)
	return n as Label
