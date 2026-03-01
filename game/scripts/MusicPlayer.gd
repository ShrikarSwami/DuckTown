extends AudioStreamPlayer
# Background music player - plays continuously until party scene

var main_theme = preload("res://assets/Audio/Duck_Town_Music.mp3")

func _ready():
	stream = main_theme
	autoplay = true
	bus = "Master"
	volume_db = -10
	play()
	print("[MusicPlayer] Background music started")

func stop_music():
	"""Called by party scene to stop background music"""
	stop()
	print("[MusicPlayer] Background music stopped")