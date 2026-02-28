extends CharacterBody2D

@export var npc_id: String = "npc_generic"
@export var display_name: String = "Citizen"

# Later: set this per NPC instance, ex:
# res://assets/data/npcs/baker.json
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

func _ready() -> void:
	_home = global_position
	_pick_new_dir()
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)

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
