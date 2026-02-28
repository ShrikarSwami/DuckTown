# Task Board - Duck Party Rumor Game

## Sprint Overview

Team of 4. Estimated 2-week sprint for MVP.

---

## Core Features Breakdown

### 1. Game Loop & Player Movement (Shrikar)

**Owner:** Shrikar Swami

- [ ] Create main scene with town tilemap
- [ ] Implement player controller (WASD + arrow keys)
- [ ] Camera follow player
- [ ] NPC placement and sprite rendering
- [ ] Collision detection (walls, NPCs)
- [ ] Proximity detection for dialogue trigger

**Estimated:** 4 days  
**Blockers:** Art assets (sprites)

---

### 2. NPC Dialogue & Interaction System (Adithya)

**Owner:** Adithya Pillai

- [ ] Create NPC scene template
- [ ] Implement dialogue UI (text box, character name)
- [ ] Integrate with backend Gemini API
- [ ] Parse backend JSON responses
- [ ] Handle offline mode (fallback dialogues)
- [ ] Dialogue history tracking
- [ ] Error handling for failed requests

**Estimated:** 5 days  
**Dependencies:** Backend endpoint working, API contract finalized

---

### 3. Rumor System & NPC Relationships (Abhiram)

**Owner:** Abhiram Kandadi

- [ ] Build rumor data structure
- [ ] Implement relationship tracking per NPC
- [ ] Create rumor propagation algorithm
- [ ] NPC personality affect dialogue tone
- [ ] Rumor degradation/transformation over time
- [ ] UI to display known rumors
- [ ] Rumor affect on NPC responses

**Estimated:** 5 days  
**Dependencies:** Dialogue system, NPC state persistence

---

### 4. Backend Proxy & Gemini Integration (Daksh)

**Owner:** Daksh Aggrawal

- [ ] Set up Express.js server
- [ ] Create `/api/gemini` POST endpoint
- [ ] Integrate Google Gemini SDK
- [ ] Implement request JSON validation
- [ ] Implement response JSON validation
- [ ] Error handling and logging
- [ ] Environment variable management
- [ ] Deploy to local/staging environment
- [ ] Write API contract documentation

**Estimated:** 3 days  
**Blockers:** Gemini API key access

---

## Supporting Tasks

### UI & Polish
- [ ] Main menu/start screen layout
- [ ] Settings screen (audio, difficulty, backend URL)
- [ ] Quest log UI
- [ ] Relationship/rumor tracker UI

### Art & Animation
- [ ] Player sprite (4-directional, 24x24)
- [ ] 3-4 NPC sprite variations
- [ ] Town tileset
- [ ] UI icons and fonts

### Testing & Debug
- [ ] Test NPC dialogue edge cases
- [ ] Test rumor propagation logic
- [ ] Test backend error handling
- [ ] Integration testing (game ↔ backend)

---

## Dependencies & Milestones

```
Week 1:
  Mon-Tue   → Game loop (Shrikar)
  Wed-Thu   → Backend setup (Daksh)
  Fri       → Integration (Adithya + Daksh)

Week 2:
  Mon-Wed   → Rumor system (Abhiram)
  Thu-Fri   → Polish, testing, bug fixes
```

---

## Communication & Blockers

**Daily standup:** 10am (async Slack updates acceptable)  
**Code review:** PRs require 1 approval before merge to `develop`  
**Blockers:** Post in team channel ASAP

### Known Blockers (To Resolve)
- [ ] Gemini API key provisioning
- [ ] Optional Firebase setup (low priority, MVP doesn't need it)
- [ ] Final NPC profiles & dialogue tone guide

---

## Definition of Done (DoD)

Each task is done when:
1. Code is written and tested locally
2. PR submitted with clear description
3. At least 1 teammate reviews
4. Merged to `develop`
5. No blocking issues on main branch

---

## References

- Architecture: `/docs/architecture.md`
- API Contract: `/docs/api_contract.md`
- NPC Profiles: `/docs/npc_profiles_template.md`
- Art Guidelines: `/docs/art_pipeline.md`
