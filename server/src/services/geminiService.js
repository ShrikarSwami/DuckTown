const { GoogleGenerativeAI } = require('@google/generative-ai');

const DEFAULT_GEMINI_MODEL = process.env.GEMINI_MODEL || 'gemini-2.5-flash';

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
    player_name = 'Player',
    player_relationship,
    dialogue_history = [],
    known_rumors = [],
    active_tasks = [],
    town_context = {}
  } = gameRequest;
  
  try {
    // Build the system prompt that defines NPC behavior
    const systemPrompt = buildSystemPrompt(
      npc_name,
      npc_personality,
      player_relationship,
      known_rumors,
      active_tasks,
      town_context
    );
    
    // Build conversation history for context
    const conversationHistory = buildConversationHistory(dialogue_history);
    
    // Prepare the message to send to Gemini
    const userMessage = buildUserMessage(player_message, player_relationship, player_name, active_tasks, town_context);
    
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
    err.httpStatus = error.httpStatus || null;
    err.upstreamMessage = error.upstreamMessage || error.message;
    throw err;
  }
}

/**
 * Actually call the Gemini API
 * Calls Google's Gemini 2.0 Flash model and parses JSON response
 */
async function callGeminiAPI(systemPrompt, conversationHistory, userMessage) {
  if (!geminiClient) {
    throw new Error('Gemini client not initialized');
  }
  
  try {
    const modelName = DEFAULT_GEMINI_MODEL;
    const endpointBase = 'https://generativelanguage.googleapis.com';
    const endpointPath = `/v1beta/models/${modelName}:generateContent`;
    const endpointUrl = `${endpointBase}${endpointPath}`;

    // Get the Gemini model
    const model = geminiClient.getGenerativeModel({ model: modelName });
    
    // Build the full message array with system prompt as first message
    const messages = [
      {
        role: "user",
        parts: [{ text: systemPrompt }]
      },
      ...conversationHistory,
      userMessage
    ];
    
    console.log(`[callGeminiAPI] Sending request to Gemini with ${conversationHistory.length} history messages`);
    console.log(`[callGeminiAPI] Request URL: ${endpointUrl}`);
    console.log(`[callGeminiAPI] Model: ${modelName}`);
    console.log(`[callGeminiAPI] GEMINI_API_KEY present: ${Boolean(process.env.GEMINI_API_KEY)} (length=${(process.env.GEMINI_API_KEY || '').length})`);
    
    // Call the Gemini API
    const result = await model.generateContent({
      contents: messages,
      generationConfig: {
        responseMimeType: 'application/json',
        maxOutputTokens: 300,
        temperature: 0.8
      }
    });
    
    // Extract the text response
    const responseText = result.response.text();
    console.log(`[callGeminiAPI] Raw Gemini response: ${responseText.substring(0, 200)}...`);
    
    // Parse JSON from the response
    const parsedResponse = extractAndParseJSON(responseText);
    
    if (!parsedResponse) {
      console.warn('[callGeminiAPI] Failed to extract JSON from response, using fallback');
      return buildFallbackResponse(responseText);
    }
    
    // Ensure required fields exist
    const validatedResponse = {
      success: true,
      npc_reply: parsedResponse.npc_reply || "...",
      relationship_delta: parseInt(parsedResponse.relationship_delta) || 0,
      rumor: parsedResponse.rumor || null,
      quest_progress: parsedResponse.quest_progress || null,
      npc_mood_change: parsedResponse.npc_mood_change || "neutral"
    };
    
    console.log(`[callGeminiAPI] Successfully parsed Gemini response`);
    return validatedResponse;
    
  } catch (error) {
    const rawMessage = error?.message || '';
    const statusMatch = rawMessage.match(/\[(\d{3})\s[^\]]+\]/);
    const parsedStatusCode = statusMatch ? parseInt(statusMatch[1], 10) : null;
    const statusCode = parsedStatusCode || error?.status || error?.statusCode || error?.response?.status || null;
    const responseBody = error?.response?.data || error?.errorDetails || error?.details || error?.body || rawMessage || null;
    const networkCode = error?.code || null;

    console.error('[callGeminiAPI] Error calling Gemini API:', error.message);
    console.error('[callGeminiAPI] Error diagnostics:', {
      statusCode,
      networkCode,
      message: error?.message || null,
      responseBody
    });

    error.httpStatus = statusCode;
    error.upstreamMessage = rawMessage;
    throw error;
  }
}

/**
 * Extract and parse JSON from Gemini response text
 * Handles cases where Gemini wraps JSON in markdown code blocks
 */
function extractAndParseJSON(responseText) {
  if (!responseText) return null;
  
  try {
    // Try 1: Direct JSON parse (response is pure JSON)
    try {
      return JSON.parse(responseText);
    } catch (e) {
      // Continue to next attempt
    }
    
    // Try 2: Extract from markdown code block
    const jsonMatch = responseText.match(/```json\s*([\s\S]*?)\s*```/);
    if (jsonMatch && jsonMatch[1]) {
      return JSON.parse(jsonMatch[1]);
    }
    
    // Try 3: Extract from plain code block
    const codeMatch = responseText.match(/```\s*([\s\S]*?)\s*```/);
    if (codeMatch && codeMatch[1]) {
      return JSON.parse(codeMatch[1]);
    }
    
    // Try 4: Find JSON object using braces
    const braceStart = responseText.indexOf('{');
    const braceEnd = responseText.lastIndexOf('}');
    if (braceStart !== -1 && braceEnd !== -1 && braceEnd > braceStart) {
      const jsonString = responseText.substring(braceStart, braceEnd + 1);
      return JSON.parse(jsonString);
    }
    
    return null;
    
  } catch (error) {
    console.warn(`[extractAndParseJSON] Failed to parse: ${error.message}`);
    return null;
  }
}

/**
 * Build a fallback response when JSON parsing fails
 * Extracts what we can from the response text
 */
function buildFallbackResponse(responseText) {
  console.warn('[buildFallbackResponse] Using fallback response structure');
  
  return {
    success: true,
    npc_reply: responseText.substring(0, 200) || "I... I don't know what to say.",
    relationship_delta: 0,
    rumor: null,
    quest_progress: null,
    npc_mood_change: "confused"
  };
}

/**
 * Build system prompt that defines NPC personality and constraints
 * Emphasizes JSON response format to maximize model compliance
 */
function buildSystemPrompt(npcName, personality, relationship, rumors, activeTasks = [], townContext = {}) {
  const { traits = [], speech_pattern = "natural", current_mood = "neutral" } = personality;
  const openTasks = Array.isArray(activeTasks) ? activeTasks : [];
  const demoFocus = Array.isArray(townContext?.demo_focus) ? townContext.demo_focus : ['baker', 'merch', 'guard'];
  const partyGoal = townContext?.party_goal || 'Help the mayor complete party prep by earning citizen approvals.';
  
  const relationshipContext = relationship > 50 ? "likes the player" :
                              relationship > 0 ? "is neutral with the player" :
                              relationship > -50 ? "doesn't trust the player" :
                              "dislikes the player";
  
  return `ROLE: You are ${npcName} in DuckTown.
Traits: ${traits.join(", ") || "unknown"}
Speech: ${speech_pattern}
Current Mood: ${current_mood}
Player Relationship: ${relationship}/100 (${relationshipContext})
PRIMARY GAME GOAL: ${partyGoal}
CURRENT ACTIVE TASKS:
${openTasks.length > 0 ? openTasks.map((t, i) => `${i + 1}. ${t}`).join("\n") : "No explicit tasks provided"}
DEMO FOCUS NPCS (can change per demo): ${demoFocus.join(', ')}

KNOWN RUMORS:
${rumors && rumors.length > 0 ? rumors.map((r, i) => `${i + 1}. "${r.text}" (${r.tags?.join(", ") || "general"})`).join("\n") : "None yet"}

TASK: Generate one useful, in-character line that helps or reacts to task progress.
Aim to nudge the player toward concrete next steps, approvals, or actionable rumors.

RESPONSE FORMAT - OUTPUT ONLY VALID JSON, NO EXTRA TEXT:
{
  "npc_reply": "Your dialogue here",
  "relationship_delta": 0,
  "rumor": null,
  "quest_progress": null,
  "npc_mood_change": "neutral"
}

RULES:
1. Return ONLY a single JSON object.
2. npc_reply must be <= 160 chars, specific, and in-character.
3. relationship_delta must be an integer from -10 to 10.
4. rumor can be null OR {"text": "...", "tags": ["task|npc|event"], "confidence": 0.0-1.0}.
5. quest_progress can be null OR {"task": "...", "status": "hint|progress|complete"}.
6. npc_mood_change must be a single mood word.
7. Avoid generic filler. Tie response to current tasks when possible.
8. Never output markdown/code fences.`;
}

/**
 * Build conversation history from dialogue array
 */
function buildConversationHistory(dialogueHistory) {
  // TODO: Format dialogue history for Gemini API
  // Each message should be formatted as { role: "user"|"assistant", content: "text" }
  
  return dialogueHistory.map(msg => ({
    role: msg.role === "player" ? "user" : "model",
    parts: [{ text: msg.text }]
  }));
}

/**
 * Build the current user message
 */
function buildUserMessage(playerMessage, relationship, playerName = 'Player', activeTasks = [], townContext = {}) {
  const tasksText = Array.isArray(activeTasks) && activeTasks.length > 0
    ? activeTasks.map((task, index) => `${index + 1}) ${task}`).join('\n')
    : 'No active tasks provided';

  const contextSummary = JSON.stringify({
    demo_focus: townContext?.demo_focus || null,
    party_goal: townContext?.party_goal || null,
    completed_tasks: townContext?.completed_tasks || []
  });

  return {
    role: "user",
    parts: [
      { 
        text: `Player name: ${playerName}\nPlayer says: "${playerMessage}"\nRelationship score: ${relationship}\nActive tasks:\n${tasksText}\nTown context: ${contextSummary}\n\nReturn one valid JSON object only.`
      }
    ]
  };
}

module.exports = {
  callGemini
};
