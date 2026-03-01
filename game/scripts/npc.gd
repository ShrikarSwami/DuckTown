extends CharacterBody2D

@export var npc_id: String = "npc_generic"
@export var display_name: String = "Citizen"
@export_file("*.json") var profile_json_path: String = ""

@export var speed: float = 80.0
@export var wander_radius: float = 90.0
@export var change_dir_time: float = 1.3
@export var map_min: Vector2 = Vector2(30, 30)
@export var map_max: Vector2 = Vector2(1570, 870)

signal npc_in_range(npc: Node)
signal npc_out_of_range(npc: Node)

@onready var interact_area: Area2D = $InteractArea
@onready var name_tag: Label = $NameTag

var _home: Vector2
var _timer: float = 0.0
var _dir: Vector2 = Vector2.ZERO
var _interaction_component: Node = null
var _roam_points: Array[Vector2] = []
var _is_talking: bool = false

func _ready() -> void:
	# Add to NPC group
	add_to_group("npc")
	
	_home = global_position
	_pick_new_dir()
	
	# Set name tag
	if name_tag:
		name_tag.text = display_name if display_name != "" else npc_id.capitalize()
	
	# Connect interaction area for player detection
	if interact_area:
		interact_area.body_entered.connect(_on_body_entered)
		interact_area.body_exited.connect(_on_body_exited)
		interact_area.input_pickable = true
		if not interact_area.input_event.is_connected(_on_interact_area_input_event):
			interact_area.input_event.connect(_on_interact_area_input_event)
	
	# Find interaction component immediately (should have been added by main.gd)
	_interaction_component = get_node_or_null("NPC_Interaction")
	if _interaction_component:
		print("[NPC %s] Interaction component found" % name)
	else:
		push_error("[NPC %s] Interaction component NOT found! Check main.gd setup." % name)

func _physics_process(delta: float) -> void:
	if _is_talking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_timer -= delta
	if _timer <= 0.0:
		_pick_new_dir()

	var offset := global_position - _home
	if offset.length() > wander_radius:
		_dir = (-offset).normalized()

	velocity = _dir * speed
	move_and_slide()
	global_position = global_position.clamp(map_min, map_max)

func _pick_new_dir() -> void:
	if not _roam_points.is_empty() and randi_range(0, 100) < 45:
		_home = _roam_points[randi() % _roam_points.size()]
	_timer = change_dir_time
	_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	if randf() < 0.55:
		_dir = ( _home - global_position ).normalized()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		npc_in_range.emit(self)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		npc_out_of_range.emit(self)

# === Integration with Interaction System ===

func start_dialogue(message: String = "") -> void:
	"""Forward dialogue request to NPC_Interaction component"""
	print("[NPC] start_dialogue %s" % npc_id)
	set_talking(true)

	if _interaction_component == null:
		_interaction_component = get_node_or_null("NPC_Interaction")

	if _interaction_component == null:
		push_error("[NPC %s] No NPC_Interaction component! Cannot start dialogue." % name)
		return
	
	if not _interaction_component.has_method("start_dialogue"):
		push_error("[NPC %s] Interaction component missing start_dialogue method!" % name)
		return
	
	_interaction_component.start_dialogue(message)


func end_dialogue() -> void:
	if _interaction_component != null and _interaction_component.has_method("end_dialogue"):
		_interaction_component.end_dialogue()
	set_talking(false)

func get_relationship() -> int:
	"""Get current relationship score"""
	if _interaction_component and _interaction_component.has_method("get_relationship"):
		return _interaction_component.get_relationship()
	return 0

func on_rumor_learned(rumor_id: String, rumor_text: String, from_npc: String) -> void:
	"""Called when this NPC learns a new rumor"""
	print("[NPC %s] 💬 Learned rumor from %s: '%s'" % [name, from_npc, rumor_text])
	
	# React based on personality
	# For demo, just modify relationship slightly
	if _interaction_component and _interaction_component.has_method("update_relationship"):
		var delta = randi_range(-5, 5)
		_interaction_component.update_relationship(delta)

func set_roam_points(points: Array[Vector2]) -> void:
	"""Inject shared roam markers so NPCs spread around town"""
	_roam_points = points.duplicate()
	if not _roam_points.is_empty() and randf() < 0.6:
		_home = _roam_points[randi() % _roam_points.size()]

func set_talking(is_talking: bool) -> void:
	if _is_talking == is_talking:
		return
	_is_talking = is_talking
	print("[NPC] set_talking %s" % ("true" if is_talking else "false"))
	if _is_talking:
		velocity = Vector2.ZERO

func _on_interact_area_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if not (event is InputEventMouseButton):
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	var dialogue_ui = get_tree().get_first_node_in_group("dialogue_ui")
	if dialogue_ui != null and dialogue_ui.has_method("is_open") and dialogue_ui.is_open():
		return

	print("[Click] NPC clicked: %s" % (display_name if display_name != "" else npc_id))
	start_dialogue("")
