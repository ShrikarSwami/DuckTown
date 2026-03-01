extends CharacterBody2D

@export var speed := 160.0
@onready var interact_area := $InteractArea
@onready var dialogue_ui := get_tree().get_first_node_in_group("dialogue_ui")

var nearby_interact_areas := []


func _ready() -> void:
	# Safety checks so you immediately know what is missing.
	if interact_area == null:
		push_error("Player is missing child Area2D named 'InteractArea'.")
	else:
		interact_area.area_entered.connect(_on_area_entered)
		interact_area.area_exited.connect(_on_area_exited)

	if dialogue_ui == null:
		push_error("No node in group 'dialogue_ui'. Put your DialogueUI node in that group AND make sure UI.tscn is instanced in Main.")

	_setup_input_map_if_missing()


func _physics_process(_delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * speed
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	# Press E to interact
	if event.is_action_pressed("interact"):
		_try_interact()
		get_viewport().set_input_as_handled()


func _try_interact() -> void:
	var closest := _get_closest_interact_area()
	if closest == null:
		return

	# The interact Area2D is a child of the NPC scene, so its parent should be the NPC root.
	var npc := closest.get_parent()
	if npc == null:
		return

	if dialogue_ui != null and dialogue_ui.has_method("open_for_npc"):
		dialogue_ui.call("open_for_npc", npc)


func _get_closest_interact_area() -> Area2D:
	if nearby_interact_areas.is_empty():
		return null

	var closest: Area2D = null
	var best_dist := INF
	for a in nearby_interact_areas:
		if a == null:
			continue
		var d := global_position.distance_to(a.global_position)
		if d < best_dist:
			best_dist = d
			closest = a
	return closest


func _on_area_entered(area: Area2D) -> void:
	if area == null or not area.is_in_group("npc_interact"):
		return

	if not nearby_interact_areas.has(area):
		nearby_interact_areas.append(area)

	var npc := area.get_parent()
	var npc_name: String = "NPC"
	if npc != null:
		npc_name = str(npc.name)

	if dialogue_ui != null and dialogue_ui.has_method("show_hint"):
		dialogue_ui.call("show_hint", "Press E to talk to " + npc_name)
func _on_area_exited(area: Area2D) -> void:
	if area == null:
		return

	if nearby_interact_areas.has(area):
		nearby_interact_areas.erase(area)

	if nearby_interact_areas.is_empty():
		if dialogue_ui != null and dialogue_ui.has_method("hide_hint"):
			dialogue_ui.call("hide_hint")
	else:
		var closest := _get_closest_interact_area()
		if closest != null:
			var npc := closest.get_parent()
			var npc_name: String = "NPC"
			if npc != null:
				npc_name = str(npc.name)

			if dialogue_ui != null and dialogue_ui.has_method("show_hint"):
				dialogue_ui.call("show_hint", "Press E to talk to " + npc_name)


func _setup_input_map_if_missing() -> void:
	_ensure_action_with_keys("move_left", [KEY_A, KEY_LEFT])
	_ensure_action_with_keys("move_right", [KEY_D, KEY_RIGHT])
	_ensure_action_with_keys("move_up", [KEY_W, KEY_UP])
	_ensure_action_with_keys("move_down", [KEY_S, KEY_DOWN])
	_ensure_action_with_keys("interact", [KEY_E])


func _ensure_action_with_keys(action_name: String, keys: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for k in keys:
		if _action_has_key(action_name, k):
			continue
		var ev := InputEventKey.new()
		ev.keycode = int(k)
		InputMap.action_add_event(action_name, ev)


func _action_has_key(action_name: String, keycode_value: int) -> bool:
	for ev in InputMap.action_get_events(action_name):
		if ev is InputEventKey and (ev as InputEventKey).keycode == keycode_value:
			return true
	return false
