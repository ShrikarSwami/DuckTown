extends CharacterBody2D
# Player controller for Duck Party Rumor Game

# TODO: Implement player movement and animation

const SPEED = 200.0
const ACCELERATION = 500.0

var input_direction = Vector2.ZERO
var is_moving = false

func _ready():
    # TODO: Load player sprite and animations
    pass

func _process(delta):
    # TODO: Handle input
    get_input()
    
    # TODO: Update animation based on direction and movement
    # TODO: Handle sprite facing direction
    pass

func _physics_process(delta):
    # TODO: Implement movement with CharacterBody2D
    # - Apply acceleration
    # - Check collisions
    # - Play walk animation
    
    if input_direction != Vector2.ZERO:
        velocity = velocity.move_toward(input_direction * SPEED, ACCELERATION * delta)
    else:
        velocity = velocity.move_toward(Vector2.ZERO, ACCELERATION * delta)
    
    # TODO: Uncomment when collision is set up
    # move_and_slide()

func get_input():
    # TODO: Handle WASD and arrow keys
    var input = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    input_direction = input.normalized()
    
    # TODO: Update facing direction for sprite flipping
    if input_direction != Vector2.ZERO:
        is_moving = true
        # TODO: Play walk animation
    else:
        is_moving = false
        # TODO: Play idle animation

func play_animation(direction: Vector2):
    # TODO: Play walk animation based on direction
    # Directions: up, down, left, right
    pass

func set_animation_speed(speed: float):
    # TODO: Scale animation speed based on movement speed
    pass
