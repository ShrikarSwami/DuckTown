extends Node
# Rumor system - tracks rumor generation, propagation, and decay

class Rumor:
	var id: String
	var text: String
	var tags: Array[String]
	var origin_npc: String
	var believer_npcs: Array[String]
	var confidence: float = 1.0
	var created_at: int
	var last_spread_to: Array[String] = []
	
	func _init(p_id: String, p_text: String, p_origin: String):
		id = p_id
		text = p_text
		origin_npc = p_origin
		created_at = Time.get_ticks_msec()
		believer_npcs = [p_origin]

var rumors: Dictionary = {}  # rumors[rumor_id] = Rumor
var npc_rumors: Dictionary = {}  # npc_rumors[npc_id] = [rumor_ids]
var all_npcs: Array[Node] = []  # Cache of all NPC nodes

signal rumor_created(rumor_id: String, text: String, origin_npc: String)
signal rumor_spread(rumor_id: String, from_npc: String, to_npc: String)
signal rumor_faded(rumor_id: String)

var _spread_timers: Dictionary = {}  # rumor_id -> timer node

func _ready():
	# Find all NPCs in the scene
	_find_all_npcs()
	print("[RumorSystem] Initialized with %d NPCs" % all_npcs.size())

func _find_all_npcs() -> void:
	"""Scan the scene tree for all NPC nodes"""
	all_npcs.clear()
	for node in get_tree().get_nodes_in_group("npc"):
		all_npcs.append(node)
	print("[RumorSystem] Found %d NPCs" % all_npcs.size())

func _process(delta):
	# Rumors decay over time
	for rumor_id in rumors.keys():
		var rumor = rumors[rumor_id]
		# Every 30 seconds, decrease confidence
		if Time.get_ticks_msec() - rumor.created_at > 30000:
			rumor.confidence *= 0.95
			
			if rumor.confidence < 0.1:
				clear_rumor(rumor_id)

func add_rumor(rumor_id: String, rumor_text: String, origin_npc: String, tags: Array[String] = []):
	"""Create a new rumor and schedule it to spread"""
	var new_rumor = Rumor.new(rumor_id, rumor_text, origin_npc)
	new_rumor.tags = tags
	
	rumors[rumor_id] = new_rumor
	
	if not npc_rumors.has(origin_npc):
		npc_rumors[origin_npc] = []
	
	if rumor_id not in npc_rumors[origin_npc]:
		npc_rumors[origin_npc].append(rumor_id)
	
	rumor_created.emit(rumor_id, rumor_text, origin_npc)
	print("[RumorSystem] Created rumor '%s' from %s" % [rumor_text, origin_npc])
	
	# Schedule spreading to other NPCs after 15-30 seconds
	var delay = randf_range(15.0, 30.0)
	_schedule_rumors_spread(rumor_id, delay)

func _schedule_rumors_spread(rumor_id: String, delay: float) -> void:
	"""Schedule rumor to spread to other NPCs after a delay"""
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = delay
	timer.one_shot = true
	timer.timeout.connect(func(): _spread_rumor_round(rumor_id))
	timer.start()
	
	_spread_timers[rumor_id] = timer
	print("[RumorSystem] Scheduled rumor %s to spread in %.1f seconds" % [rumor_id, delay])

func _spread_rumor_round(rumor_id: String) -> void:
	"""Have NPCs who know this rumor spread it to others"""
	if not rumors.has(rumor_id):
		return
	
	var rumor = rumors[rumor_id]
	print("[RumorSystem] Spreading rumor '%s' (%s know it)" % [rumor.text, rumor.believer_npcs.size()])
	
	# Each believer tries to spread to 1-2 random other NPCs
	for source_npc_id in rumor.believer_npcs:
		if source_npc_id in rumor.last_spread_to:
			continue  # Already spread from this NPC
		
		var spread_count = randi_range(1, 2)
		for i in range(spread_count):
			# Pick random target NPC that doesn't already know
			var target_npc_id = _pick_random_npc_for_rumor(rumor)
			if target_npc_id and target_npc_id != source_npc_id:
				propagate_rumor(rumor_id, source_npc_id, target_npc_id)
				rumor.last_spread_to.append(source_npc_id)

func propagate_rumor(rumor_id: String, source_npc: String, target_npc: String):
	"""Spread rumor from one NPC to another"""
	if not rumors.has(rumor_id):
		print("[RumorSystem] Rumor %s not found" % rumor_id)
		return
	
	var rumor = rumors[rumor_id]
	
	# Mark target as believer if not already
	if target_npc not in rumor.believer_npcs:
		rumor.believer_npcs.append(target_npc)
		
		if not npc_rumors.has(target_npc):
			npc_rumors[target_npc] = []
		
		npc_rumors[target_npc].append(rumor_id)
		
		# Slightly degrade the rumor text (add noise)
		rumor.confidence *= 0.9
		
		print("[RumorSystem] %s learned from %s: '%s'" % [target_npc, source_npc, rumor.text])
		rumor_spread.emit(rumor_id, source_npc, target_npc)
		
		# Trigger target NPC's reaction (if it's an NPC node)
		var target_node = _find_npc_by_id(target_npc)
		if target_node and target_node.has_method("on_rumor_learned"):
			target_node.on_rumor_learned(rumor_id, rumor.text, source_npc)

func _pick_random_npc_for_rumor(rumor: Rumor) -> String:
	"""Pick a random NPC who doesn't already know this rumor"""
	if all_npcs.is_empty():
		_find_all_npcs()
	
	var available_npcs: Array[String] = []
	for npc in all_npcs:
		var npc_id_value = npc.get("npc_id")
		var npc_id = str(npc_id_value) if npc_id_value != null else "unknown"
		if npc_id not in rumor.believer_npcs:
			available_npcs.append(npc_id)
	
	if available_npcs.is_empty():
		return ""
	
	return available_npcs[randi() % available_npcs.size()]

func _find_npc_by_id(npc_id: String) -> Node:
	"""Find NPC node by its npc_id"""
	for npc in all_npcs:
		var value = npc.get("npc_id")
		if value != null and str(value) == npc_id:
			return npc
	return null

func get_npc_rumors(npc_id: String) -> Array[String]:
	"""Return list of rumor IDs known by this NPC"""
	if npc_rumors.has(npc_id):
		return npc_rumors[npc_id]
	return []

func get_rumor_text(rumor_id: String) -> String:
	"""Get the current text of a rumor"""
	if rumors.has(rumor_id):
		return rumors[rumor_id].text
	return ""

func is_rumor_about(rumor_id: String, npc_id: String) -> bool:
	"""Check if rumor is about a specific NPC"""
	if rumors.has(rumor_id):
		return npc_id in rumors[rumor_id].tags
	return false

func clear_rumor(rumor_id: String):
	"""Remove rumor from all NPCs"""
	if rumors.has(rumor_id):
		for npc_id in npc_rumors.keys():
			if rumor_id in npc_rumors[npc_id]:
				npc_rumors[npc_id].erase(rumor_id)
		rumors.erase(rumor_id)
		
		# Cancel any pending spread timer
		if _spread_timers.has(rumor_id):
			_spread_timers[rumor_id].queue_free()
			_spread_timers.erase(rumor_id)
		
		print("[RumorSystem] Rumor %s cleared" % rumor_id)
		rumor_faded.emit(rumor_id)

func get_all_rumors() -> Dictionary:
	"""Return all active rumors for debugging/UI"""
	return rumors.duplicate()

func get_rumors_by_target(target_npc_id: String) -> Array[String]:
	"""Get all rumors about a specific NPC"""
	var result: Array[String] = []
	for rumor_id in rumors.keys():
		if is_rumor_about(rumor_id, target_npc_id):
			result.append(rumor_id)
	return result
