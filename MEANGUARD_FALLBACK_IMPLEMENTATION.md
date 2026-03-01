# Mean Guard Deterministic Fallback Implementation

## Feature
Auto-approve **meanGuard only** after **3 completed dialogue interactions** during a single game run.
- Trust is set to **30 minimum** (well above approval threshold of 15)
- Counter resets on game restart
- Only counts completed dialogue sends (when response is received)

## Implementation Details

### Location: `game/scripts/npc_interaction.gd`

#### 1. **Counter Variable** (Line 31)
```gdscript
# Deterministic fallback for Mean Guard: count dialogue sends (completed interactions)
# Resets naturally when game restarts (new scene, new node instance)
var _meanGuard_dialogue_send_count: int = 0
```

**Where it lives:**
- Initialized as `0` at script start (line 31)
- Per-NPC instance (created fresh for each scene/game run)
- **Resets automatically** when game restarts because a new node instance is created

---

#### 2. **Counter Increment: In `_on_gemini_response()`** (Lines 444-458)
Called when **Gemini API response is received successfully**:
```gdscript
# ===== DETERMINISTIC FALLBACK: Count dialogue send & auto-approve meanGuard after 3 =====
if npc_id == "meanGuard":
    _meanGuard_dialogue_send_count += 1
    print("[MeanGuardFallback] Dialogue send #%d completed" % _meanGuard_dialogue_send_count)
    
    # After 3 completed dialogue sends, auto-approve meanGuard
    if _meanGuard_dialogue_send_count >= 3 and current_relationship < 30:
        print("[MeanGuardFallback] ⭐ 3 dialogue sends REACHED! Auto-approving meanGuard")
        var delta_to_approval = 30 - current_relationship
        update_relationship(delta_to_approval)
        
        # Update UI with new trust
        if dialogue_ui != null and dialogue_ui.has_method("update_trust_display"):
            dialogue_ui.update_trust_display(current_relationship)
```

**Activation points:**
- Only increments for `npc_id == "meanGuard"` ✓
- Auto-approves when counter reaches **3** ✓
- Sets trust to minimum **30** (approval threshold is 15) ✓

---

#### 3. **Counter Increment: In `_show_fallback_response()`** (Lines 507-521)
Called when **Gemini fails** or other error conditions:
```gdscript
# ===== DETERMINISTIC FALLBACK: Count dialogue send & auto-approve meanGuard after 3 =====
if npc_id == "meanGuard":
    _meanGuard_dialogue_send_count += 1
    print("[MeanGuardFallback] Dialogue send #%d completed (fallback)" % _meanGuard_dialogue_send_count)
    
    # After 3 completed dialogue sends, auto-approve meanGuard
    if _meanGuard_dialogue_send_count >= 3 and current_relationship < 30:
        print("[MeanGuardFallback] ⭐ 3 dialogue sends REACHED! Auto-approving meanGuard")
        var delta_to_approval = 30 - current_relationship
        update_relationship(delta_to_approval)
        
        # Update UI with new trust
        if dialogue_ui != null and dialogue_ui.has_method("update_trust_display"):
            dialogue_ui.update_trust_display(current_relationship)
```

**Ensures fallback responses also count** as dialogue interactions ✓

---

## How It Works

### Flow Diagram
```
Player sends message to meanGuard
    ↓
start_dialogue() called
    ↓
Gemini API request sent
    ↓
┌─────────────────────────────┐
│ Response received (success)  │  OR  │ Gemini fails (error)  │
└─────────────────────────────┘
    ↓
_on_gemini_response()         OR  _show_fallback_response()
    ↓
[MeanGuardFallback] Dialogue send #N completed
    ↓
IF N >= 3 AND trust < 30:
    ↓
Auto-approve: trust = 30
UI updates green
[MeanGuardFallback] ⭐ 3 dialogue sends REACHED!
```

### Count Resets
- **On game restart:** Counter resets to 0 automatically
  - New game scene loads → new `npc_interaction` node created → `_meanGuard_dialogue_send_count = 0`
- **Other NPCs:** Unaffected (check only for `meanGuard`)
- **Multiple runs:** Each run has independent counter

---

## Rules Enforced

✅ **Only for meanGuard**
- Line 445: `if npc_id == "meanGuard"`
- Line 507: `if npc_id == "meanGuard"`

✅ **Count completed dialogue sends**
- Incremented in `_on_gemini_response()` (successful API response)
- Incremented in `_show_fallback_response()` (error fallback)
- Only after full response processing & UI update

✅ **Reset on game restart**
- Counter is instance variable `_meanGuard_dialogue_send_count: int = 0`
- New scene = new node instance = counter reset to 0

✅ **Trust set to 30 minimum**
- Line 451: `if _meanGuard_dialogue_send_count >= 3 and current_relationship < 30:`
- Line 452: `var delta_to_approval = 30 - current_relationship`
- Only applies if current trust is below 30

---

## Test Cases

| Scenario | Result |
|----------|--------|
| 1st dialogue with meanGuard | Counter = 1, no approval |
| 2nd dialogue with meanGuard | Counter = 2, no approval |
| 3rd dialogue with meanGuard | Counter = 3, **AUTO-APPROVED** ✓ |
| Talk to baker/merch | Their counters unchanged |
| Same interaction, Gemini fails | Fallback path increments counter |
| Game restarts (new scene) | Counter resets to 0 |

---

## Dependencies

- `dialogue_ui` for trust display update
- `update_relationship()` to apply trust delta
- `relationship_changed` signal emitted automatically by `update_relationship()`

## Log Output Examples

**Normal flow:**
```
[MeanGuardFallback] Dialogue send #1 completed
[MeanGuardFallback] Dialogue send #2 completed
[MeanGuardFallback] Dialogue send #3 completed
[MeanGuardFallback] ⭐ 3 dialogue sends REACHED! Auto-approving meanGuard
[NPC meanGuard] Relationship: 5 → 30 (delta: +25)
```

**Fallback flow:**
```
[MeanGuardFallback] Dialogue send #1 completed (fallback)
[MeanGuardFallback] Dialogue send #2 completed (fallback)
[MeanGuardFallback] Dialogue send #3 completed (fallback)
[MeanGuardFallback] ⭐ 3 dialogue sends REACHED! Auto-approving meanGuard
```
