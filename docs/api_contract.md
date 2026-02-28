# API Contract - Backend ↔ Game Communication

## Endpoint Overview

**POST /api/gemini**

Accepts an NPC dialogue request and returns AI-generated response with rumor and relationship impacts.

---

## Request Schema

```json
{
  "npc_id": "alice",
  "npc_name": "Alice the Organizer",
  "npc_personality": {
    "traits": ["ambitious", "social", "perfectionist"],
    "speech_pattern": "friendly and upbeat",
    "current_mood": "excited_but_stressed"
  },
  "player_message": "What do you think about the duck party?",
  "player_relationship": 25,
  "dialogue_history": [
    { "role": "npc", "text": "Oh, hi there! What's up?" },
    { "role": "player", "text": "Hey Alice, how's the party planning going?" }
  ],
  "known_rumors": [
    {
      "id": "rumor_001",
      "text": "The mayor has been blocking event approvals",
      "tags": ["politics", "mayor"]
    },
    {
      "id": "rumor_002",
      "text": "Strange visitor came to town last week",
      "tags": ["mystery"]
    }
  ],
  "town_context": {
    "current_season": "spring",
    "game_time": "afternoon",
    "event_urgency": 8
  }
}
```

### Request Fields

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `npc_id` | string | Yes | Unique NPC identifier |
| `npc_name` | string | Yes | Display name |
| `npc_personality` | object | Yes | Personality traits, speech pattern, mood |
| `player_message` | string | Yes | What the player just said |
| `player_relationship` | integer | Yes | -100 to 100 (lower = disliked, higher = liked) |
| `dialogue_history` | array | No | Previous exchanges (max 10 messages) |
| `known_rumors` | array | No | Rumors this NPC knows (max 5) |
| `town_context` | object | No | Time, season, urgency level |

---

## Response Schema (Success: 200 OK)

```json
{
  "success": true,
  "npc_reply": "I'm doing great! The planning is going really well, but the mayor keeps being difficult. Have you heard anything about what's going on with him?",
  "rumor": {
    "text": "The mayor might be influenced by outside forces to block community events",
    "tags": ["politics", "allegation", "mayor"],
    "confidence": 0.7,
    "rumor_target_npc": null,
    "suggested_spread_to": ["bob_deputy", "charlie"]
  },
  "relationship_delta": 8,
  "quest_progress": {
    "duck_party_permit": {
      "progress": 35,
      "next_step": "Talk to the deputy mayor about the mayor's concerns"
    }
  },
  "next_dialogue_hook": "Alice mentions she'll try to set up a meeting with the deputy mayor",
  "npc_mood_change": "excited_determined",
  "metadata": {
    "model_used": "gemini-2.0-flash",
    "tokens_used": 245,
    "processing_time_ms": 1240
  }
}
```

### Response Fields

| Field | Type | Notes |
|-------|------|-------|
| `success` | boolean | Always `true` on success |
| `npc_reply` | string | The NPC's response (100-200 chars recommended) |
| `rumor` | object | New rumor generated (or null if none) |
| `relationship_delta` | integer | Change to player-NPC relationship (-50 to +50) |
| `quest_progress` | object | Any quest state changes for this NPC |
| `next_dialogue_hook` | string | Optional narrative hook for follow-up |
| `npc_mood_change` | string | NPC's mood after conversation |
| `metadata` | object | Debug info (tokens, latency, etc.) |

### Rumor Object

```json
{
  "text": "string - the rumor content (50-150 chars)",
  "tags": ["array", "of", "tags"],
  "confidence": "0.0 to 1.0 (NPC's certainty about rumor)",
  "rumor_target_npc": "null or string - which NPC the rumor is about",
  "suggested_spread_to": ["array", "of", "npc_ids"]
}
```

---

## Error Responses

### 400 Bad Request
```json
{
  "success": false,
  "error": "Invalid request schema",
  "details": {
    "missing_fields": ["npc_id"],
    "invalid_fields": [
      {
        "field": "player_relationship",
        "reason": "must be between -100 and 100"
      }
    ]
  }
}
```

### 422 Unprocessable Entity (Gemini Response Invalid)
```json
{
  "success": false,
  "error": "Gemini response failed validation",
  "details": {
    "missing_fields": ["npc_reply"],
    "schema_violations": [
      {
        "field": "relationship_delta",
        "expected": "integer",
        "received": "string"
      }
    ],
    "raw_response": "DEBUG: Gemini's actual response (truncated)"
  }
}
```

### 429 Too Many Requests
```json
{
  "success": false,
  "error": "Rate limit exceeded",
  "retry_after_seconds": 60
}
```

### 500 Internal Server Error
```json
{
  "success": false,
  "error": "Internal server error",
  "error_code": "GEMINI_API_UNAVAILABLE",
  "details": "Failed to connect to Gemini API. Check your API key."
}
```

---

## Validation Rules

### Request Validation (Backend to Godot)

The backend should validate incoming requests:
1. All required fields present
2. `npc_id` is alphanumeric + underscore
3. `player_relationship` is integer between -100 and 100
4. `player_message` is non-empty string (max 500 chars)
5. `dialogue_history` array has max 10 items
6. `known_rumors` array has max 5 items
7. All nested objects conform to expected schemas

**If validation fails:** Return 400 with detailed error.

### Response Validation (Gemini to Backend)

The backend must validate Gemini's response before returning to game:

1. **Required fields:** `npc_reply` (non-empty string)
2. **Optional but validate if present:**
   - `rumor` object has required fields: `text`, `tags`, `confidence`
   - `relationship_delta` is integer, -50 to 50
   - `quest_progress` is object with string keys
   - `npc_mood_change` is valid mood string
3. **String constraints:**
   - `npc_reply` max 200 chars
   - `rumor.text` max 150 chars
4. **Array constraints:**
   - `rumor.tags` max 5 items
   - `rumor.suggested_spread_to` max 3 NPC IDs
5. **Type checking:**
   - `confidence` is float 0.0-1.0
   - `metadata.tokens_used` is integer

**If validation fails:** Return 422 with violations and (optionally) raw Gemini response for debugging.

---

## Example Conversation Flow

### 1. Game sends request:
```json
{
  "npc_id": "alice",
  "npc_name": "Alice the Organizer",
  "player_message": "Can you help me convince the mayor?",
  "player_relationship": 45,
  "dialogue_history": [
    { "role": "npc", "text": "The mayor keeps blocking my applications!" }
  ]
}
```

### 2. Backend calls Gemini with system prompt:
```
You are roleplaying as Alice the Organizer in a duck-themed town.
Personality: ambitious, social, perfectionist
Current mood: excited but stressed
Player relationship: 45/100 (friendly)

The player asked: "Can you help me convince the mayor?"

Respond authentically in character. Your response MUST be valid JSON with these fields:
{
  "npc_reply": "your response here (max 200 chars)",
  "rumor": optional object with text, tags, confidence,
  "relationship_delta": -50 to 50,
  ...
}
```

### 3. Backend validates response

If Gemini's JSON is malformed, return 422 error.

### 4. Backend returns to game:
```json
{
  "success": true,
  "npc_reply": "Oh absolutely! I've been thinking about forming a coalition...",
  "relationship_delta": 12,
  "quest_progress": { "duck_party_permit": { "progress": 45 } }
}
```

### 5. Game updates state:
- Text displays on NPC dialogue UI
- Player relationship with Alice increases by 12
- Quest progress bar updates

---

## Rate Limiting & Caching

- **Rate limit:** 60 requests per minute per game instance
- **Caching:** Consider caching repeated NPC responses (same query within 5 minutes)
- **Timeout:** Gemini API calls timeout after 30 seconds

---

## Testing Checklist

- [ ] Valid request returns 200 with proper response
- [ ] Missing required field returns 400
- [ ] Invalid relationship score returns 400
- [ ] Malformed Gemini response returns 422 with details
- [ ] Network timeout handled gracefully
- [ ] Response latency logged
- [ ] Sample responses parsed correctly by Godot JSON parser

---

## Godot Client Integration

In your Godot client, parse responses like:

```gdscript
var response_data = JSON.parse_string(response_text)
if response_data["success"]:
    var npc_reply = response_data["npc_reply"]
    var relationship_delta = response_data["relationship_delta"]
    # Update game state
else:
    var error = response_data["error"]
    # Show error to player
```

---

## Notes for Future Enhancement

- Consider WebSocket for real-time NPC state sync
- Add rumor persistence to Firebase (optional)
- Implement multiplayer synchronization endpoint
- Add authentication if publishing publicly
