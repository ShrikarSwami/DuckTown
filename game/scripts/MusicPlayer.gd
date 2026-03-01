# Preloading is more efficient for a single main theme
var main_theme = preload("res://assets/audio/Duck_Town_Music.mp3")

func _ready():
    # Assuming you have an AudioStreamPlayer node named 'MusicPlayer'
    $MusicPlayer.stream = main_theme
    $MusicPlayer.play()