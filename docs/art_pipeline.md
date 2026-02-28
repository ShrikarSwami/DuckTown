# Art Pipeline - Duck Party Rumor Game

## Sprite Guidelines

### Canvas & Scale

- **Grid Size:** 24x24 pixels (primary) or 25x25 pixels (alternative)
- **Target Resolution:** Game runs at 1280×720; sprites upscaled by pixel-perfect scaling
- **Aspect Ratio:** Square (1:1) for character sprites, flexible for scenery

### Character Sprites

#### Player Character
- **Dimensions:** 24×24 pixels
- **Frames:** 4-directional (up, down, left, right)
- **Animation:** 2-4 frames per direction for walking
- **File naming:** `player_walk_down_1.png`, `player_walk_down_2.png`, etc.
- **Style:** Simple, readable silhouette (top-down perspective)
- **Color:**  Distinct primary color (avoid blending with NPCs)

Example structure:
```
player_idle_down.png          (1×1 frame)
player_walk_down_1.png        (walk cycle frame 1)
player_walk_down_2.png        (walk cycle frame 2)
player_walk_up_1.png
...
```

#### NPC Characters
- **Dimensions:** 24×24 pixels base
- **Variations:** At least 3 unique NPCs with distinct silhouettes
- **Idle Pose:** Single frame, facing towards camera
- **Optional Animation:** Idle bob/sway (2-3 frames, subtle)
- **File naming:** `npc_alice_idle.png`, `npc_bob_idle.png`, etc.
- **Color:** Distinct color palette per NPC (red for Alice, blue for Bob, etc.)

### Layered Composition (Base + Overlays)

For efficient animation and customization:

1. **Base Layer:** Body, torso, head (minimal features)
2. **Overlay Layer 1:** Clothing (shirt, pants)
3. **Overlay Layer 2:** Accessories (hat, hair, jewelry)
4. **Overlay Layer 3:** Emotion/Expression (happy mouth, worried eyes)

Example:
```
npc_alice_base.png            (body outline)
npc_alice_clothing_formal.png (business outfit)
npc_alice_hair_long.png       (hair style)
npc_alice_expr_happy.png      (smile, happy eyes)
```

**Godot Integration:**
- Composite layers in a `Sprite2D` node with multiple children
- Each layer is a separate `Sprite2D` with positioned `Texture2D`
- Swap overlay layer textures for outfit/emotion changes without re-rendering

### Tileset & Scenery

- **Tile Size:** 24×24 (matches character scale)
- **Tileset Pack:** One spritesheet image with multiple tiles arranged in a grid
- **Typical Tileset Contents:**
  - Grass/dirt (walkable)
  - Pavement/roads
  - Trees, shrubs
  - Water
  - Buildings (walls, roofs, doors, windows)
  - Props (lamps, benches, vendor carts)

Example layout:
```
tileset_terrain.png (8×8 grid of 24px tiles = 192×192 image)
  [0,0] grass
  [1,0] road_vertical
  [2,0] road_horizontal
  [3,0] tree_dark
  ...
```

### UI Elements

- **Button Size:** 64×32 or 96×48 pixels
- **Font:** Bitmap or vector (TrueType), readable at 12-16pt
- **Icons:** 32×32 or 48×48 (for relationship, quest markers, mood indicators)
- **Color Scheme:** High contrast for accessibility

Example UI assets:
```
ui_button_idle.png            (unpressed state)
ui_button_hover.png           (mouse over)
ui_button_pressed.png         (clicked)
ui_icon_relationship_positive.png
ui_icon_relationship_negative.png
ui_icon_quest_active.png
ui_icon_rumor.png
```

---

## Naming Conventions

### General Rules
- Use lowercase snake_case
- Prefix by category: `player_`, `npc_`, `tileset_`, `ui_`
- Include variant if applicable: `_idle`, `_walk`, `_talk`, `_angry`
- Include direction if needed: `_up`, `_down`, `_left`, `_right`
- Number frames sequentially: `_1`, `_2`, `_3`

### Examples
```
player_idle_down.png
player_walk_up_1.png
npc_charlie_idle.png
npc_charlie_talk_1.png
npc_charlie_mood_angry.png
tileset_terrain.png
tileset_buildings.png
ui_dialogue_box.png
ui_button_interact.png
```

### Spritesheet Organization

For efficiency, combine related sprites into single sheet files:

```
spritesheet_player.png
  Contains: all player idle + walk frames in a grid
  
spritesheet_npc_alice.png
  Contains: alice idle, talk, angry frames
  
spritesheet_ui.png
  Contains: buttons, icons, borders, text boxes
```

**Godot AtlasTexture:**
Use Godot's `AtlasTexture` to define regions within spritesheets:
```gdscript
var atlas = AtlasTexture.new()
atlas.atlas = load("res://assets/sprites/spritesheet_player.png")
atlas.region = Rect2(0, 0, 24, 24)  # Top-left frame
$Sprite2D.texture = atlas
```

---

## Color Palette & Style

### Aesthetic Goal
- **Retro pixel art** (like Game Boy era or early Stardew Valley)
- **Cheerful, quirky tone** (matches "duck party" theme)
- **High readability** (clear silhouettes, good contrast)

### Color Restrictions
- **Palette limit:** 16-32 colors per sprite (encourage efficiency)
- **Distinct NPCs:** Each main NPC should have a unique primary color
  - Alice: Cream/Yellow
  - Bob: Blue
  - Charlie: Green
  - Dave: Red
- **Background:** Neutral greens/browns, no bright neon
- **Accessibility:** Avoid red-green only distinctions (colorblind friendly)

### Dithering & Anti-aliasing
- **Dithering:** Encouraged for gradient effect in limited palette
- **Anti-aliasing:** Avoid (keep edges crisp for pixel art style)
- **Outlines:** Thin 1-pixel dark outlines help readability

---

## Godot Asset Organization

```
game/assets/
├── sprites/
│   ├── player/
│   │   ├── spritesheet_player.png
│   │   └── spritesheet_player.png.import
│   ├── npcs/
│   │   ├── alice_idle.png
│   │   ├── bob_idle.png
│   │   └── ...
│   ├── scenery/
│   │   ├── tileset_terrain.png
│   │   └── tileset_buildings.png
│   └── effects/
│       ├── dialogue_indicator.png
│       └── quest_marker.png
├── ui/
│   ├── dialogue_box.png
│   ├── buttons/
│   │   ├── button_idle.png
│   │   ├── button_hover.png
│   │   └── button_pressed.png
│   ├── icons/
│   │   ├── heart_icon.png
│   │   ├── rumor_icon.png
│   │   └── quest_icon.png
│   └── fonts/
│       ├── default_font.tres   (Godot font resource)
│       └── title_font.tres
└── tiles/
    └── tileset.tres  (Godot TileSet resource)
```

### Import Settings (Godot 4)

For each .png file:
1. **Texture Type:** 2D Pixel
2. **Filter:** Nearest (no smooth scaling)
3. **Mipmaps:** Off
4. **Compress Mode:** Lossy (PNG is lossless anyway)

---

## Animation Template

### Walk Cycle (4-frame loop)
```
Frame 0: Standing, left foot planted
Frame 1: Step forward, right foot raised
Frame 2: Walking, both legs in motion
Frame 3: Step forward, left foot raised
(Loop back to Frame 0)
```

Timing: 10-12 frames per second for walking

### Idle Animation (optional, subtle)
```
Frame 0: Neutral standing
Frame 1: Slight sway left
Frame 2: Neutral standing
Frame 3: Slight sway right
(Loop)
```

Timing: 8 frames per second (very relaxed)

---

## Workflow for Artists

1. **Design Phase:**
   - Sketch character/tile concepts at actual 24×24 size
   - Show pixel dimensions in reference images
   - Discuss color palette with team

2. **Implementation Phase:**
   - Create sprite in Aseprite, Piskel, or Photoshop
   - Test in Godot at intended scale (pixel-perfect)
   - Verify readability and animation smoothness

3. **Export Phase:**
   - Export as PNG (transparency)
   - Name according to conventions
   - Drag into Godot `/assets/` folder
   - Verify import settings are correct

4. **Integration Phase:**
   - Create Godot `AnimatedSprite2D` nodes or `Sprite2D` scenes
   - Set up animations in AnimationPlayer
   - Test in-game with actual character movement
   - Commit to Git (PNG files, not native project files)

---

## Asset Checklist (MVP Requirement)

- [ ] Player sprite (4-directional idle + walk cycle)
- [ ] 3 unique NPC sprites (idle + talk frames)
- [ ] Town tileset (terrain, buildings, props)
- [ ] UI buttons and text boxes
- [ ] Simple icons (relationship, quest, mood)
- [ ] Dialogue box background
- [ ] Font for dialogue and UI

---

## Future Enhancements

- **Clothes swapping** — Multiple outfit overlays per NPC
- **Emotion expressions** — Angry, happy, sad overlay faces
- **Weather effects** — Rain, snow particle overlays
- **Seasons** — Tileset variations for each season
- **Character portraits** — Full-size art for dialogue portraits
- **Animation polish** — More frames for smoothness
- **VFX** — Dust clouds, spell effects, impact animations
