extends CanvasLayer

const PARTY_VIDEO_PATH := "res://assets/video/Party.ogv"
const WATCHDOG_SECONDS := 2.0

@onready var video_player: VideoStreamPlayer = $Background/VideoPlayer
@onready var debug_label: Label = $DebugLabel

var _playback_finished_callback: Callable = Callable()
var _finish_handled: bool = false
var _play_requested: bool = false
var _loaded_stream: Resource = null

func _ready() -> void:
	# Default behavior: return to MainMenu after cutscene.
	_playback_finished_callback = func():
		_return_to_main_menu_once()

	if video_player == null:
		push_error("[PartyCutsceneOverlay] Missing VideoPlayer node.")
		_show_failure_debug("VideoPlayer node missing")
		_return_to_main_menu_once()
		return

	if video_player.finished.is_connected(_on_video_finished):
		video_player.finished.disconnect(_on_video_finished)
	video_player.finished.connect(_on_video_finished)

	_fit_video_to_viewport()
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)

	# Required startup behavior for Party scene:
	# load OGV stream and start playback immediately.
	_start_playback()

func _on_viewport_size_changed() -> void:
	_fit_video_to_viewport()

func play_and_quit() -> void:
	_playback_finished_callback = func():
		_return_to_main_menu_once()
	if not _play_requested:
		_start_playback()

func play_and_then(callback: Callable) -> void:
	_playback_finished_callback = callback
	if not _play_requested:
		_start_playback()

func _start_playback() -> void:
	if _play_requested:
		return
	_play_requested = true

	_loaded_stream = load(PARTY_VIDEO_PATH)
	video_player.stream = _loaded_stream as VideoStream
	print("[PartyCutsceneOverlay] stream_load path=%s loaded=%s class=%s" % [
		PARTY_VIDEO_PATH,
		video_player.stream != null,
		_loaded_stream.get_class() if _loaded_stream != null else "null"
	])

	if video_player.stream == null:
		push_error("[PartyCutsceneOverlay] Failed to load video stream: %s" % PARTY_VIDEO_PATH)
		_show_failure_debug("Failed to load Party.ogv")
		_return_to_main_menu_once()
		return

	video_player.play()
	print("[PartyCutsceneOverlay] play() called")
	_start_watchdog()

func _start_watchdog() -> void:
	await get_tree().create_timer(WATCHDOG_SECONDS).timeout
	if _finish_handled:
		return

	if not video_player.is_playing():
		var stream_info := "null"
		if _loaded_stream != null:
			stream_info = "%s (%s)" % [_loaded_stream, _loaded_stream.get_class()]
		push_error("[PartyCutsceneOverlay] Watchdog failure: is_playing=false after %.1fs" % WATCHDOG_SECONDS)
		push_error("[PartyCutsceneOverlay] Diagnostics path=%s stream=%s" % [PARTY_VIDEO_PATH, stream_info])
		_show_failure_debug("Video failed to start. stream=%s" % stream_info)
		_return_to_main_menu_once()
	else:
		print("[PartyCutsceneOverlay] Watchdog OK: playback active")

func _on_video_finished() -> void:
	if _finish_handled:
		return
	_finish_handled = true
	print("[PartyCutsceneOverlay] Video finished")
	if _playback_finished_callback.is_valid():
		_playback_finished_callback.call()
	else:
		_return_to_main_menu_once()

func _return_to_main_menu_once() -> void:
	if _finish_handled:
		# If _finish_handled is already true, this may still be called from callback path.
		# Keep transition one-shot by checking current scene.
		pass

	var current_scene = get_tree().get_current_scene()
	if current_scene != null and current_scene.scene_file_path == "res://scenes/MainMenu.tscn":
		return

	_finish_handled = true
	var err := get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	if err != OK:
		push_error("[PartyCutsceneOverlay] Failed to return to MainMenu (err=%d)" % err)

func _show_failure_debug(message: String) -> void:
	if debug_label == null:
		return
	debug_label.text = "[CUTSCENE ERROR] %s" % message
	debug_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
	debug_label.show()

func _fit_video_to_viewport() -> void:
	if video_player == null:
		return

	video_player.anchor_left = 0.0
	video_player.anchor_top = 0.0
	video_player.anchor_right = 1.0
	video_player.anchor_bottom = 1.0
	video_player.offset_left = 0.0
	video_player.offset_top = 0.0
	video_player.offset_right = 0.0
	video_player.offset_bottom = 0.0
	video_player.custom_minimum_size = Vector2.ZERO

	# Godot 4 VideoStreamPlayer uses `expand` (bool), not `expand_mode`.
	if _has_property(video_player, "expand"):
		video_player.set("expand", true)
	var viewport_size := Vector2.ZERO
	var viewport := get_viewport()
	if viewport != null:
		viewport_size = viewport.get_visible_rect().size
	print("[PartyCutsceneOverlay] viewport_fit source=1920x1080 viewport=%s mode=1" % str(viewport_size))

func _has_property(target: Object, property_name: String) -> bool:
	for property_info in target.get_property_list():
		if str(property_info.get("name", "")) == property_name:
			return true
	return false
