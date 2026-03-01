extends Control
# Story Intro - Shows game premise and controls before starting

var _can_continue: bool = false

func _ready():
	print("[StoryIntro] Ready - showing story")
	# Make the continue prompt blink
	_start_blink_animation()

func _on_timer_timeout():
	# Allow player to continue after brief delay
	_can_continue = true

func _input(event):
	if not _can_continue:
		return
	
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_start_game()

func _start_game():
	print("[StoryIntro] Starting main game")
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _start_blink_animation():
	var prompt = $MarginContainer/VBoxContainer/ContinuePrompt
	if prompt:
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(prompt, "modulate:a", 0.3, 0.8)
		tween.tween_property(prompt, "modulate:a", 1.0, 0.8)
