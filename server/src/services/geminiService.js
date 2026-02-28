const { GoogleGenerativeAI } = require('@google/generative-ai');

// TODO: Initialize Gemini client from environment
const initializeGemini = () => {
  const apiKey = process.env.GEMINI_API_KEY;
  
  if (!apiKey) {
    const err = new Error('GEMINI_API_KEY is not set in environment');
    err.code = 'GEMINI_API_KEY_MISSING';
    throw err;
  }
  
  try {
    return new GoogleGenerativeAI(apiKey);
  } catch (error) {
    const err = new Error('Failed to initialize Gemini client: ' + error.message);
    err.code = 'GEMINI_INIT_ERROR';
    throw err;
  }
};

let geminiClient;

try {
  geminiClient = initializeGemini();
  console.log('[GeminiService] Gemini API client initialized');
} catch (error) {
  console.warn('[GeminiService] Failed to initialize Gemini:', error.message);
  geminiClient = null;
}

/**
 * Call the Gemini API to generate NPC dialogue
 * @param {Object} gameRequest - Request from Godot game
 * @returns {Promise<Object>} Response with NPC dialogue and game state updates
 */
async function callGemini(gameRequest) {
  if (!geminiClient) {
    const err = new Error('Gemini client not initialized');
    err.code = 'GEMINI_API_ERROR';
    throw err;
  }
  
  const {
    npc_id,
    npc_name,
    npc_personality,
    player_message,
    player_relationship,
    dialogue_history = [],
    known_rumors = [],
    town_context = {}
  } = gameRequest;
  
  try {
    // Build the system prompt that defines NPC behavior
    const systemPrompt = buildSystemPrompt(
      npc_name,
      npc_personality,
      player_relationship,
      known_rumors
    );
    
    // Build conversation history for context
    const conversationHistory = buildConversationHistory(dialogue_history);
    
    // Prepare the message to send to Gemini
    const userMessage = buildUserMessage(player_message, player_relationship);
    
    console.log(`[GeminiService] Calling Gemini for ${npc_name}...`);
    
    // TODO: Make actual Gemini API call
    // For now, return a placeholder response
    // In production, this would be:
    // const model = geminiClient.getGenerativeModel({ model: 'gemini-2.0-flash' });
    // const result = await model.generateContent([...conversationHistory, userMessage]);
    
    const response = await callGeminiAPI(systemPrompt, conversationHistory, userMessage);
    
    console.log(`[GeminiService] Gemini responded for ${npc_name}`);
    
    return response;
    
  } catch (error) {
    console.error('[GeminiService] Error calling Gemini:', error.message);
    
    if (error.code === 'GEMINI_API_KEY_MISSING') {
      throw error;
    }
    
    const err = new Error('Gemini API call failed: ' + error.message);
    err.code = 'GEMINI_API_ERROR';
    throw err;
  }
}

/**
 * Actually call the Gemini API
 * TODO: Remove placeholder and implement real API call
 */
async function callGeminiAPI(systemPrompt, conversationHistory, userMessage) {
  // TODO: Implement actual Gemini API call
  // This is a placeholder that returns validation-passing response
  
  // Get the model
  // const model = geminiClient.getGenerativeModel({ model: 'gemini-2.0-flash' });
  // const result = await model.generateContent([...conversationHistory, userMessage]);
  
  // For now, return placeholder response that passes validation
  return {
    success: true,
    npc_reply: "TODO: Implement Gemini API call in callGeminiAPI(). This is a placeholder response.",
    relationship_delta: 0,
    rumor: null,
    quest_progress: null,
    npc_mood_change: "neutral",
    metadata: {
      model_used: "gemini-2.0-flash",
      tokens_used: 0
    }
  };
}

/**
 * Build system prompt that defines NPC personality and constraints
 */
function buildSystemPrompt(npcName, personality, relationship, rumors) {
  const { traits = [], speech_pattern = "natural", current_mood = "neutral" } = personality;
  
  const relationshipContext = relationship > 50 ? "likes the player" :
                              relationship > 0 ? "is neutral with the player" :
                              relationship > -50 ? "doesn't trust the player" :
                              "dislikes the player";
  
  return `You are roleplaying as ${npcName} in a small duck-obsessed town.

Personality Traits: ${traits.join(", ") || "unknown"}
Speech Pattern: ${speech_pattern}
Current Mood: ${current_mood}
Relationship with Player: ${relationship}/100 (${relationshipContext})

Your known rumors about town:
${rumors.map((r, i) => `${i + 1}. "${r.text}" (tags: ${r.tags?.join(", ")})`).join("\n") || "- None"}

IMPORTANT INSTRUCTIONS:
1. Respond in character, brief and natural (under 150 characters)
2. Your response MUST be valid JSON with these exact fields:
   - npc_reply: Your character's dialogue (string, required)
   - rumor: Optional new rumor (object with: text, tags, confidence)
   - relationship_delta: Change to player relationship (-50 to 50, integer)
   - quest_progress: Optional quest update (object)
   - npc_mood_change: Your mood after this interaction (string)

3. JSON Format Example:
{
  "npc_reply": "That sounds interesting...",
  "rumor": {"text": "something I heard", "tags": ["gossip"], "confidence": 0.6},
  "relationship_delta": 5,
  "npc_mood_change": "curious"
}

4. ALWAYS return valid JSON, never plain text
5. If something doesn't make sense, politely decline in character`;
}

/**
 * Build conversation history from dialogue array
 */
function buildConversationHistory(dialogueHistory) {
  // TODO: Format dialogue history for Gemini API
  // Each message should be formatted as { role: "user"|"assistant", content: "text" }
  
  return dialogueHistory.map(msg => ({
    role: msg.role === "player" ? "user" : "assistant",
    parts: [{ text: msg.text }]
  }));
}

/**
 * Build the current user message
 */
function buildUserMessage(playerMessage, relationship) {
  return {
    role: "user",
    parts: [
      { 
        text: `Player says: "${playerMessage}"\n\nRespond as your character. Remember to return valid JSON.`
      }
    ]
  };
}

module.exports = {
  callGemini
};
