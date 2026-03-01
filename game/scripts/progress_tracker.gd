extends PanelContainer
# Progress Tracker - Shows task completion and progress bar

var _quest_manager: Node
var _progress_bar: ProgressBar
var _task_checkboxes: Array[Label] = []

func _ready():
	# Find quest manager
	_quest_manager = get_tree().root.get_node_or_null("Main/QuestManager")
	
	# Find UI elements
	_progress_bar = $MarginContainer/VBoxContainer/ProgressBar
	
	# Find task checkboxes
	var task_list = $MarginContainer/VBoxContainer/TaskList
	_task_checkboxes.append(task_list.get_node("Task1/CheckBox"))
	_task_checkboxes.append(task_list.get_node("Task2/CheckBox"))
	_task_checkboxes.append(task_list.get_node("Task3/CheckBox"))
	
	# Connect to quest manager signals
	if _quest_manager:
		_quest_manager.approval_changed.connect(_on_approval_changed)
		print("[ProgressTracker] Connected to QuestManager")
	
	# Initial update
	call_deferred("_update_display")

func _on_approval_changed(npc_id: String, is_approved: bool):
	"""Called when an approval status changes"""
	_update_display()

func _update_display():
	"""Update the progress bar and checkboxes"""
	if not _quest_manager:
		return
	
	var approvals = _quest_manager.get_all_approvals()
	var completed = 0
	
	# Map NPC IDs to task indices
	var npc_to_task = {
		"baker": 0,
		"merch": 1,
		"guard": 2
	}
	
	# Update checkboxes
	for npc_id in npc_to_task.keys():
		if npc_id in approvals:
			var approval = approvals[npc_id]
			var task_idx = npc_to_task[npc_id]
			
			if task_idx < _task_checkboxes.size():
				var checkbox = _task_checkboxes[task_idx]
				if approval.is_approved:
					checkbox.text = "☑"
					checkbox.modulate = Color(0.4, 1.0, 0.4)
					completed += 1
				else:
					checkbox.text = "☐"
					checkbox.modulate = Color(1.0, 1.0, 1.0)
	
	# Update progress bar
	if _progress_bar:
		_progress_bar.value = completed
		
		# Color code the progress bar
		if completed == 3:
			_progress_bar.modulate = Color(0.4, 1.0, 0.4)  # Green
		elif completed >= 1:
			_progress_bar.modulate = Color(1.0, 0.9, 0.4)  # Yellow
		else:
			_progress_bar.modulate = Color(1.0, 1.0, 1.0)  # White

func _process(_delta):
	# Update every frame to catch changes
	if visible and _quest_manager:
		_update_display()
