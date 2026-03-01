extends Control

@onready var name_label: Label = $DialoguePanel/Margin/VBox/NameLabel
@onready var chat_log: RichTextLabel = $DialoguePanel/Margin/VBox/ChatLog
@onready var user_input: LineEdit = $DialoguePanel/Margin/VBox/InputRow/UserInput
@onready var send_button: Button = $DialoguePanel/Margin/VBox/InputRow/SendButton
@onready var hint_label: Label = $Hud/DialogueUI/DialoguePanel/Margin/VBox/HintLabel

func show_hint(npc_name: String) -> void:
	hint_label.text = "Press E to talk to " + npc_name
	hint_label.show()

func hide_hint() -> void:
	hint_label.hide()

var current_npc: Node = null

func _ready() -> void:
	hide()
	send_button.pressed.connect(_on_send_pressed)
	user_input.text_submitted.connect(_on_text_submitted)

func open_for_npc(npc: Node) -> void:
	current_npc = npc
	show()
	user_input.grab_focus()

	# NPC display name (fallback to node name)
	var display_name := npc.name
	if npc.has_meta("display_name"):
		display_name = str(npc.get_meta("display_name"))

	name_label.text = display_name

	# Optional greeting
	chat_log.clear()
	_append_line("[b]%s:[/b] Hello." % display_name)

func _on_send_pressed() -> void:
	_submit_user_text()

func _on_text_submitted(_text: String) -> void:
	_submit_user_text()

func _submit_user_text() -> void:
	var msg := user_input.text.strip_edges()
	if msg == "":
		return

	_append_line("[b]You:[/b] %s" % msg)
	user_input.text = ""

	# Placeholder response for now
	var npc_name := name_label.text
	_append_line("[b]%s:[/b] (thinking...)" % npc_name)

func _append_line(bbcode_line: String) -> void:
	chat_log.append_text(bbcode_line + "\n")
	chat_log.scroll_to_line(chat_log.get_line_count())
