# Duck Party Rumor Game - Godot Project

This is the Godot 4 game project for Duck Party Rumor Game.

## Getting Started

### Prerequisites
- Godot 4.x (download from [godotengine.org](https://godotengine.org))

### Opening the Project
1. Open Godot
2. Click "Import" and select this directory (`game/`)
3. Click "Import & Edit"

### Running the Game
- Press **F5** to run in the editor
- Or click the Play button (►) in the top-right toolbar
- Press **F8** to run the current scene

### Folder Structure

```
├── scenes/              # .tscn scene files
│   ├── Main.tscn       # Main game scene
│   ├── Player.tscn     # Player character scene
│   ├── NPC.tscn        # NPC template scene
│   └── UI.tscn         # UI manager scene
├── scripts/            # .gd GDScript files
│   ├── player_controller.gd
│   ├── npc_interaction.gd
│   ├── rumor_system.gd
│   ├── quest_manager.gd
│   └── gemini_client.gd
└── assets/
    ├── sprites/        # Character and tileset sprites
    ├── ui/             # UI element sprites
    └── tiles/          # Tileset definitions
```

## Development Workflow

### Creating a New Scene
1. **Scene** → **New Scene**
2. Add root node (e.g., `Node2D` for game world, `Control` for UI)
3. Save as `.tscn` file in `/scenes/` folder
4. Name: `MySceneName.tscn`

### Creating a New Script
1. Right-click in FileSystem → **New Script**
2. Language: **GDScript**
3. Path: `/scripts/my_script.gd`
4. Attach to node via Inspector (Attach Script button)

### Script Template
```gdscript
extends Node2D
# TODO: Implement core logic here

func _ready():
    # Called when scene enters tree
    pass

func _process(delta):
    # Called every frame
    pass
```

## Key Systems (Placeholders)

### Player Controller (`player_controller.gd`)
- Handles WASD/arrow input
- Movement speed
- Animation state
- Collision detection
- TODO: Implement player movement logic

### NPC Interaction (`npc_interaction.gd`)
- Detects proximity to NPCs
- Dialogue UI display
- Gemini API integration
- TODO: Wire up to Gemini backend

### Rumor System (`rumor_system.gd`)
- Tracks known rumors
- Propagates rumors between NPCs
- Applies relationship deltas
- TODO: Implement rumor persistence

### Quest Manager (`quest_manager.gd`)
- Tracks active quests
- Updates quest progress
- Handles quest rewards
- TODO: Link quest triggers to NPC dialogue

### Gemini Client (`gemini_client.gd`)
- HTTP requests to backend
- JSON parsing
- Response caching (optional)
- TODO: Implement async HTTP calls

## Asset Guidelines

See `/docs/art_pipeline.md` for sprite guidelines:
- **Player sprite:** 24×24 pixels, 4-directional
- **NPC sprites:** 24×24 pixels, distinct colors
- **Tileset:** 24×24 pixel grid
- **UI:** Scale-independent (use Control nodes)

## Godot Tips

### Debugging
- Use `print()` for console output
- Press **Ctrl+B** to open the Debug tab
- Inspect node states in Remote tab during play

### Performance
- Use `@onready` for node references
- Cache frequently accessed nodes
- Use `Sprite2D` + `CollisionShape2D` for characters
- Use `TileMap` for terrain

### Signals
Custom events (recommended for decoupled systems):
```gdscript
# Define signal in script
signal dialogue_started(npc_id)

# Emit it:
dialogue_started.emit("alice")

# Listen to it:
dialogue_started.connect(_on_dialogue_started)
```

## Testing Checklist

- [ ] Game window opens without errors
- [ ] Player moves with WASD
- [ ] NPC sprites visible
- [ ] Camera follows player
- [ ] Dialogue UI displays on NPC interaction
- [ ] Gemini API returns valid response
- [ ] Relationship scores update correctly

## Known Issues

*(Will be filled as issues are discovered)*

- TODO: Add placeholder issues or remove this section

## Next Steps

1. Import Godot 4 and open this project
2. Check `project.godot` for engine settings
3. Review `/docs/architecture.md` for system overview
4. Start with implementing player movement in `player_controller.gd`
5. Test scene by pressing F5

For questions, check the main `/README.md` or ask in team Slack.
