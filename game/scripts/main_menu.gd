extends Control
# Main Menu - Entry point for the game

func _ready():
	# Focus the play button for keyboard/controller support
	var play_button = $MenuMargins/CenterContainer/MenuCard/CardMargin/VBoxContainer/PlayButton
	if play_button:
		play_button.grab_focus()
	
	print("[MainMenu] Ready")

func _on_play_button_pressed():
	print("[MainMenu] Play button pressed - loading story intro")
	get_tree().change_scene_to_file("res://scenes/StoryIntro.tscn")

func _on_quit_button_pressed():
	print("[MainMenu] Quit button pressed")
	get_tree().quit()
