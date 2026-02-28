# NPC Profile Template

Use this template to define each NPC in the Duck Party Rumor Game. These profiles inform both dialogue generation and relationship/rumor mechanics.

---

## Profile Fields

### Basic Identity
- **NPC ID:** Unique identifier (e.g., `alice`, `bob_mayor`) — no spaces
- **Name:** Display name (e.g., "Alice the Organizer")
- **Role/Job:** What do they do in town? (e.g., "Event Coordinator", "Duck Care Specialist")
- **Age Group:** Adult, Elder, Teen (for contextual dialogue)

### Personality & Traits
- **Personality Type:** (e.g., Optimistic, Cynical, Neutral, Anxious, Combative)
- **Key Traits:** 3-5 descriptors (e.g., "ambitious", "gossipy", "careful", "fun-loving")
- **Speech Pattern:** How do they talk? (e.g., formal, casual, sarcastic, poetic)
- **Interests:** What do they care about? (e.g., "community events", "personal freedom", "tradition")
- **Fears/Dealbreakers:** What triggers negative reactions? (e.g., "change", "dishonesty", "chaos")

### Relationships
- **Allies:** Who do they like? (e.g., `alice`, `charlie`) — names or IDs
- **Rivals:** Who do they conflict with? (e.g., `dave`)
- **Neutral:** Who do they barely know? (e.g., `eve`)
- **Romantic Interest:** Any crushes or relationships? (e.g., "secretly loves alice")

### Starting State
- **Initial Relationship with Player:** -50 to 50 (e.g., `10` = neutral, `30` = friendly, `-20` = suspicious)
- **Known Rumors:** List of rumor IDs they know at game start (e.g., `["rumor_weather_control", "rumor_mystery_visitor"]`)
- **Mood:** Default mood at game start (e.g., "happy", "stressed", "bored")

### Quest/Story Hook
- **Quest Hook:** What task might they ask the player? (e.g., "Find out who stole the town clock")
- **Quest Reward:** What do they offer? (e.g., "Introduction to the mayor", "Free event tickets")
- **Success/Failure Paths:** How does the quest change if player succeeds/fails?

### Dialogue Guidance
- **Greeting Dialogue:** Example: "Oh hey there! Have you heard about the mayor's new duck policy?"
- **Curious Topic:** What will they gossip about if player brings it up?
- **Turn-off Topic:** What makes them refuse to talk?
- **Relationship Delta by Type:**
  - Compliment them: +5
  - Help with quest: +15
  - Spread false rumor about them: -20
  - Share relevant rumor they're interested in: +10

---

## Example Profile

```
### Alice the Organizer (alice)

**Basic Identity**
- ID: alice
- Name: Alice the Organizer
- Role: Event Coordinator
- Age Group: Adult

**Personality & Traits**
- Type: Optimistic, Detail-Oriented
- Traits: ambitious, social, helpful, perfectionist, gossipy
- Speech: Friendly and upbeat, occasionally frantic when stressed
- Interests: town events, bringing the community together, the duck party
- Fears: Last-minute cancellations, incompetence, failure to deliver on promises

**Relationships**
- Allies: Charlie (best friend), Dave (romantic interest)
- Rivals: Bob the Mayor (political tension), Eve (different vision for town)
- Neutral: Frank
- Romantic: Dreams about Dave but hasn't confessed

**Starting State**
- Initial Relationship with Player: 5 (neutral, curious)
- Known Rumors: ["rumor_mayor_blocking_event", "rumor_mysterious_visitor_town"]
- Mood: Excited but stressed

**Quest Hook**
- Quest: "Help me convince the mayor to approve the duck party"
- Reward: Exclusive event invitations, key connections to other NPCs
- Success: Relationship +25, becomes your agent with other NPCs
- Failure: Relationship -15, becomes withdrawn and hard to approach

**Dialogue Guidance**
- Greeting: "Oh! Thank goodness you're here! Have you heard the latest? The mayor's being impossible about the duck party permit again..."
- Curious Topic: Will eagerly discuss the party plans, other NPCs' positions, logistics
- Turn-off: Doesn't want to hear criticism of her event planning
- Relationship Deltas:
  - "Your event planning is amazing!" → +5
  - Help convince the mayor → +20
  - Warn her about the mayor's concerns (helpful info) → +10
  - Spread rumor about her lack of organization → -25

```

---

## Rumor Template (for NPC profiles)

Each NPC might start with knowledge of certain rumors. Define them like:

```
["rumor_id"]: {
  "text": "The mayor has been secretly meeting with someone outside town...",
  "tags": ["politics", "mystery", "mayor"],
  "affects_npc_mood": true,  // Does knowing this change how they act?
  "spread_factor": 0.6,       // How likely to share with others (0.0 - 1.0)
  "npc_reaction": {           // How does knowing this rumor affect them?
    "alice": +5,              // Makes them like Alice more (thinks she's in the know)
    "bob": -10,               // Makes them distrust Bob
  }
}
```

---

## Prompting Tips for Gemini

When you send an NPC's profile to Gemini, structure it like:

```
You are roleplaying as {name}, {role} in a small duck-obsessed town.

Personality: {traits}
Speech pattern: {speech_pattern}
Current mood: {mood}

Relevant relationships:
- Alice (friend): [context]
- Bob (rival): [context]

Current rumors Alice knows about:
- {rumor_text}
- {rumor_text}

Player relationship with Alice: {score}/100
Player just said: "{player_message}"

Respond as Alice would, in character. Keep response under 100 words.
```

---

## Notes for Implementation

- **Consistency:** Each NPC should have a consistent "voice" across all interactions
- **Gossip:** Rumors should flow naturally based on NPCs' interests and relationships
- **Conflict:** Rivalry and alliance should create interesting dialogue branches
- **Growth:** Player actions should meaningfully change relationships
- **Mystery:** Some NPCs should hide secrets or lie about rumors to create intrigue

---

## Profile Checklist

Before finalizing an NPC:
- [ ] All identity fields filled
- [ ] Personality feels distinct from other NPCs
- [ ] Relationships create potential conflicts/alliances
- [ ] Quest hook is interesting and achievable
- [ ] Dialogue guidance feels authentic to personality
- [ ] Tested with Gemini prompt (if using backend)
