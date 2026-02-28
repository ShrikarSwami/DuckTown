extends Node
# Quest manager - tracks quests, objectives, and rewards

# TODO: Implement quest tracking system

class Quest:
    var quest_id: String
    var title: String
    var description: String
    var giver_npc: String
    var is_active: bool = false
    var is_completed: bool = false
    var progress: int = 0  # 0-100
    var objectives: Array[String] = []
    var current_objective_index: int = 0
    var reward: Dictionary = {}
    
    func _init(p_id: String, p_title: String, p_giver: String):
        quest_id = p_id
        title = p_title
        giver_npc = p_giver

var quests: Dictionary = {}  # quests[quest_id] = Quest
var active_quests: Array[String] = []
var completed_quests: Array[String] = []

signal quest_started(quest_id: String)
signal quest_updated(quest_id: String, progress: int)
signal quest_completed(quest_id: String, reward: Dictionary)

func _ready():
    # TODO: Load quests from game data / NPC profiles
    pass

func _process(delta):
    # TODO: Check for quest completion conditions
    pass

func create_quest(quest_id: String, title: String, giver_npc: String) -> Quest:
    # TODO: Create a new quest
    var new_quest = Quest.new(quest_id, title, giver_npc)
    quests[quest_id] = new_quest
    print("Quest created: %s" % title)
    return new_quest

func start_quest(quest_id: String):
    # TODO: Activate a quest
    if quests.has(quest_id):
        quests[quest_id].is_active = true
        active_quests.append(quest_id)
        quest_started.emit(quest_id)
        print("Quest started: %s" % quests[quest_id].title)

func update_quest_progress(quest_id: String, progress_delta: int):
    # TODO: Update quest progress
    if quests.has(quest_id):
        var quest = quests[quest_id]
        quest.progress = clampi(quest.progress + progress_delta, 0, 100)
        quest_updated.emit(quest_id, quest.progress)
        print("Quest %s progress: %d%%" % [quest.title, quest.progress])
        
        # Check if completed
        if quest.progress >= 100:
            complete_quest(quest_id)

func advance_objective(quest_id: String):
    # TODO: Move to next objective in a quest
    if quests.has(quest_id):
        var quest = quests[quest_id]
        if quest.current_objective_index < quest.objectives.size() - 1:
            quest.current_objective_index += 1
            print("Objective advanced in quest %s" % quest.title)

func complete_quest(quest_id: String):
    # TODO: Mark quest as complete and award rewards
    if quests.has(quest_id):
        var quest = quests[quest_id]
        quest.is_completed = true
        active_quests.erase(quest_id)
        completed_quests.append(quest_id)
        
        # TODO: Award relationship bonus to giver NPC
        # TODO: Award items/rewards
        
        quest_completed.emit(quest_id, quest.reward)
        print("Quest completed: %s" % quest.title)

func get_quest(quest_id: String) -> Quest:
    # TODO: Get quest object
    if quests.has(quest_id):
        return quests[quest_id]
    return null

func get_active_quests() -> Array[String]:
    # TODO: Return list of active quest IDs
    return active_quests.duplicate()

func get_npc_quests(npc_id: String) -> Array[String]:
    # TODO: Get all quests from a specific NPC
    var npc_quests: Array[String] = []
    for quest_id in quests.keys():
        if quests[quest_id].giver_npc == npc_id:
            npc_quests.append(quest_id)
    return npc_quests

func is_quest_active(quest_id: String) -> bool:
    # TODO: Check if a quest is currently active
    return quest_id in active_quests

func is_quest_completed(quest_id: String) -> bool:
    # TODO: Check if a quest is completed
    return quest_id in completed_quests

func get_quest_progress(quest_id: String) -> int:
    # TODO: Get current progress of a quest (0-100)
    if quests.has(quest_id):
        return quests[quest_id].progress
    return 0

func abandon_quest(quest_id: String):
    # TODO: Option to cancel an active quest
    if quests.has(quest_id):
        var quest = quests[quest_id]
        quest.is_active = false
        active_quests.erase(quest_id)
        print("Quest abandoned: %s" % quest.title)

# TODO: Implement these methods
# - link_quest_to_dialogue(quest_id: String, npc_id: String, dialogue_trigger: String)
#   Trigger quest progress when player says something specific
#
# - get_current_objective(quest_id: String) -> String
#   Display current quest objective to player
#
# - save_quest_state() -> Dictionary
#   Serialize all quest progress for persistence
#
# - load_quest_state(state: Dictionary)
#   Restore quest progress from save file
