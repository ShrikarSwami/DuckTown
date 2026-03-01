extends CharacterBody2D

@export var speed: float = 160.0
@export var debug_interact: bool = true

@onready var interact_area: Area2D = $InteractArea
@onready var dialogue_ui: Node = get_tree().get_first_node_in_group("dialogue_ui")

var nearby_interact_areas: Array[Area2D] = []

func _ready() -> void:
	if dialogue_ui == null:
		push_error("No node in group 'dialogue_ui'. Add DialogueUI to that group and instance UI.tscn in Main.")

	interact_area.area_entered.connect(_on_area_entered)
	interact_area.area_exited.connect(_on_area_exited)

	_setup_input_map_if_missing()

func _physics_process(_delta: float) -> void:
	var dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * speed
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_try_interact()
		get_viewport().set_input_as_handled()

func _try_interact() -> void:
	var closest: Area2D = _get_closest_interact_area()
	if closest == null:
		return

	var npc: Node = closest.get_parent()
	if npc == null:
		return

	if dialogue_ui != null and dialogue_ui.has_method("open_for_npc"):
		dialogue_ui.call("open_for_npc", npc)

func _get_closest_interact_area() -> Area2D:
	if nearby_interact_areas.is_empty():
		return null

	var closest: Area2D = null
	var best_dist: float = INF

	for a: Area2D in nearby_interact_areas:
		if a == null:
			continue
		var d: float = global_position.distance_to(a.global_position)
		if d < best_dist:
			best_dist = d
			closest = a

	return closest

func _on_area_entered(area: Area2D) -> void:
	if area == null:
		return
	if not area.is_in_group("npc_interact"):
		return

	if debug_interact:
		print("Entered npc_interact: ", area.name)

	if not nearby_interact_areas.has(area):
		nearby_interact_areas.append(area)

	var npc: Node = area.get_parent()
	var npc_name: String = npc.name if npc != null else "NPC"

	if dialogue_ui != null and dialogue_ui.has_method("show_hint"):
		var hint_text: String = "Press E to talk to %s" % npc_name
		dialogue_ui.call("show_hint", hint_text)

func _on_area_exited(area: Area2D) -> void:
	if area == null:
		return
	if not nearby_interact_areas.has(area):
		return

	if debug_interact:
		print("Exited npc_interact: ", area.name)

	nearby_interact_areas.erase(area)

	if dialogue_ui != null and dialogue_ui.has_method("hide_hint"):
		if nearby_interact_areas.is_empty():
			dialogue_ui.call("hide_hint")
		else:
			var closest: Area2D = _get_closest_interact_area()
			var npc: Node = closest.get_parent() if closest != null else null
			var npc_name: String = npc.name if npc != null else "NPC"
			if dialogue_ui.has_method("show_hint"):
				var hint_text: String = "Press E to talk to %s" % npc_name
				dialogue_ui.call("show_hint", hint_text)

func _setup_input_map_if_missing() -> void:
	_ensure_action_with_keys("move_left", [KEY_A, KEY_LEFT])
	_ensure_action_with_keys("move_right", [KEY_D, KEY_RIGHT])
	_ensure_action_with_keys("move_up", [KEY_W, KEY_UP])
	_ensure_action_with_keys("move_down", [KEY_S, KEY_DOWN])
	_ensure_action_with_keys("interact", [KEY_E])

func _ensure_action_with_keys(action_name: StringName, keys: Array[Key]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for k: Key in keys:
		if _action_has_key(action_name, k):
			continue
		var ev := InputEventKey.new()
		ev.keycode = k
		InputMap.action_add_event(action_name, ev)

func _action_has_key(action_name: StringName, keycode_value: Key) -> bool:
	for ev: InputEvent in InputMap.action_get_events(action_name):
		if ev is InputEventKey and (ev as InputEventKey).keycode == keycode_value:
			return true
	return false
