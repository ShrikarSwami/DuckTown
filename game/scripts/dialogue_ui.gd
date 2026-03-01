extends Control

@export var hint_label_path: NodePath
@export var dialogue_panel_path: NodePath
@export var npc_name_label_path: NodePath

var _hint_label: Label
var _dialogue_panel: Control
var _npc_name_label: Label
var _chat_log: RichTextLabel
var _user_input: LineEdit
var _send_button: Button
var _options_container: VBoxContainer

var _dialogue_open: bool = false
var _waiting_for_response: bool = false
var _current_npc: Node = null
var _active_interaction: Node = null
var _first_dialogue_of_run: bool = true
var _demo_run_count: int = 1

const DEMO_RUDE_OPTION_TEXT := "We don’t even need you."

func _ready() -> void:
	_hint_label = _resolve_hint_label()
	_dialogue_panel = _resolve_dialogue_panel()
	_npc_name_label = _resolve_npc_name_label()

	if not is_in_group("dialogue_ui"):
		add_to_group("dialogue_ui")

	if _dialogue_panel == null:
		push_error("[DialogueUI] DialoguePanel not found")
		return

	_setup_dialogue_panel()
	_dialogue_panel.hide()
	if _hint_label != null:
		_hint_label.hide()

	if get_tree().root.has_meta("demo_run_count"):
		_demo_run_count = int(get_tree().root.get_meta("demo_run_count"))

	# Enable input for debug
	set_process_unhandled_input(true)

	print("[DialogueUI] Ready")


func _setup_dialogue_panel() -> void:
	_chat_log = _dialogue_panel.find_child("ChatLog", true, false) as RichTextLabel
	_user_input = _dialogue_panel.find_child("UserInput", true, false) as LineEdit
	_send_button = _dialogue_panel.find_child("SendButton", true, false) as Button

	if _npc_name_label == null:
		_npc_name_label = _dialogue_panel.find_child("NameLabel", true, false) as Label

	_options_container = _dialogue_panel.find_child("OptionsContainer", true, false) as VBoxContainer
	if _options_container == null:
		_options_container = VBoxContainer.new()
		_options_container.name = "OptionsContainer"
		_options_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_options_container.custom_minimum_size = Vector2(0, 120)
		_options_container.add_theme_constant_override("separation", 6)

		var input_row := _dialogue_panel.find_child("InputRow", true, false)
		if input_row != null and input_row.get_parent() != null:
			input_row.get_parent().add_child(_options_container)
			input_row.get_parent().move_child(_options_container, input_row.get_index())
		else:
			_dialogue_panel.add_child(_options_container)

	if _send_button != null and not _send_button.pressed.is_connected(_on_send_pressed):
		_send_button.pressed.connect(_on_send_pressed)
	if _user_input != null and not _user_input.text_submitted.is_connected(_on_user_text_submitted):
		_user_input.text_submitted.connect(_on_user_text_submitted)


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
	if npc == null:
		push_error("[DialogueUI] open_for_npc called with null npc")
		return
	if _dialogue_panel == null:
		push_error("[DialogueUI] DialoguePanel is null")
		return
	if _dialogue_open:
		close()

	var npc_id: String = str(npc.get("npc_id")) if npc.get("npc_id") != null else str(npc.name)
	print("[DialogueUI] open_for_npc %s" % npc_id)

	_current_npc = npc
	_active_interaction = npc.get_node_or_null("NPC_Interaction")
	_dialogue_open = true
	_waiting_for_response = false

	hide_hint()
	
	# ===== HARD FORCE VISIBILITY =====
	visible = true
	show()
	_dialogue_panel.visible = true
	_dialogue_panel.show()

	# ===== DEBUG TELEMETRY =====
	print("========== DIALOGUE DEBUG ==========")
	print("[DialogueUI] self visible:", visible)
	print("[DialogueUI] panel visible:", _dialogue_panel.visible)
	print("[DialogueUI] self global_position:", global_position)
	print("[DialogueUI] panel global_position:", _dialogue_panel.global_position)
	print("[DialogueUI] panel position:", _dialogue_panel.position)
	print("[DialogueUI] panel size:", _dialogue_panel.size)
	print("[DialogueUI] panel rect:", _dialogue_panel.get_rect())
	print("[DialogueUI] viewport size:", get_viewport().get_visible_rect().size)
	print("[DialogueUI] z_index:", z_index)
	print("[DialogueUI] parent:", get_parent().name)
	print("[DialogueUI] parent type:", get_parent().get_class())
	print("====================================")

	# ===== FORCE CENTER POSITION TEST =====
	_dialogue_panel.set_anchors_preset(Control.PRESET_CENTER)
	_dialogue_panel.position = get_viewport().get_visible_rect().size / 2 - _dialogue_panel.size / 2
	print("[DialogueUI] Forced center position:", _dialogue_panel.position)

	if _npc_name_label != null:
		var display_name := ""
		if npc.get("display_name") != null:
			display_name = str(npc.get("display_name"))
		_npc_name_label.text = display_name if display_name != "" else npc.name

	_clear_chat_log()
	_append_chat_line("System", "What would you like to talk about?")
	_clear_options()
	var opening_options = _get_phase_aware_options()
	if opening_options.size() < 2:
		opening_options = _build_default_options()
	_show_dialogue_options(opening_options)

	if _user_input != null:
		_user_input.editable = true
		_user_input.text = ""
		_user_input.placeholder_text = "Type a message or pick an option..."
		_user_input.grab_focus()

	print("[DialogueUI] Opened for %s" % npc.name)


func _build_default_options() -> Array[String]:
	var options: Array[String] = []
	
	# Add rude option on second run for first NPC only
	if _first_dialogue_of_run:
		if _demo_run_count >= 2:
			options.append(DEMO_RUDE_OPTION_TEXT)
		_first_dialogue_of_run = false
	
	options.append("Tell me about yourself")
	options.append("Have you heard any rumors?")
	options.append("I'd like to help")
	return options


func _show_dialogue_options(options: Array[String]) -> void:
	if _options_container == null:
		return
	_clear_options()
	for option_text in options:
		var button := Button.new()
		button.text = option_text
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 34)
		if option_text == "Close":
			button.pressed.connect(_on_close_button_pressed)
		elif option_text == "Continue":
			button.pressed.connect(_on_continue_button_pressed)
		else:
			button.pressed.connect(func() -> void: _on_option_selected(option_text))
		_options_container.add_child(button)


func _on_option_selected(option_text: String) -> void:
	print("[DialogueUI] Selected option: %s" % option_text)
	
	# Mark rude option for special handling
	if option_text == DEMO_RUDE_OPTION_TEXT and _active_interaction:
		if _active_interaction.has_method("set_is_rude_option"):
			_active_interaction.set_is_rude_option(true)
	
	_submit_player_text(option_text)


func _on_send_pressed() -> void:
	if _user_input == null:
		return
	_submit_player_text(_user_input.text)


func _on_user_text_submitted(new_text: String) -> void:
	_submit_player_text(new_text)


func _submit_player_text(raw_text: String) -> void:
	if not _dialogue_open:
		return
	if _waiting_for_response:
		return
	if _active_interaction == null or not _active_interaction.has_method("start_dialogue"):
		show_error("I can't reach this NPC right now.")
		return

	var message := raw_text.strip_edges()
	if message.is_empty():
		return

	_waiting_for_response = true
	_append_chat_line("You", message)
	_append_chat_line("System", "Waiting for response…")
	_clear_options()

	if _user_input != null:
		_user_input.editable = false
		_user_input.text = ""

	_active_interaction.start_dialogue(message)


func set_npc_reply(reply_text: String) -> void:
	var safe_reply := reply_text
	if safe_reply == null:
		safe_reply = ""
	safe_reply = safe_reply.strip_edges()
	if safe_reply.is_empty():
		safe_reply = "I heard you, but I don't know what to say yet."

	print("[DialogueUI] Received reply length=%d" % safe_reply.length())
	_append_chat_line("NPC", safe_reply)
	_waiting_for_response = false

	if _user_input != null:
		_user_input.editable = true
		_user_input.grab_focus()

	_show_post_reply_options()


func show_error(error_msg: String) -> void:
	var safe_msg := error_msg
	if safe_msg == null:
		safe_msg = ""
	safe_msg = safe_msg.strip_edges()
	if safe_msg.is_empty():
		safe_msg = "Something went wrong."
	_append_chat_line("NPC", safe_msg)
	_waiting_for_response = false
	if _user_input != null:
		_user_input.editable = true
	_show_post_reply_options()


func update_trust_display(trust_value: int) -> void:
	if _chat_log == null:
		return
	# Keep method for compatibility with callers; HUD owns main trust display.
	if trust_value < -100 or trust_value > 100:
		print("[DialogueUI] Trust value out of expected range: %d" % trust_value)


func _on_continue_button_pressed() -> void:
	if not _dialogue_open:
		return
	_append_chat_line("System", "What else would you like to ask?")
	var continue_options = _get_phase_aware_options()
	if continue_options.size() < 2:
		continue_options = _build_default_options()
	_show_dialogue_options(continue_options)
	if _user_input != null:
		_user_input.editable = true
		_user_input.grab_focus()


func _on_close_button_pressed() -> void:
	close()


func close() -> void:
	if not _dialogue_open and _current_npc == null and _active_interaction == null:
		return

	print("[DialogueUI] close")

	if _active_interaction != null and _active_interaction.has_method("end_dialogue"):
		_active_interaction.end_dialogue()
	if _current_npc != null and _current_npc.has_method("set_talking"):
		_current_npc.set_talking(false)

	_dialogue_open = false
	_waiting_for_response = false
	_current_npc = null
	_active_interaction = null
	_clear_options()

	if _user_input != null:
		_user_input.release_focus()
		_user_input.editable = true
		_user_input.text = ""

	if _dialogue_panel != null:
		_dialogue_panel.hide()


func close_dialogue() -> void:
	close()


func _draw() -> void:
	# Draw visual debug box to verify rendering
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0, 0, 0.2), true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		print("[DialogueUI] ESC pressed")
		if visible and _dialogue_open:
			print("[DialogueUI] Closing dialogue via ESC")
			close_dialogue()


func is_open() -> bool:
	return _dialogue_open


func is_dialogue_open() -> bool:
	return is_open()


func _set_dialogue_text(text: String) -> void:
	if _chat_log != null:
		_chat_log.text = text


func _append_chat_line(speaker: String, text: String) -> void:
	if _chat_log == null:
		return
	var safe_text := text if text != null else ""
	safe_text = safe_text.strip_edges()
	if safe_text.is_empty():
		return
	var line := "%s: %s" % [speaker, safe_text]
	if _chat_log.text.strip_edges().is_empty():
		_chat_log.text = line
	else:
		_chat_log.text += "\n" + line
	_chat_log.scroll_to_line(max(_chat_log.get_line_count() - 1, 0))
	
	# ===== CHATLOG POPULATION DEBUG =====
	print("[DialogueUI] ChatLog text now length:", _chat_log.text.length())
	print("[DialogueUI] ChatLog line count:", _chat_log.get_line_count())


func _clear_chat_log() -> void:
	if _chat_log == null:
		return
	_chat_log.text = ""


func _show_post_reply_options() -> void:
	var scripted_options = _get_phase_aware_options()
	if scripted_options.size() >= 2:
		var demo_options: Array[String] = []
		for option_text in scripted_options:
			demo_options.append(option_text)
			if demo_options.size() >= 3:
				break
		if not demo_options.has("Close") and demo_options.size() < 4:
			demo_options.append("Close")
		_show_dialogue_options(demo_options)
		return

	var base_options: Array[String] = []
	if _active_interaction != null and _active_interaction.has_method("get_dialogue_options"):
		var raw_options = _active_interaction.get_dialogue_options()
		if typeof(raw_options) == TYPE_ARRAY:
			for item in raw_options:
				if typeof(item) == TYPE_STRING:
					var option_text := str(item).strip_edges()
					if not option_text.is_empty() and not base_options.has(option_text):
						base_options.append(option_text)

	if base_options.size() < 2:
		for fallback_option in _build_default_options():
			if not base_options.has(fallback_option):
				base_options.append(fallback_option)

	var final_options: Array[String] = []
	for option_text in base_options:
		final_options.append(option_text)
		if final_options.size() >= 3:
			break

	final_options.append("Continue")
	final_options.append("Close")
	_show_dialogue_options(final_options)


func _get_phase_aware_options() -> Array[String]:
	var options: Array[String] = []
	if _active_interaction == null:
		return options

	var npc_id_value = _active_interaction.get("npc_id")
	if npc_id_value == null:
		return options

	var quest_manager = get_tree().root.get_node_or_null("Main/QuestManager")
	if quest_manager == null or not quest_manager.has_method("get_demo_options_for_npc"):
		return options

	var raw_options = quest_manager.get_demo_options_for_npc(str(npc_id_value))
	if typeof(raw_options) != TYPE_ARRAY:
		return options

	for item in raw_options:
		if typeof(item) == TYPE_STRING:
			var option_text := str(item).strip_edges()
			if not option_text.is_empty() and not options.has(option_text):
				options.append(option_text)
			if options.size() >= 4:
				break

	return options


func _clear_options() -> void:
	if _options_container == null:
		return
	for child in _options_container.get_children():
		child.queue_free()


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
		n = find_child("NameLabel", true, false)
	if n == null:
		n = find_child("NPCNameLabel", true, false)
	return n as Label
