extends Node2D
# Party scene - celebration when all approvals are obtained

const VERBOSE_DEBUG := false

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const PARTY_VIDEO_CACHE_KEY := "party_video_stream"
const PARTY_AUDIO_CACHE_KEY := "party_audio_stream"
const PRE_VIDEO_FADE_DURATION := 0.5
const POST_VIDEO_FADE_DURATION := 0.2
const WATCHDOG_TIMEOUT_SECONDS := 30.0

const VIDEO_CANDIDATE_PATHS: Array[String] = [
	"res://assets/Video/Party.mp4",
	"res://assets/Video/Party.webm"
]
const AUDIO_CANDIDATE_PATHS: Array[String] = [
	"res://assets/Video/Party.wav",
	"res://assets/Audio/Party.wav"
]

@onready var celebration: Control = $Celebration
@onready var video_overlay: Control = $VideoOverlay
@onready var video_player: VideoStreamPlayer = $VideoOverlay/VictoryVideo
@onready var party_audio: AudioStreamPlayer = $VideoOverlay/PartyAudio
@onready var fade_overlay: ColorRect = $FadeOverlay

var _restart_started: bool = false
var _selected_video_path: String = ""
var _selected_audio_path: String = ""
var _play_external_audio: bool = false

func _ready():
	print("="*60)
	print("[PartyScene] 🎉 PARTY SCENE _ready() CALLED")
	
	# Check if triggered by debug shortcut
	var main_node = get_tree().root.get_node_or_null("Main/Main")
	if main_node == null:
		# Try to find Main scene in tree
		for node in get_tree().root.get_children():
			if node.name == "Main" or node.get_script() != null and "main.gd" in str(node.get_script().resource_path).to_lower():
				main_node = node
				break
	if main_node != null and main_node.get("debug_party_triggered") == true:
		print("[PartyScene] ready from debug trigger")
	
	print("[PartyScene] Node tree: overlay=%s video=%s audio=%s fade=%s" % [
		video_overlay != null, video_player != null, party_audio != null, fade_overlay != null
	])
	
	if fade_overlay != null:
		fade_overlay.color = Color(0, 0, 0, 0)
		fade_overlay.show()
		print("[PartyScene] Fade overlay initialized")

	print("[PartyScene] Starting victory video sequence")
	if not await _fade_then_play_victory_video():
		print("[PartyScene] ⚠️ Video playback failed, falling back to timed restart")
		await get_tree().create_timer(3.0).timeout
		_restart_demo()
	else:
		print("[PartyScene] ✅ Victory video playback initiated successfully")


func _fade_then_play_victory_video() -> bool:
	if fade_overlay != null:
		print("[PartyScene] Starting fade to black (%.1fs)" % PRE_VIDEO_FADE_DURATION)
		var fade_tween := create_tween()
		fade_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		fade_tween.tween_property(fade_overlay, "color", Color(0, 0, 0, 1), PRE_VIDEO_FADE_DURATION)
		await fade_tween.finished
		print("[PartyScene] Fade complete, starting video")

	return _play_victory_video()

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


func _play_victory_video() -> bool:
	print("[PartyScene] _play_victory_video() called")
	
	if video_player == null or video_overlay == null or party_audio == null:
		push_error("[PartyScene] ❌ Critical nodes missing: video_player=%s overlay=%s audio=%s" % [
			video_player != null, video_overlay != null, party_audio != null
		])
		return false

	print("[PartyScene] Resolving video/audio paths...")
	_selected_video_path = _resolve_first_existing_path(VIDEO_CANDIDATE_PATHS)
	_selected_audio_path = _resolve_first_existing_path(AUDIO_CANDIDATE_PATHS)

	if _selected_video_path.is_empty():
		push_error("[PartyScene] ❌ Could not find victory video in candidates: %s" % VIDEO_CANDIDATE_PATHS)
		return false
	
	print("[PartyScene] Selected video: %s" % _selected_video_path)

	var root = get_tree().root
	var video_stream: VideoStream = null
	var audio_stream: AudioStream = null

	if root.has_meta(PARTY_VIDEO_CACHE_KEY):
		video_stream = root.get_meta(PARTY_VIDEO_CACHE_KEY) as VideoStream

	if video_stream == null:
		video_stream = load(_selected_video_path) as VideoStream
		if video_stream != null:
			root.set_meta(PARTY_VIDEO_CACHE_KEY, video_stream)

	if video_stream == null:
		push_warning("[PartyScene] Could not load video: %s" % _selected_video_path)
		return false

	_play_external_audio = not _selected_video_path.to_lower().ends_with(".webm")
	if _play_external_audio and not _selected_audio_path.is_empty():
		if root.has_meta(PARTY_AUDIO_CACHE_KEY):
			audio_stream = root.get_meta(PARTY_AUDIO_CACHE_KEY) as AudioStream
		if audio_stream == null:
			audio_stream = load(_selected_audio_path) as AudioStream
			if audio_stream != null:
				root.set_meta(PARTY_AUDIO_CACHE_KEY, audio_stream)

	if _play_external_audio and audio_stream == null:
		push_warning("[PartyScene] Could not load external audio: %s" % _selected_audio_path)
		return false

	if celebration != null:
		celebration.hide()

	video_overlay.show()
	video_player.show()
	video_player.expand = true
	video_player.stream = video_stream

	if _play_external_audio:
		party_audio.stream = audio_stream
	else:
		if party_audio.playing:
			party_audio.stop()
		party_audio.stream = null

	if video_player.finished.is_connected(_on_video_finished):
		video_player.finished.disconnect(_on_video_finished)
	video_player.finished.connect(_on_video_finished, CONNECT_ONE_SHOT)

	print("[PartyScene] Calling video_player.play()...")
	video_player.play()
	print("[PartyScene] ✅ video_player.play() called")
	
	if _play_external_audio:
		print("[PartyScene] Starting external audio")
		party_audio.play()
		print("[PartyScene] ✅ Audio playback started")

	print("[PartyScene] 🎬 VICTORY VIDEO PLAYBACK STARTED")
	print("[PartyScene] Video: %s | External Audio: %s | Audio Path: %s" % [
		_selected_video_path,
		_play_external_audio,
		_selected_audio_path if not _selected_audio_path.is_empty() else "<none>"
	])
	print("="*60)

	_start_finish_watchdog()
	return true


func _resolve_first_existing_path(candidates: Array[String]) -> String:
	for candidate in candidates:
		if ResourceLoader.exists(candidate):
			return candidate
	return ""


func _start_finish_watchdog() -> void:
	var watchdog := get_tree().create_timer(WATCHDOG_TIMEOUT_SECONDS)
	watchdog.timeout.connect(func() -> void:
		if _restart_started:
			return
		if VERBOSE_DEBUG:
			print("[PartyScene] Video watchdog timeout, forcing restart")
		if party_audio != null and party_audio.playing:
			party_audio.stop()
		_restart_demo()
	, CONNECT_ONE_SHOT)


func _on_video_finished() -> void:
	print("[VERIFY] Party video finished -> restarting to Main")
	if party_audio != null and party_audio.playing:
		party_audio.stop()
	if fade_overlay != null:
		fade_overlay.move_to_front()
		fade_overlay.show()
		var fade_tween := create_tween()
		fade_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		fade_tween.tween_property(fade_overlay, "color", Color(0, 0, 0, 1), POST_VIDEO_FADE_DURATION)
		await fade_tween.finished
	_restart_demo()


func _restart_demo() -> void:
	if _restart_started:
		return
	_restart_started = true
	if party_audio != null and party_audio.playing:
		party_audio.stop()
	if video_player != null and video_player.is_playing():
		video_player.stop()

	print("🔄 Restarting demo...")
	print("[VERIFY] RESTARTING MAIN")
	var err := get_tree().change_scene_to_file(MAIN_SCENE_PATH)
	if err != OK:
		print("[PartyScene] ✗ Failed to restart to Main")
		get_tree().reload_current_scene()
	else:
		print("[PartyScene] ✓ Restarted to Main scene")
