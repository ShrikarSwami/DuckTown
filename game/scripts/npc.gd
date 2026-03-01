extends CharacterBody2D

@export var npc_id: String = "npc_generic"
@export var display_name: String = "Citizen"
@export_file("*.json") var profile_json_path: String = ""

@export var speed: float = 80.0
@export var wander_radius: float = 90.0
@export var change_dir_time: float = 1.3

signal npc_in_range(npc: Node)
signal npc_out_of_range(npc: Node)

@onready var interact_area: Area2D = $InteractArea

var _home: Vector2
var _timer: float = 0.0
var _dir: Vector2 = Vector2.ZERO
var _interaction_component: Node = null

func _ready() -> void:
	# Add to NPC group
	add_to_group("npc")
	
	_home = global_position
	_pick_new_dir()
	
	# Connect interaction area
	if interact_area:
		interact_area.body_entered.connect(_on_body_entered)
		interact_area.body_exited.connect(_on_body_exited)
	
	# Find or wait for interaction component
	call_deferred("_find_interaction_component")

func _find_interaction_component() -> void:
	"""Locate the interaction component (added by Main.gd)"""
	_interaction_component = get_node_or_null("NPC_Interaction")
	if _interaction_component:
		print("[NPC %s] Found interaction component" % name)

func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_pick_new_dir()

	var offset := global_position - _home
	if offset.length() > wander_radius:
		_dir = (-offset).normalized()

	velocity = _dir * speed
	move_and_slide()

func _pick_new_dir() -> void:
	_timer = change_dir_time
	_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		npc_in_range.emit(self)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		npc_out_of_range.emit(self)

# === Integration with Interaction System ===

func start_dialogue(message: String) -> void:
	"""Forward dialogue request to interaction component"""
	if _interaction_component and _interaction_component.has_method("start_dialogue"):
		_interaction_component.start_dialogue(message)
	else:
		push_error("[NPC %s] No interaction component found!" % name)

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
