# 🦆 DuckTown Demo - Quick Start Guide

## 🚦 One Run Smoke Test

**Use this checklist to verify the full demo flow before showing it live.**

### 1. Start Game
- **Action:** Run Main.tscn in Godot
- **Expected:** Console shows `🦆 DuckTown Starting...` and `=== DEMO RUN #1 ===`
- **Console:** 
  ```
  🦆 DuckTown Starting...
  === DEMO RUN #1 ===
  ✅ All systems initialized
  ```

### 2. Enter Player Name
- **Action:** At StoryIntro screen, type your name (or leave blank for "Alex") and click Continue
- **Expected:** Transition to Main scene with intro message popup
- **Console:** `[StoryIntro] Player name set: <YourName>`

### 3. Talk to Baker
- **Action:** Walk to `Npc_Baker` (near bakery), press E, select option mentioning "duck"
- **Expected:** 
  - DialoguePanel opens with NPC name "Baker"
  - Gemini responds with food-related reply
  - Trust HUD shows `Baker: 10` (or higher, green)
  - ProgressTracker checkbox 1 turns green (☑)
- **Console:**
  ```
  [DialogueUI] Opened for Npc_Baker
  [NPC_Interaction baker] Starting dialogue: 'Can you make duck cupcakes?'
  [NPC Baker] Relationship: 0 → 10 (delta: +10)
  [QuestManager] Baker approved! (trust: 10)
  ```

### 4. Talk to Merch
- **Action:** Walk to `Npc_merchGuy`, press E, select option mentioning "mean guard"
- **Expected:**
  - Trust HUD shows `Merch: 10` (green)
  - ProgressTracker checkbox 2 turns green (☑)
- **Console:**
  ```
  [NPC Merch] Relationship: 0 → 10 (delta: +10)
  [QuestManager] Merch approved! (trust: 10)
  ```

### 5. Talk to Mean Guard
- **Action:** Walk to `Npc_meanGuard`, press E, select "We need you to guard the party"
- **Expected:**
  - Trust HUD shows `MeanGuard: 15` (green)
  - ProgressTracker checkbox 3 turns green (☑)
  - Progress bar fills to 3/3
- **Console:**
  ```
  [NPC Mean Guard] Relationship: -10 → 5 (delta: +15)
  [QuestManager] Mean Guard approved! (trust: 5)
  [DemoPhase] ✨ ALL APPROVALS MET! Party unlock!
  [QuestManager] 🎉 PARTY TRIGGERED!
  ```

### 6. Verify ProgressTracker Updates
- **Expected:** All three checkboxes are green (☑), progress bar shows 3/3 and is green

### 7. Verify Party Scene Triggers
- **Expected:** Scene automatically changes to Party.tscn
- **Console:**
  ```
  🎉 PARTY SCENE LOADED!
  [PartyScene] Video start
  [VERIFY] VIDEO START
  ```

### 8. Verify Victory Video Plays with Audio
- **Expected:** 
  - Full-screen video of party celebration
  - Audio plays simultaneously
  - Video runs for ~8-10 seconds
- **Console:**
  ```
  [PartyScene] Video finished
  [VERIFY] VIDEO FINISH
  ```

### 9. Verify Restart Returns to Main
- **Expected:** After video finishes, scene automatically reloads to Main.tscn
- **Console:**
  ```
  🔄 Restarting demo...
  [VERIFY] RESTARTING MAIN
  === DEMO RUN #2 ===
  ```

---

## 🔧 Debug Configuration

### Verbose Debug Toggle
All game scripts include a `VERBOSE_DEBUG` constant (set to `false` by default) that controls detailed diagnostic logging:

**Files with VERBOSE_DEBUG:**
- `dialogue_ui.gd` - UI positioning, panel state, chat log metrics
- `npc_interaction.gd` - Detailed interaction flow, fallback responses
- `main.gd` - System initialization details, NPC connection logs
- `party_scene.gd` - Media loading details, fade timing
- `quest_manager.gd` - Phase transitions, approval tracking details
- `progress_tracker.gd` - ProgressBar update cycles
- `trust_hud.gd` - HUD registration, NPC discovery
- `debug_overlay.gd` - NPC detection loops
- `gemini_client.gd` - HTTP request details
- `player_controller.gd` - Movement/interact input events
- `npc.gd` - Click events, rumor learning details

**To enable verbose logging:** Change `const VERBOSE_DEBUG := false` to `true` in any script.

### Important Logs (Always Visible)
These lifecycle logs remain visible even when `VERBOSE_DEBUG = false`:

**Startup & Initialization:**
- `🦆 DuckTown Starting...`
- `=== DEMO RUN #X ===`
- `✅ All systems initialized`

**Dialogue & Interaction:**
- `[DialogueUI] Opened for <NPC>`
- `[NPC_Interaction X] Starting dialogue: '<message>'`

**Relationship & Trust:**
- `[NPC X] Relationship: A → B (delta: +C)`

**Approvals & Quest Progress:**
- `[QuestManager] <NPC> approved! (trust: X)`
- `[DemoPhase] ✨ ALL APPROVALS MET! Party unlock!`
- `[QuestManager] 🎉 PARTY TRIGGERED!`

**Party Scene:**
- `🎉 PARTY SCENE LOADED!`
- `[PartyScene] Video start`
- `[VERIFY] VIDEO START`
- `[PartyScene] Video finished`
- `[VERIFY] VIDEO FINISH`
- `🔄 Restarting demo...`
- `[VERIFY] RESTARTING MAIN`

**Errors:**
- All `push_error()` and `push_warning()` messages remain visible

---

## ✅ Implementation Status

### Core Systems (COMPLETE)
- ✅ Gemini API integration with JSON parsing & fallbacks
- ✅ HTTP client in Godot (async requests via signals)
- ✅ Dialogue UI with 2-3 option selection
- ✅ Trust/relationship system (NPC approval gates)
- ✅ Rumor spreading (auto-propagates after 15-30s)
- ✅ Quest system (Baker/Merch/Guard approvals → Party)
- ✅ Debug overlay (Press D to view system state)
- ✅ Party scene trigger (when all 3 approvals met)

### Not Implemented (Phase 2)
- ❌ Firestore persistence (game state saves to cloud)
- ❌ Controlled demo path (scripted narrative)
- ❌ Demo video

---

## 🚀 Setup Instructions

### 1. Backend Setup

```bash
cd server

# Install dependencies
npm install

# Create .env file
cp .env.example .env

# Add your Gemini API key to .env
# Get key at: https://makersuite.google.com/app/apikey
echo "GEMINI_API_KEY=your_key_here" > .env

# Start backend
npm start
```

Backend runs at `http://localhost:8080`

### 2. Game Setup

1. Open `game/` folder in Godot 4.6+
2. Run the Main.tscn scene
3. Backend must be running on port 8080

---

## 🎮 How to Play

### Controls
- **WASD / Arrow Keys** - Move player
- **E** - Interact with NPCs when nearby
- **D** - Toggle debug overlay

### Demo Flow
1. Approach Baker near bakery (upper left)
2. Press **E** to open dialogue
3. Select a dialogue option (1-3 buttons appear)
4. Watch NPC reply and trust score update
5. **Rumor automatically spreads** after 15-30 seconds
6. Other NPCs react to rumor, changing their trust
7. Get trust ≥ 30 with Baker, Merch, and Guard
8. **Party scene triggers!** 🎉

### Debug Overlay (Press D)
Shows real-time:
- NPC trust scores with visual bars
- Approval status (Baker/Merch/Guard)
- Active rumors and spread count
- Progress toward party (0/3 → 3/3)

---

## 🧪 Testing Checklist

### Backend Test
```bash
# Health check
curl http://localhost:8080/health

# Expected: {"status":"ok","timestamp":"..."}
```

### Gemini Integration Test
1. Start backend with valid API key
2. Approach any NPC in game
3. Press E, select dialogue option
4. **PASS:** NPC responds with generated text
5. **PASS:** Trust score changes
6. **FAIL:** Check backend logs for errors

### Rumor Spread Test
1. Talk to Baker, generate a rumor
2. Wait 15-30 seconds
3. **PASS:** Console shows "Spreading rumor..."
4. **PASS:** Other NPCs learn the rumor
5. Press D to verify rumor count increases

### Quest System Test
1. Build trust with Baker (talk positively)
2. Get trust ≥ 30
3. **PASS:** Debug shows ✓ Baker approval
4. Repeat for Merch and Guard
5. **PASS:** Party scene loads automatically

---

## 🐛 Known Issues

### Backend offline
- **Symptom:** "ERROR: Backend returned status XXX"
- **Fix:** Ensure `npm start` is running on port 8080

### No Gemini responses
- **Symptom:** NPC says "I... I don't know what to say"
- **Fix:** Check GEMINI_API_KEY in server/.env

### NPC not responding
- **Symptom:** UI opens but nothing happens
- **Fix:** Check Godot console for errors, verify Main.gd initialized systems

### Debug overlay not showing
- **Symptom:** Press D does nothing
- **Fix:** NPCs need time to initialize. Wait 1 second after game starts.

---

## 📊 System Architecture

```
Player presses E
  ↓
DialogueUI opens
  ↓
Player selects option → NPC_Interaction.start_dialogue()
  ↓
GeminiClient.call_api() → HTTP POST to backend
  ↓
Backend calls Gemini API → Parses JSON
  ↓
Response → NPC_Interaction updates trust
  ↓
RumorSystem.add_rumor() if rumor present
  ↓
Timer fires (15-30s) → RumorSystem spreads to other NPCs
  ↓
QuestManager checks trust ≥ 30 for approvals
  ↓
All approvals → Party scene!
```

---

## 🎥 Demo Video Script (1 minute)

**0:00-0:10** - Show player movement + approach NPC  
**0:10-0:30** - AI conversation (show dialogue options + response)  
**0:30-0:40** - Press D, show rumor spreading in debug overlay  
**0:40-0:50** - Show trust meters increasing  
**0:50-1:00** - Party scene trigger + celebration  

**Voiceover:**
> "This is DuckTown, where NPCs remember every conversation. Watch as a rumor spreads dynamically, changing relationships across the town. When you earn enough trust, the party begins!"

---

## 🔧 Next Steps (Phase 2)

1. **Firestore Integration** - Persist game state to cloud
2. **Controlled Path** - Script guaranteed demo flow
3. **Polish** - Animation, sound effects, more NPCs
4. **Record Demo** - Capture 1-minute gameplay video

---

## 📝 Files Modified/Created

### New Files
- `game/scripts/main.gd` - System initializer
- `game/scripts/debug_overlay.gd` - Debug UI
- `game/scripts/party_scene.gd` - Victory scene
- `game/scenes/Party.tscn` - Party scene
- `DEMO_GUIDE.md` - This file

### Modified Files
- `game/scripts/gemini_client.gd` - Full HTTP implementation
- `game/scripts/npc_interaction.gd` - Gemini integration
- `game/scripts/dialogue_ui.gd` - Option selection
- `game/scripts/rumor_system.gd` - Auto-spread logic
- `game/scripts/quest_manager.gd` - Approval gates
- `game/scripts/npc.gd` - Integration layer
- `server/src/services/geminiService.js` - Real API calls
- `game/scenes/Main.tscn` - Script attached
- `game/scenes/NPC.tscn` - Script + group tag

---

## 🦆 Ready to Demo!

**All core systems are functional.** Start the backend, run the game, and experience the "intelligent world" moment when rumors spread autonomously!
