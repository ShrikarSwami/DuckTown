extends Node2D
# NPC interaction system - handles dialogue and relationship tracking

# TODO: Implement NPC dialogue and interaction

signal dialogue_started(npc_id: String)
signal dialogue_ended()
signal relationship_changed(npc_id: String, delta: int)

@export var npc_id: String = "unknown"
@export var npc_name: String = "Unknown NPC"
@export var personality_traits: Array[String] = []
@export var initial_relationship: int = 0

var current_relationship: int = 0
var dialogue_history: Array[Dictionary] = []
var known_rumors: Array[String] = []
var gemini_client

func _ready():
    current_relationship = initial_relationship
    gemini_client = get_tree().root.get_node("Main/GeminiClient")
    # TODO: Wire up proximity detection from Player
    # TODO: Connect interaction area signals

func _process(delta):
    # TODO: Check if player is in interaction range
    # TODO: Display "Press E to interact" prompt
    pass

func start_dialogue(player_message: String):
    # TODO: Call Gemini API via backend
    dialogue_started.emit(npc_id)
    
    # TODO: Add to dialogue history
    var player_entry = {
        "role": "player",
        "text": player_message
    }
    dialogue_history.append(player_entry)
    
    # TODO: Call backend /api/gemini endpoint with:
    # - NPC ID and personality
    # - Last few messages from dialogue_history
    # - Player's current relationship score
    # - Known rumors in town
    
    # Example structure:
    # var request_data = {
    #     "npc_id": npc_id,
    #     "npc_name": npc_name,
    #     "npc_personality": build_personality_dict(),
    #     "player_message": player_message,
    #     "player_relationship": current_relationship,
    #     "dialogue_history": dialogue_history.slice(-10),  # Last 10 messages
    #     "known_rumors": known_rumors
    # }
    
    # await gemini_client.call_api(request_data)
    pass

func handle_gemini_response(response: Dictionary):
    # TODO: Parse response and update game state
    # Response fields:
    # - npc_reply: string
    # - rumor: optional dict with text, tags, confidence
    # - relationship_delta: int
    # - quest_progress: optional dict
    # - npc_mood_change: string
    
    if response.get("success", false):
        var npc_reply = response.get("npc_reply", "")
        var rel_delta = response.get("relationship_delta", 0)
        
        # TODO: Display dialogue text in UI
        # TODO: Add to dialogue history
        var npc_entry = {
            "role": "npc",
            "text": npc_reply
        }
        dialogue_history.append(npc_entry)
        
        # TODO: Update relationship
        update_relationship(rel_delta)
        
        # TODO: Handle rumor if present
        if response.has("rumor") and response["rumor"] != null:
            handle_rumor(response["rumor"])
        
        # TODO: Handle quest progress
        if response.has("quest_progress"):
            # Signal quest system to update
            pass
    else:
        # TODO: Handle API error
        var error = response.get("error", "Unknown error")
        print("Gemini API error: ", error)

func update_relationship(delta: int):
    # TODO: Update player's relationship with this NPC
    current_relationship = clampi(current_relationship + delta, -100, 100)
    relationship_changed.emit(npc_id, delta)
    print("%s relationship delta: %d (now %d)" % [npc_name, delta, current_relationship])

func handle_rumor(rumor_data: Dictionary):
    # TODO: Add rumor to NPC's known rumors
    # TODO: Signal rumor system to propagate
    # Rumor fields: text, tags, confidence, rumor_target_npc, suggested_spread_to
    print("New rumor for %s: %s" % [npc_name, rumor_data.get("text", "")])

func build_personality_dict() -> Dictionary:
    # TODO: Build personality object for Gemini prompt
    return {
        "traits": personality_traits,
        "speech_pattern": "TODO: Define",
        "current_mood": "TODO: Define"
    }

func end_dialogue():
    # TODO: Close dialogue UI
    # TODO: Trigger rumor propagation in rumor_system
    dialogue_ended.emit()
