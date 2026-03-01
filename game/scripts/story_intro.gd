extends Control
# Story intro with scrolling text and player name capture

@onready var story_scroll: RichTextLabel = $Margin/VBox/StoryWindow/StoryScroll
@onready var name_input: LineEdit = $Margin/VBox/NameInput

var _scroll_speed: float = 24.0

func _ready():
	name_input.grab_focus()
	_refresh_story_text("...")
	print("[StoryIntro] Ready")

func _process(delta: float) -> void:
	if story_scroll == null:
		return
	var scroll_bar = story_scroll.get_v_scroll_bar()
	if scroll_bar:
		scroll_bar.value += _scroll_speed * delta

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_continue_button_pressed()

func _on_name_input_text_submitted(_new_text: String) -> void:
	_on_continue_button_pressed()

func _on_continue_button_pressed() -> void:
	var entered_name := name_input.text.strip_edges()
	if entered_name.is_empty():
		entered_name = "Alex"
	
	get_tree().root.set_meta("player_name", entered_name)
	print("[StoryIntro] Player name set: %s" % entered_name)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _refresh_story_text(player_name: String) -> void:
	story_scroll.text = "\n".join([
		"[center]YOU ARE A RESIDENT OF DUCK TOWN NAMED %s.[/center]" % player_name,
		"",
		"[center]YOUR MAYOR IS A LOVABLE CLUTZ, AND THE BIG DUCK PARTY IS COMING FAST.[/center]",
		"",
		"[center]YOUR JOB: HELP SET UP THE PARTY BY COMPLETING TASKS,[/center]",
		"[center]TALKING TO CITIZENS, AND BUILDING TRUST.[/center]",
		"",
		"[center]KEY PEOPLE THIS DEMO: BAKER, MERCH GUY, MUSICIAN.[/center]",
		"",
		"[center]IN FUTURE DEMOS, THESE TARGET CITIZENS CAN CHANGE DYNAMICALLY.[/center]",
		"",
		"[center]USE GEMINI-POWERED DIALOGUE TO ADAPT CONVERSATIONS,[/center]",
		"[center]SPREAD RUMORS, AND UNLOCK APPROVALS FASTER.[/center]",
		"",
		"[center]TYPE YOUR NAME BELOW, THEN PRESS CONTINUE.[/center]",
		"",
		"[center]----------------------------------------------[/center]",
		"",
		"[center]GOOD LUCK, RESIDENT.[/center]"
	])
