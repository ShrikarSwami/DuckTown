# dialogue_ui.gd (clean replacement, no pinning, relies on UI.tscn anchors)
extends Control

@export var hint_label_path: NodePath
@export var dialogue_panel_path: NodePath
@export var npc_name_label_path: NodePath

var _hint_label: Label
var _dialogue_panel: Control
var _npc_name_label: Label

var _dialogue_open: bool = false
var _current_npc: Node = null


func _ready() -> void:
	_hint_label = _resolve_hint_label()
	_dialogue_panel = _resolve_dialogue_panel()
	_npc_name_label = _resolve_npc_name_label()

	print("DialogueUI ready")
	print("  HintLabel resolved: %s" % _node_debug(_hint_label))
	print("  DialoguePanel resolved: %s" % _node_debug(_dialogue_panel))
	print("  NPCNameLabel resolved: %s" % _node_debug(_npc_name_label))

	if _dialogue_panel == null:
		push_error("DialogueUI: DialoguePanel not found. Set dialogue_panel_path OR ensure a child named DialoguePanel exists.")
	else:
		_dialogue_panel.hide()
		print("  DialoguePanel hidden on ready (visible=%s)" % str(_dialogue_panel.visible))

	if _hint_label != null:
		_hint_label.hide()


func show_hint(text: String) -> void:
	print("show_hint called with npc name: %s" % _extract_npc_name_from_hint(text))

	if _dialogue_open:
		return

	if _hint_label == null:
		push_warning("DialogueUI: show_hint called but HintLabel is null. Set hint_label_path OR ensure a child named HintLabel exists.")
		return

	_hint_label.text = text
	_hint_label.show()


func hide_hint() -> void:
	print("hide_hint called")

	if _hint_label == null:
		return

	_hint_label.hide()


func open_for_npc(npc: Node) -> void:
	_current_npc = npc
	_dialogue_open = true

	var npc_name: String = npc.name if npc != null else "Unknown"
	print("open_for_npc called with npc name: %s" % npc_name)

	hide_hint()

	if _dialogue_panel == null:
		push_error("DialogueUI: open_for_npc called but DialoguePanel is null. Set dialogue_panel_path OR ensure a child named DialoguePanel exists.")
		return

	_dialogue_panel.show()

	if _npc_name_label != null:
		_npc_name_label.text = npc_name

	print("  DialoguePanel visible=%s" % str(_dialogue_panel.visible))


func close_dialogue() -> void:
	print("close_dialogue called")

	_dialogue_open = false
	_current_npc = null

	if _dialogue_panel != null:
		_dialogue_panel.hide()


func is_dialogue_open() -> bool:
	return _dialogue_open


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


func _extract_npc_name_from_hint(text: String) -> String:
	var marker: String = "Press E to talk to "
	var idx: int = text.find(marker)
	if idx == -1:
		return text
	return text.substr(idx + marker.length())


func _node_debug(n: Node) -> String:
	if n == null:
		return "null"
	return "%s (%s)" % [String(n.get_path()), n.get_class()]
