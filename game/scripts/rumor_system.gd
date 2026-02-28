extends Node
# Rumor system - tracks rumor generation, propagation, and decay

# TODO: Implement rumor tracking and spreading

class Rumor:
    var id: String
    var text: String
    var tags: Array[String]
    var origin_npc: String
    var believer_npcs: Array[String]
    var confidence: float = 1.0
    var created_at: int
    var spread_factor: float = 0.5
    
    func _init(p_id: String, p_text: String, p_origin: String):
        id = p_id
        text = p_text
        origin_npc = p_origin
        created_at = Time.get_ticks_msec()
        believer_npcs = [p_origin]

var rumors: Dictionary = {}  # rumors[rumor_id] = Rumor
var npc_rumors: Dictionary = {}  # npc_rumors[npc_id] = [rumor_ids]

func _ready():
    # TODO: Load initial rumors from game state
    pass

func _process(delta):
    # TODO: Handle rumor decay and propagation over time
    # Every few seconds:
    # - Decrease confidence of old rumors
    # - Propagate rumors to nearby NPCs
    # - Mark rumors that have spread far enough as "town knowledge"
    pass

func add_rumor(rumor_id: String, rumor_text: String, origin_npc: String, tags: Array[String] = []):
    # TODO: Create new rumor
    var new_rumor = Rumor.new(rumor_id, rumor_text, origin_npc)
    new_rumor.tags = tags
    
    rumors[rumor_id] = new_rumor
    
    if not npc_rumors.has(origin_npc):
        npc_rumors[origin_npc] = []
    
    if rumor_id not in npc_rumors[origin_npc]:
        npc_rumors[origin_npc].append(rumor_id)
    
    print("New rumor %s from %s: %s" % [rumor_id, origin_npc, rumor_text])

func propagate_rumor(rumor_id: String, source_npc: String, target_npc: String):
    # TODO: Spread rumor from one NPC to another
    # - Check NPC relationship/personality to see if they spread it
    # - Degrade confidence (add noise to the rumor)
    # - Track which NPCs know the rumor
    
    if not rumors.has(rumor_id):
        print("Rumor %s not found" % rumor_id)
        return
    
    var rumor = rumors[rumor_id]
    
    # Mark target as believer if not already
    if target_npc not in rumor.believer_npcs:
        rumor.believer_npcs.append(target_npc)
        
        if not npc_rumors.has(target_npc):
            npc_rumors[target_npc] = []
        
        npc_rumors[target_npc].append(rumor_id)
        print("%s learned rumor %s from %s" % [target_npc, rumor_id, source_npc])

func degrade_rumor(rumor_id: String):
    # TODO: Add slight variations/noise to rumor text
    # Over time, rumor changes depending on NPCs talking about it
    
    if rumors.has(rumor_id):
        var rumor = rumors[rumor_id]
        rumor.confidence *= 0.95  # Confidence decreases over time
        
        if rumor.confidence < 0.1:
            # Rumor forgotten
            print("Rumor %s faded away" % rumor_id)

func get_npc_rumors(npc_id: String) -> Array[String]:
    # TODO: Return list of rumor IDs known by this NPC
    if npc_rumors.has(npc_id):
        return npc_rumors[npc_id]
    return []

func get_rumor_text(rumor_id: String) -> String:
    # TODO: Get the current text of a rumor (may be degraded)
    if rumors.has(rumor_id):
        return rumors[rumor_id].text
    return ""

func is_rumor_about(rumor_id: String, npc_id: String) -> bool:
    # TODO: Check if rumor is about a specific NPC
    # (depends on tags and content matching)
    if rumors.has(rumor_id):
        # For now, check if NPC name is in tags
        return npc_id in rumors[rumor_id].tags
    return false

func clear_rumor(rumor_id: String):
    # TODO: Remove rumor from all NPCs and rumor dict
    if rumors.has(rumor_id):
        for npc_id in npc_rumors.keys():
            if rumor_id in npc_rumors[npc_id]:
                npc_rumors[npc_id].erase(rumor_id)
        rumors.erase(rumor_id)
        print("Rumor %s cleared" % rumor_id)

func get_all_rumors() -> Dictionary:
    # TODO: Return all active rumors for debugging/UI
    return rumors.duplicate()

# TODO: Implement these methods
# - get_rumor_confidence(rumor_id) -> float
#   Returns how confident NPCs are about this rumor
#
# - has_rumor_topic(topic: String) -> bool
#   Check if any rumors have a specific tag
#
# - get_rumors_by_target(npc_id: String) -> Array[String]
#   Get all rumors about a specific NPC
#
# - rumor_transforms_text(original: String) -> String
#   Apply degradation/noise to rumor text over time
