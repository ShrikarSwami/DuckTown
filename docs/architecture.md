# Duck Party Rumor Game - Architecture

## System Overview

```
┌─────────────────────────────────────────────────────┐
│           Godot Client (2D Game)                    │
│  - Player controller                                │
│  - NPC interaction UI                               │
│  - Rumor propagation tracking                       │
│  - Quest/relationship state management              │
└────────────────┬────────────────────────────────────┘
                 │ HTTP/JSON
                 │
    ┌────────────▼────────────┐
    │   Node.js Backend       │
    │   (Optional Proxy)      │
    │ - Gemini API relay      │
    │ - JSON validation       │
    │ - Request logging       │
    └────────────┬────────────┘
                 │ API Key
                 │
    ┌────────────▼────────────┐
    │   Google Gemini API     │
    │   (LLM for NPC AI)      │
    └─────────────────────────┘

    ┌──────────────────────────┐
    │   Firebase (Optional)    │
    │   - Game state persist   │
    │   - Leaderboards        │
    │   - User progress       │
    └──────────────────────────┘
```

## Tech Stack

### Frontend
- **Engine:** Godot 4.x
- **Language:** GDScript
- **Target:** Windows, macOS, Linux (desktop build)

### Backend (Optional for AI)
- **Runtime:** Node.js 18+
- **Framework:** Express.js
- **External API:** Google Gemini API

### Data Persistence (Optional)
- **Database:** Firebase Realtime Database or Firestore
- **Purpose:** Cross-device sync, leaderboards, analytics

### Optional LLM Enhancement
- **LlamaIndex** integration for rumor/lore memory management
- Long-context retrieval for consistent NPC behavior

## Game Loop

1. **Player Movement Phase**
   - Player navigates the town
   - Triggers NPC proximity detection

2. **Interaction Phase**
   - Player talks to NPC
   - Game sends NPC context + dialogue history to backend

3. **Backend Processing**
   - Validates request JSON schema
   - Calls Gemini API with system prompt + dialogue context
   - Validates Gemini response against expected schema
   - Returns enriched response (dialogue, rumor data, relationship delta)

4. **State Update Phase**
   - Update relationship scores with NPCs
   - Add new rumors to propagation queue
   - Track quest progress
   - Update UI with results

5. **Rumor Propagation Phase**
   - Track rumor spread between NPCs
   - Apply degradation/transformation
   - Influence NPC dialogue on next interaction

## Data Models

### NPC State
```gdscript
# In-game NPC object
- npc_id: String
- name: String
- relationship_with_player: int (-100 to 100)
- known_rumors: Array[String]  # Rumor IDs
- personality_traits: Array[String]
- current_mood: String
- dialogue_history: Array[String]
```

### Rumor Structure
```json
{
  "rumor_id": "rumor_001",
  "text": "Alex is hiding something...",
  "tags": ["mystery", "suspicious"],
  "origin_npc": "bob",
  "created_at": 1234567890,
  "believer_npcs": ["alice", "charlie"],
  "spread_factor": 0.7
}
```

### Backend Communication

**Request to /api/gemini:**
```json
{
  "npc_id": "alice",
  "npc_personality": {...},
  "dialogue_history": [...],
  "player_relationship": 45,
  "current_rumors": [...]
}
```

**Response from /api/gemini:**
(See `/docs/api_contract.md` for full spec)

## Offline vs. Online Modes

### Offline Mode
- No backend required
- NPCs respond with pre-written dialogues
- Limited rumor system
- No persistence

### Online Mode (with Backend)
- Full Gemini integration
- Dynamic NPC personalities
- Rumor generation and propagation
- Optional Firebase persistence

## Security Considerations

- **API Keys:** Kept in `.env`, never committed
- **Backend validation:** All Gemini responses validated before use
- **CORS:** Backend should restrict to game domain in production
- **Input sanitization:** Validate NPC data before sending to Gemini

## File Organization

```
game/               # Godot project root
  project.godot    # Engine config
  scenes/          # .tscn files
  scripts/         # .gd scripts
  assets/          # Art, audio, data
    sprites/
    ui/
    tiles/

server/            # Node.js backend
  src/
    routes/        # Express routes
    services/      # Business logic
    utils/         # Helpers
  index.js         # Entry point
  package.json
```

## Future Enhancements

- **LlamaIndex Integration** — For persistent rumor memory across sessions
- **Multiplayer** — Multiple players in same town
- **Advanced NPC Memory** — Contextual responses based on full conversation history
- **Voice Generation** — TTS for NPC dialogue
- **Mobile Port** — iOS/Android build from Godot
- **Analytics** — Track rumor spread, player interactions, decisions
