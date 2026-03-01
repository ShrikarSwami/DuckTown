extends PanelContainer
# Progress Tracker - Shows task completion and progress bar

const VERBOSE_DEBUG := false

var _quest_manager: Node
var _progress_bar: ProgressBar
var _task_checkboxes: Array[Label] = []

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
	
	# Find UI elements
	_progress_bar = $MarginContainer/VBoxContainer/ProgressBar
	_progress_bar.max_value = 3  # 0-3 approvals
	
	# Find task checkboxes
	var task_list = $MarginContainer/VBoxContainer/TaskList
	_task_checkboxes.append(task_list.get_node("Task1/CheckBox"))
	_task_checkboxes.append(task_list.get_node("Task2/CheckBox"))
	_task_checkboxes.append(task_list.get_node("Task3/CheckBox"))
	
	# Connect to new approvals_updated signal
	if not _quest_manager.approvals_updated.is_connected(_on_approvals_updated):
		_quest_manager.approvals_updated.connect(_on_approvals_updated)
		if VERBOSE_DEBUG:
			print("[ProgressTracker] Connected to approvals_updated signal")
	else:
		if VERBOSE_DEBUG:
			print("[ProgressTracker] Already connected to approvals_updated signal")
	
	# Load initial approval state
	call_deferred("_initialize_display")

func _initialize_display():
	"""Initialize display with current approval state"""
	if not _quest_manager:
		return
	
	var approvals = _quest_manager.get_all_approvals()
	var baker_ok = approvals["baker"].is_approved
	var merch_ok = approvals["merch"].is_approved
	var mean_guard_ok = approvals["meanGuard"].is_approved
	var count = _quest_manager.get_approval_progress()
	
	_update_display(baker_ok, merch_ok, mean_guard_ok, count)

func _on_approvals_updated(baker_ok: bool, merch_ok: bool, mean_guard_ok: bool, approvals_count: int):
	"""Called when approvals are updated - receive state directly from QuestManager"""
	_update_display(baker_ok, merch_ok, mean_guard_ok, approvals_count)

func _update_display(baker_ok: bool, merch_ok: bool, mean_guard_ok: bool, approvals_count: int):
	"""Update the progress bar and checkboxes with current approval states"""
	if not _quest_manager:
		if VERBOSE_DEBUG:
			print("[ProgressTracker] Cannot update: _quest_manager is null")
		return
	
	# Update checkboxes based on approval states
	var approval_states = [baker_ok, merch_ok, mean_guard_ok]
	for i in range(approval_states.size()):
		if i < _task_checkboxes.size():
			var checkbox = _task_checkboxes[i]
			if approval_states[i]:
				checkbox.text = "☑"
				checkbox.modulate = Color(0.4, 1.0, 0.4)
			else:
				checkbox.text = "☐"
				checkbox.modulate = Color(1.0, 1.0, 1.0)
	
	# Update progress bar value
	if _progress_bar:
		_progress_bar.value = approvals_count
	
	# Verification logs
	if VERBOSE_DEBUG:
		print("[ProgressTracker] approvals baker=%s merch=%s meanGuard=%s count=%d" % [baker_ok, merch_ok, mean_guard_ok, approvals_count])
	
	# Color code the progress bar
	if approvals_count == 3:
		_progress_bar.modulate = Color(0.4, 1.0, 0.4)  # Green
	elif approvals_count >= 1:
		_progress_bar.modulate = Color(1.0, 0.9, 0.4)  # Yellow
	else:
		_progress_bar.modulate = Color(1.0, 1.0, 1.0)  # White
