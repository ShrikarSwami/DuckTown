extends PanelContainer
# Progress Tracker - Shows approval status with red/green text

const VERBOSE_DEBUG := false
const QUEST_MANAGER_PATH := "QuestManager"
const UI_APPROVAL_LOG_META_KEY := "ui_prep_green_logs"

var _quest_manager: Node
var _baker_label: Label
var _merch_label: Label
var _guard_label: Label

# Color codes - using exact Color8 values from spec
const RED := Color8(255, 80, 80)        # Not approved
const GREEN := Color8(80, 255, 120)     # Approved

# Track previous state for flip detection and logging
var _prev_baker_ok: bool = false
var _prev_merch_ok: bool = false
var _prev_mean_guard_ok: bool = false

func _ready():
	# Find the approval status labels
	var task_list = $MarginContainer/VBoxContainer/TaskList
	_baker_label = task_list.get_node("BakerLabel")
	_merch_label = task_list.get_node("MerchLabel")
	_guard_label = task_list.get_node("GuardLabel")
	
	# Ensure default rendering is explicit while waiting for QuestManager.
	_update_display(false, false, false)
	call_deferred("_bind_or_retry_quest_manager")

func _has_logged_approval_ui(npc_id: String) -> bool:
	var root = get_tree().root
	if root == null or not root.has_meta(UI_APPROVAL_LOG_META_KEY):
		return false

	var flags_variant = root.get_meta(UI_APPROVAL_LOG_META_KEY)
	if typeof(flags_variant) != TYPE_DICTIONARY:
		return false

	var flags: Dictionary = flags_variant
	return bool(flags.get(npc_id, false))

func _mark_logged_approval_ui(npc_id: String) -> void:
	var root = get_tree().root
	if root == null:
		return

	var flags: Dictionary = {}
	if root.has_meta(UI_APPROVAL_LOG_META_KEY):
		var flags_variant = root.get_meta(UI_APPROVAL_LOG_META_KEY)
		if typeof(flags_variant) == TYPE_DICTIONARY:
			flags = (flags_variant as Dictionary).duplicate(true)

	flags[npc_id] = true
	root.set_meta(UI_APPROVAL_LOG_META_KEY, flags)

func _bind_or_retry_quest_manager() -> void:
	if _quest_manager == null:
		var current_scene = get_tree().get_current_scene()
		if current_scene:
			_quest_manager = current_scene.get_node_or_null(QUEST_MANAGER_PATH)

	if _quest_manager == null:
		if VERBOSE_DEBUG:
			print("[ProgressTracker] QuestManager not ready yet, retrying...")
		await get_tree().process_frame
		call_deferred("_bind_or_retry_quest_manager")
		return

	if VERBOSE_DEBUG:
		print("[ProgressTracker] Found QuestManager: %s" % _quest_manager)

	if _quest_manager.has_signal("approvals_changed") and not _quest_manager.approvals_changed.is_connected(_on_approvals_changed):
		_quest_manager.approvals_changed.connect(_on_approvals_changed)
		if VERBOSE_DEBUG:
			print("[ProgressTracker] Connected to approvals_changed signal")

	if _quest_manager.has_signal("approvals_updated") and not _quest_manager.approvals_updated.is_connected(_on_approvals_updated):
		_quest_manager.approvals_updated.connect(_on_approvals_updated)
		if VERBOSE_DEBUG:
			print("[ProgressTracker] Connected to approvals_updated signal")

	_initialize_display()

func _initialize_display():
	"""Initialize display with current approval state"""
	if not _quest_manager:
		return
	
	var baker_ok: bool = _get_approval_bool("baker")
	var merch_ok: bool = _get_approval_bool("merch")
	var mean_guard_ok: bool = _get_approval_bool("meanGuard")
	
	_update_display(baker_ok, merch_ok, mean_guard_ok)

func _get_approval_bool(npc_id: String) -> bool:
	"""Get approval status from QuestManager - ONLY uses stored booleans"""
	if _quest_manager == null:
		return false

	# Use the is_approved method which reads from the boolean dictionary
	if _quest_manager.has_method("is_approved"):
		return bool(_quest_manager.call("is_approved", npc_id))

	# Fallback: directly read the approvals dictionary
	var approvals_variant = _quest_manager.get("approvals")
	if typeof(approvals_variant) != TYPE_DICTIONARY:
		return false

	var approvals: Dictionary = approvals_variant
	# Now approvals is a simple bool dictionary, not Approval objects
	return bool(approvals.get(npc_id, false))

func _on_approvals_updated(baker_ok: bool, merch_ok: bool, mean_guard_ok: bool, approvals_count: int):
	"""Called when approvals are updated - receive state directly from QuestManager"""
	_update_display(baker_ok, merch_ok, mean_guard_ok)

func _update_display(baker_ok: bool, merch_ok: bool, mean_guard_ok: bool):
	"""Update approval labels with red/green colors"""
	# Update label colors based on approval states
	_baker_label.add_theme_color_override("font_color", GREEN if baker_ok else RED)
	_merch_label.add_theme_color_override("font_color", GREEN if merch_ok else RED)
	_guard_label.add_theme_color_override("font_color", GREEN if mean_guard_ok else RED)

	# Required one-time UI logs when line turns green.
	if baker_ok and not _has_logged_approval_ui("baker"):
		print("[UI] baker approved -> prep line green")
		_mark_logged_approval_ui("baker")
	if merch_ok and not _has_logged_approval_ui("merch"):
		print("[UI] merch approved -> prep line green")
		_mark_logged_approval_ui("merch")
	if mean_guard_ok and not _has_logged_approval_ui("meanGuard"):
		print("[UI] meanGuard approved -> prep line green")
		_mark_logged_approval_ui("meanGuard")
	
	# Update previous state
	_prev_baker_ok = baker_ok
	_prev_merch_ok = merch_ok
	_prev_mean_guard_ok = mean_guard_ok
	
	if VERBOSE_DEBUG:
		print("[ProgressTracker] approvals baker=%s merch=%s meanGuard=%s" % [baker_ok, merch_ok, mean_guard_ok])

func _on_approvals_changed(npc_id: String, approved: bool):
	"""Called when a specific approval changes - update UI live"""
	match npc_id:
		"baker":
			_update_display(approved, _prev_merch_ok, _prev_mean_guard_ok)
		"merch":
			_update_display(_prev_baker_ok, approved, _prev_mean_guard_ok)
		"meanGuard":
			_update_display(_prev_baker_ok, _prev_merch_ok, approved)
		_:
			_initialize_display()

	if VERBOSE_DEBUG:
		print("[ProgressTracker] Live update: %s = %s" % [npc_id, "green" if approved else "red"])
