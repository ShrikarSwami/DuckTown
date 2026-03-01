extends PanelContainer
# Progress Tracker - Shows approval status with red/green text

const VERBOSE_DEBUG := false

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
	# Find quest manager using reliable current scene access
	var current_scene = get_tree().get_current_scene()
	if current_scene:
		_quest_manager = current_scene.get_node_or_null("QuestManager")
	
	if not _quest_manager:
		push_error("[ProgressTracker] Could not find QuestManager!")
		return
	
	if VERBOSE_DEBUG:
		print("[ProgressTracker] Found QuestManager: %s" % _quest_manager)
	
	# Find the approval status labels
	var task_list = $MarginContainer/VBoxContainer/TaskList
	_baker_label = task_list.get_node("BakerLabel")
	_merch_label = task_list.get_node("MerchLabel")
	_guard_label = task_list.get_node("GuardLabel")
	
	# Connect to approvals_updated signal
	if not _quest_manager.approvals_updated.is_connected(_on_approvals_updated):
		_quest_manager.approvals_updated.connect(_on_approvals_updated)
		if VERBOSE_DEBUG:
			print("[ProgressTracker] Connected to approvals_updated signal")
	
	# Initialize display with current approval state
	call_deferred("_initialize_display")

func _initialize_display():
	"""Initialize display with current approval state"""
	if not _quest_manager:
		return
	
	var approvals = _quest_manager.approvals
	var baker_ok = approvals["baker"].is_approved
	var merch_ok = approvals["merch"].is_approved
	var mean_guard_ok = approvals["meanGuard"].is_approved
	
	_update_display(baker_ok, merch_ok, mean_guard_ok)

func _on_approvals_updated(baker_ok: bool, merch_ok: bool, mean_guard_ok: bool, approvals_count: int):
	"""Called when approvals are updated - receive state directly from QuestManager"""
	_update_display(baker_ok, merch_ok, mean_guard_ok)

func _update_display(baker_ok: bool, merch_ok: bool, mean_guard_ok: bool):
	"""Update approval labels with red/green colors"""
	if not _quest_manager:
		if VERBOSE_DEBUG:
			print("[ProgressTracker] Cannot update: _quest_manager is null")
		return
	
	# Update label colors based on approval states
	_baker_label.add_theme_color_override("font_color", GREEN if baker_ok else RED)
	_merch_label.add_theme_color_override("font_color", GREEN if merch_ok else RED)
	_guard_label.add_theme_color_override("font_color", GREEN if mean_guard_ok else RED)
	
	# Log approval color flips for verification
	if baker_ok and not _prev_baker_ok:
		print("[VERIFY] UI approval color flip: baker -> green")
	if merch_ok and not _prev_merch_ok:
		print("[VERIFY] UI approval color flip: merch -> green")
	if mean_guard_ok and not _prev_mean_guard_ok:
		print("[VERIFY] UI approval color flip: meanGuard -> green")
	
	# Update previous state
	_prev_baker_ok = baker_ok
	_prev_merch_ok = merch_ok
	_prev_mean_guard_ok = mean_guard_ok
	
	if VERBOSE_DEBUG:
		print("[ProgressTracker] approvals baker=%s merch=%s meanGuard=%s" % [baker_ok, merch_ok, mean_guard_ok])

