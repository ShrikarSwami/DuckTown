extends Node
# PartyFlow.gd - single idempotent entry point for party transition

const PARTY_SCENE_PATH := "res://scenes/Party.tscn"

var has_triggered: bool = false
var trigger_source: String = ""

func _ready() -> void:
	print("[PartyFlow] Ready (single-fire trigger enabled)")

func trigger_party(source: String, force: bool = false) -> void:
	# Strict idempotency: accepted once, then hard reject duplicates.
	if has_triggered:
		print("[PartyFlow] DUPLICATE REJECTED source=%s existing_source=%s has_triggered=true" % [source, trigger_source])
		return

	var approvals_met := _are_all_approvals_met()
	if not force and not approvals_met:
		print("[PartyFlow] BLOCKED source=%s force=false approvals_met=false" % source)
		return

	has_triggered = true
	trigger_source = source
	print("[PartyFlow] TRIGGER ACCEPTED source=%s force=%s approvals_met=%s" % [source, force, approvals_met])
	print("[PartyFlow] BRANCH=%s" % ("force_debug" if force else "approvals"))

	_close_dialogue_if_open()
	_disable_player_input()
	_change_to_party_scene()

func _are_all_approvals_met() -> bool:
	var quest_manager := _get_quest_manager()
	if quest_manager == null:
		return false

	var baker_ok := bool(quest_manager.call("is_approved", "baker"))
	var merch_ok := bool(quest_manager.call("is_approved", "merch"))
	var mean_guard_ok := bool(quest_manager.call("is_approved", "meanGuard"))
	return baker_ok and merch_ok and mean_guard_ok

func _get_quest_manager() -> Node:
	var scene = get_tree().get_current_scene()
	if scene != null:
		var qm = scene.get_node_or_null("QuestManager")
		if qm != null:
			return qm
	return get_tree().root.get_node_or_null("Main/QuestManager")

func _close_dialogue_if_open() -> void:
	for node in get_tree().get_nodes_in_group("dialogue_ui"):
		if node != null and node.has_method("is_open") and node.is_open() and node.has_method("close"):
			print("[PartyFlow] Closing DialogueUI before transition")
			node.close()
			return

func _disable_player_input() -> void:
	for player in get_tree().get_nodes_in_group("player"):
		if player == null:
			continue
		player.set_process_input(false)
		player.set_process_unhandled_input(false)
		player.set_physics_process(false)
		print("[PartyFlow] Player input disabled")
		return

func _change_to_party_scene() -> void:
	if not ResourceLoader.exists(PARTY_SCENE_PATH):
		push_error("[PartyFlow] Party scene not found: %s" % PARTY_SCENE_PATH)
		return

	print("[PartyFlow] Changing scene to %s" % PARTY_SCENE_PATH)
	var err := get_tree().change_scene_to_file(PARTY_SCENE_PATH)
	if err != OK:
		push_error("[PartyFlow] Failed to change scene to party (err=%d)" % err)

func get_status() -> String:
	return "PartyFlow { has_triggered=%s source=%s }" % [has_triggered, trigger_source]
