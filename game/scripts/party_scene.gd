extends Node
# party_scene.gd - Party scene host for PartyCutsceneOverlay.

@onready var party_overlay: CanvasLayer = $PartyCutsceneOverlay

func _ready() -> void:
	print("[PartyScene] Ready")
	if party_overlay == null:
		push_error("[PartyScene] Missing PartyCutsceneOverlay node.")
		return
	print("[PartyScene] PartyCutsceneOverlay present; cutscene starts from overlay _ready()")
