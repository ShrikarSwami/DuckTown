# NPC Profiles Template (Duck Party Rumor Game)

These profiles are used for:
1) consistent dialogue generation (Gemini)
2) relationship and rumor mechanics (game logic)
3) quest gating for the Duck Party objective

Keep everything short and structured. Use IDs with no spaces.

---

## 1) NPC Profile Fields

### A) Identity
- **NPC ID:** `snake_case_id`
- **Name:** Display name
- **Role:** Mayor, Rival Organizer, Baker, Merch and Decor, Nice Guard, Mean Guard, Musician, Mom Gossip, Duck Historian, Coder
- **Age Group:** Teen, Adult, Elder
- **Location Tag:** where they usually stand (town_square, bakery, hall, etc)

### B) Voice
- **One Line Vibe:** how they feel instantly
- **Speech Style:** formal, blunt, dramatic, nonchalant, frantic, etc
- **Verbal Ticks:** 1 to 2 phrases they repeat (optional)

### C) Personality
- **Core Traits:** 3 to 5 traits
- **Motivation:** why they care about the Duck Party
- **Pressure Point:** what makes them fold or react strongly
- **Deal Breakers:** 1 to 3 topics or people that trigger refusal

### D) Relationships (Use NPC IDs)
- **Friend:** `npc_id`
- **Rival:** `npc_id`
- **Secret Respect:** `npc_id`
- **Notes:** one sentence explaining why each matters

### E) Secrets
- **Mild Secret:** safe, funny, or awkward
- **Spicy Secret:** higher stakes but still safe for a hackathon
- **Secret Enemy Toggle:** true or false  
  - If true: increase convince difficulty by +3 and decrease rumor accuracy by 10 percent

### F) Rumor Behavior
- **Rumor Accuracy Range:** `0.0 to 1.0` (example: 0.4 to 0.6)
- **Spread Style:** hoards, overshares, selective, exaggerates, weaponizes
- **Favorite Tags:** 2 to 4 tags they care about (duck, politics, drama, safety, music, etc)

### G) Player Relationship
- **Initial Relationship Score:** -50 to 50
- **Trust Threshold:** low, medium, high, extremely_high  
  - Low: 2 points  
  - Medium: 4 points  
  - High: 6 points  
  - Extremely high: 10 points

### H) Party Contribution (Quest Gate)
- **What They Control:** what they can block or unlock (cupcakes, signs, venue approval, safety approval, music, decor, mayor approval)
- **Requirement To Approve:** what must be true (relationship points, remove rival from invite list, fix rumor, etc)
- **Failure Reaction:** what they do if player fails (spread rumor, refuse, raise suspicion, switch sides)

### I) Interaction Set
- **Greeting Line Example:** 1 line
- **Refusal Line Example:** 1 line
- **If Asked About Ducks:** 1 line
- **If Asked About The Incident:** 1 line
- **If Presented A Rumor They Care About:** 1 line

---

## 2) Relationship Point System (Standard Actions)

Use these defaults unless overridden per NPC:

- **Compliment aligned with their values:** +1 point
- **Share useful info they care about:** +2 points
- **Help their party task:** +3 points
- **Fix a negative rumor about them:** +3 points
- **Invite or exclude their deal breaker correctly:** +2 points
- **Lie and get caught:** -4 points
- **Spread a false rumor about them:** -5 points

---

## 3) Rumor Template

Each rumor is a small object with tags and an optional gameplay effect.

- **Rumor ID:** `rumor_snake_case`
- **Text:** one sentence
- **Tags:** 2 to 4 tags
- **Target NPC ID:** optional
- **Spread Factor:** 0.0 to 1.0 (how fast it spreads)
- **Effect:** optional
  - relationship delta on certain NPCs
  - suspicion or town mood change
  - blocks or unlocks an approval

Example:

`rumor_old_mayor_son`:
- text: "The new mayor is connected to the old mayor somehow."
- tags: politics, scandal
- target: `mayor`
- spread_factor: 0.6
- effect:
  - mayor_relationship: -2 points
  - town_suspicion: +5

---

## 4) Gemini Prompt Pack (Per Interaction)

When calling Gemini, send:

- NPC profile (condensed)
- current invite list (who is invited)
- current known rumors (top 3 relevant)
- player relationship score and points
- the player message
- required output schema

---

## 5) Required Output Schema From Gemini (Strict)

Gemini must return valid JSON only:

- **npc_reply:** string (max 80 words)
- **rumor_created:** object or null
  - id, text, tags, target_npc_id, spread_factor
- **relationship_points_delta:** integer (negative allowed)
- **approval_delta:** object
  - cupcakes_approved, signs_approved, venue_approved, safety_approved, music_approved, decor_approved, mayor_approved (true, false, or null)
- **next_rumor_target_npc_id:** string or null
- **tone_tag:** one of: friendly, suspicious, angry, stressed, smug, neutral

If JSON is invalid, the backend rejects it and requests a retry.

---

## 6) Blank NPC Profile (Fill This In)

### {Name} ({npc_id})

**Identity**
- NPC ID:
- Name:
- Role:
- Age Group:
- Location Tag:

**Voice**
- One Line Vibe:
- Speech Style:
- Verbal Ticks:

**Personality**
- Core Traits:
- Motivation:
- Pressure Point:
- Deal Breakers:

**Relationships**
- Friend:
- Rival:
- Secret Respect:
- Notes:

**Secrets**
- Mild Secret:
- Spicy Secret:
- Secret Enemy Toggle:

**Rumor Behavior**
- Rumor Accuracy Range:
- Spread Style:
- Favorite Tags:

**Player Relationship**
- Initial Relationship Score:
- Trust Threshold:

**Party Contribution**
- What They Control:
- Requirement To Approve:
- Failure Reaction:

**Interaction Set**
- Greeting Line Example:
- Refusal Line Example:
- If Asked About Ducks:
- If Asked About The Incident:
- If Presented A Rumor They Care About: