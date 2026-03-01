extends Node2D
# Party scene - celebration when all approvals are obtained

func _ready():
	print("🎉 PARTY SCENE LOADED!")
	
	# Play celebration audio/animation
	_play_celebration()
	
	# Auto-restart after 3 seconds
	await get_tree().create_timer(3.0).timeout
	print("🔄 Restarting game...")
	get_tree().reload_current_scene()

func _play_celebration() -> void:
	"""Play party celebration animation/effects"""
	# Animate confetti or whatever celebration effect
	var tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	
	# Pulse the title
	var title = $Celebration/Title
	for i in range(3):
		tween.tween_property(title, "scale", Vector2(1.2, 1.2), 0.2)
		tween.tween_property(title, "scale", Vector2(1.0, 1.0), 0.2)
	
	# Change background color
	var bg = $Celebration/Background
	tween.tween_property(bg, "color", Color.YELLOW, 0.5)
	tween.tween_property(bg, "color", Color(0.8, 0.6, 0.2, 1.0), 0.5)
