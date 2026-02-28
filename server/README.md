# Duck Party Rumor Game - Backend Server

A Node.js/Express proxy server that relays NPC dialogue requests to Google Gemini API.

## Overview

This backend is **optional** for the game. However, with it:
- NPCs generate dynamic, contextual dialogue using Gemini
- Conversations feel more natural and responsive
- Player choices meaningfully affect NPC behavior

**Without backend:** NPCs respond with pre-written fallback dialogues (limited variety).

## Prerequisites

- **Node.js 18+** (download from [nodejs.org](https://nodejs.org))
- **Google Gemini API Key** (get from [Google AI Studio](https://makersuite.google.com/app/apikey))
- Optional: **Firebase credentials** for persistence (not required for MVP)

## Installation

### 1. Install Dependencies

```bash
npm install
```

This installs:
- `express` — HTTP server framework
- `dotenv` — Environment variable management
- `@google/generative-ai` — Google Gemini SDK
- `cors` — Cross-origin request handling

### 2. Set Up Environment Variables

Copy the environment template:

```bash
cp .env.example .env
```

Edit `.env` and add your Gemini API key:

```
GEMINI_API_KEY=your_api_key_here
BACKEND_PORT=8080
```

**⚠️ NEVER commit `.env` to Git.** It contains secrets.

### 3. Start the Server

```bash
npm start
```

You should see:
```
Duck Party backend running on http://localhost:8080
```

For development with auto-reload:

```bash
npm run dev
```

## API Documentation

### POST /api/gemini

Generates NPC dialogue via Gemini.

**Request:**
```json
{
  "npc_id": "alice",
  "npc_name": "Alice the Organizer",
  "npc_personality": {
    "traits": ["ambitious", "social"],
    "speech_pattern": "friendly",
    "current_mood": "excited"
  },
  "player_message": "What do you think about the party?",
  "player_relationship": 45,
  "dialogue_history": [...],
  "known_rumors": [...]
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "npc_reply": "I'm thrilled about it! The planning is going great...",
  "relationship_delta": 8,
  "rumor": {
    "text": "The mayor is being difficult",
    "tags": ["politics", "mayor"],
    "confidence": 0.7
  },
  "quest_progress": {...},
  "npc_mood_change": "excited_determined",
  "metadata": {
    "model_used": "gemini-2.0-flash",
    "tokens_used": 245,
    "processing_time_ms": 1240
  }
}
```

**Error (400/422):**
```json
{
  "success": false,
  "error": "Invalid request schema",
  "details": {...}
}
```

See `/docs/api_contract.md` for full specification.

## Running Locally

### 1. Start Backend

```bash
cd server
npm install
npm start
```

### 2. Configure Game

In Godot game settings:
- Backend URL: `http://localhost:8080`
- Enable API calls: `true`

### 3. Test API

```bash
curl -X POST http://localhost:8080/api/gemini \
  -H "Content-Type: application/json" \
  -d '{
    "npc_id": "alice",
    "npc_name": "Alice",
    "player_message": "Hi Alice!",
    "player_relationship": 0,
    "npc_personality": {"traits": ["friendly"]}
  }'
```

Expected response includes `npc_reply` field.

## Project Structure

```
server/
├── index.js                    # Express app entry point
├── package.json               # Dependencies
├── .env.example               # Environment template
├── src/
│   ├── routes/
│   │   └── gemini.js          # POST /api/gemini endpoint
│   ├── services/
│   │   └── geminiService.js   # Gemini API integration
│   └── utils/
│       └── validateGeminiJson.js  # Response validation
└── README.md                  # This file
```

## Key Features

### Request Validation
- Validates incoming request schema
- Returns 400 with detailed errors if invalid
- Prevents malformed requests from reaching Gemini

### Gemini Integration
- Calls Google Gemini API with system prompt
- System prompt defines NPC personality & constraints
- Passes dialogue history and known rumors

### Response Validation
- Validates Gemini response against expected JSON schema
- Returns 422 if response is malformed
- Includes debug info to help diagnose API issues

### Logging
- Logs all requests, responses, and errors
- Includes latency and token usage info
- Helps debuggingin development and troubleshooting

### Error Handling
- Graceful fallbacks for network errors
- Clear error messages for game developers
- Rate limiting (60 requests/minute per game instance)

## Development Tips

### Debug Mode
Add console logging by uncommenting lines in:
- `src/routes/gemini.js` — Request/response logs
- `src/services/geminiService.js` — Gemini API calls
- `src/utils/validateGeminiJson.js` — Validation details

### Testing Locally
Use curl or Postman to test the `/api/gemini` endpoint.

### Environment Variables
- `GEMINI_API_KEY` — Your API key (required)
- `BACKEND_PORT` — Server port (default: 8080)
- `FIREBASE_PROJECT_ID`, etc. — Optional for persistence

### Common Issues

**"API key not found"**
- Ensure `.env` file exists and `GEMINI_API_KEY` is set
- Check that `.env` is in the `server/` directory

**"Connection refused"**
- Server not running? Try `npm start` again
- Check that port 8080 is available (`lsof -i :8080`)

**"Gemini response invalid"**
- Check Gemini's response in console logs
- Verify system prompt format in `geminiService.js`
- See `/docs/api_contract.md` for expected schema

## Deployment Notes

For production:
1. Move API key to secure environment variable service
2. Add CORS restrictions (whitelist game domain)
3. Implement rate limiting per user/game instance
4. Add database for caching/persistence (Firebase, PostgreSQL)
5. Set up monitoring and alerting for API failures
6. Use HTTPS for communication with client

For MVP hackathon, localhost is fine.

## Security Considerations

- **Never hardcode API keys** — Use `.env` only
- **Validate all inputs** — Prevent injection attacks
- **Limit response size** — Prevent flooding
- **Rate limit requests** — Prevent API abuse
- **Log sensitive data carefully** — Avoid logging full API keys

## Optional Firebase Integration

To add persistence (optional for MVP):

1. Get Firebase credentials from [Firebase Console](https://console.firebase.google.com)
2. Add to `.env`:
   ```
   FIREBASE_PROJECT_ID=your_project
   FIREBASE_CLIENT_EMAIL=your_email
   FIREBASE_PRIVATE_KEY=your_key
   ```
3. Implement Firebase SDK in `geminiService.js`

## Contributing

When adding features:
1. Update validation schema if adding new fields
2. Add tests for new endpoints
3. Document changes in this README
4. Ensure backwards compatibility with game client

## References

- **Gemini API Docs:** https://ai.google.dev
- **API Contract:** `/docs/api_contract.md`
- **Architecture:** `/docs/architecture.md`
- **NPC Profiles:** `/docs/npc_profiles_template.md`

## License

MIT License — See root `/LICENSE` file

---

**Questions?** Check the team Slack or open an issue.
