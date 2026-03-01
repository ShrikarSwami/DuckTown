extends Node2D
# Party scene - celebration when all approvals are obtained

const VERBOSE_DEBUG := false

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const VICTORY_VIDEO_PATH := "res://assets/Video/Party.webm"
const VICTORY_AUDIO_PATH := "res://assets/Audio/Party.wav"
const PARTY_VIDEO_CACHE_KEY := "party_video_stream"
const PARTY_AUDIO_CACHE_KEY := "party_audio_stream"
const PRE_VIDEO_FADE_DURATION := 0.5
const POST_VIDEO_FADE_DURATION := 0.2

@onready var celebration: Control = $Celebration
@onready var video_overlay: Control = $VideoOverlay
@onready var video_player: VideoStreamPlayer = $VideoOverlay/VictoryVideo
@onready var party_audio: AudioStreamPlayer = $VideoOverlay/PartyAudio
@onready var fade_overlay: ColorRect = $FadeOverlay

var _restart_started: bool = false

func _ready():
	print("🎉 PARTY SCENE LOADED!")
	if fade_overlay != null:
		fade_overlay.color = Color(0, 0, 0, 0)
		fade_overlay.show()

	if not await _fade_then_play_victory_video():
		print("[PartyScene] Falling back to timed restart")
		await get_tree().create_timer(3.0).timeout
		_restart_demo()


func _fade_then_play_victory_video() -> bool:
	if fade_overlay != null:
		if VERBOSE_DEBUG:
			print("[PartyScene] Fade start")
		var fade_tween := create_tween()
		fade_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		fade_tween.tween_property(fade_overlay, "color", Color(0, 0, 0, 1), PRE_VIDEO_FADE_DURATION)
		await fade_tween.finished

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
	if video_player == null or video_overlay == null or party_audio == null:
		push_warning("[PartyScene] Video player nodes missing")
		return false

	var root = get_tree().root
	var video_stream: VideoStream = null
	var audio_stream: AudioStream = null
	var used_cached_video := false
	var used_cached_audio := false

	if root.has_meta(PARTY_VIDEO_CACHE_KEY):
		video_stream = root.get_meta(PARTY_VIDEO_CACHE_KEY) as VideoStream
		used_cached_video = video_stream != null
	if root.has_meta(PARTY_AUDIO_CACHE_KEY):
		audio_stream = root.get_meta(PARTY_AUDIO_CACHE_KEY) as AudioStream
		used_cached_audio = audio_stream != null

	if video_stream == null:
		video_stream = load(VICTORY_VIDEO_PATH) as VideoStream
		if video_stream != null:
			root.set_meta(PARTY_VIDEO_CACHE_KEY, video_stream)
	if audio_stream == null:
		audio_stream = load(VICTORY_AUDIO_PATH) as AudioStream
		if audio_stream != null:
			root.set_meta(PARTY_AUDIO_CACHE_KEY, audio_stream)

	if VERBOSE_DEBUG:
		print("[PartyScene] Media source - video: %s, audio: %s" % ["cache" if used_cached_video else "fallback_load", "cache" if used_cached_audio else "fallback_load"])

	if video_stream == null:
		push_warning("[PartyScene] Could not load video: %s" % VICTORY_VIDEO_PATH)
		return false
	if audio_stream == null:
		push_warning("[PartyScene] Could not load audio: %s" % VICTORY_AUDIO_PATH)
		return false

	if celebration != null:
		celebration.hide()

	video_overlay.show()
	video_player.stream = video_stream
	party_audio.stream = audio_stream
	video_player.expand = true

	if not video_player.finished.is_connected(_on_video_finished):
		video_player.finished.connect(_on_video_finished, CONNECT_ONE_SHOT)

	party_audio.play()
	video_player.play()
	print("[PartyScene] ✓ Video and audio playing")
	print("[VERIFY] VIDEO START")

	# Watchdog: if finished signal never arrives, still restart.
	var watchdog := get_tree().create_timer(30.0)
	watchdog.timeout.connect(func() -> void:
		if not _restart_started:
			if VERBOSE_DEBUG:
				print("[PartyScene] Video watchdog timeout, forcing restart")
			if party_audio.playing:
				party_audio.stop()
			_restart_demo()
	, CONNECT_ONE_SHOT)

	return true


func _on_video_finished() -> void:
	print("[PartyScene] Video finished")
	print("[VERIFY] VIDEO FINISH")
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
