const { GoogleGenerativeAI } = require('@google/generative-ai');
const { normalizeGeminiResponse } = require('../utils/validateGeminiJson');

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
    town_context = {},
    demo_context = {}
  } = gameRequest;
  
  try {
    // Build the system prompt that defines NPC behavior
    const systemPrompt = buildSystemPrompt(
      npc_name,
      npc_personality,
      player_relationship,
      known_rumors,
      active_tasks,
      town_context,
      demo_context
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
        maxOutputTokens: 800,
        temperature: 0.7
      }
    });
    
    // Extract the text response
    const responseText = result.response.text();
    console.log(`[callGeminiAPI] Raw Gemini response: ${responseText.substring(0, 200)}...`);
    
    // Parse JSON from the response
    const extraction = extractAndParseJSON(responseText);

    if (!extraction.object) {
      console.warn('[callGeminiAPI] JSON extraction mode=fallback reason=no_valid_json_object');
      return buildFallbackResponse(responseText);
    }

    const normalizedResponse = normalizeGeminiResponse(extraction.object);
    console.log(`[callGeminiAPI] JSON extraction mode=clean method=${extraction.method}`);
    return normalizedResponse;
    
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
  if (typeof responseText !== 'string' || responseText.trim().length === 0) {
    return { object: null, method: 'none' };
  }

  const text = responseText.trim();

  const parseIfObject = (candidate, method) => {
    const parsed = parsePossiblyBrokenJSONObject(candidate);
    if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
      return { object: parsed, method };
    }
    return null;
  };

  // 1) Pure JSON response
  const direct = parseIfObject(text, 'direct');
  if (direct) {
    return direct;
  }

  // 2) JSON inside markdown fence blocks (```json ...``` or ``` ... ```)
  const fencedRegex = /```(?:json)?\s*([\s\S]*?)\s*```/gi;
  let fenceMatch = fencedRegex.exec(text);
  while (fenceMatch) {
    const fencedCandidate = (fenceMatch[1] || '').trim();
    const fencedParsed = parseIfObject(fencedCandidate, 'fenced');
    if (fencedParsed) {
      return fencedParsed;
    }

    const nested = extractFirstJSONObjectFromText(fencedCandidate);
    if (nested) {
      const nestedParsed = parseIfObject(nested, 'fenced_embedded_object');
      if (nestedParsed) {
        return nestedParsed;
      }
    }

    fenceMatch = fencedRegex.exec(text);
  }

  // 3) Mixed prose + JSON: extract first valid JSON object from raw text
  const firstObject = extractFirstJSONObjectFromText(text);
  if (firstObject) {
    const embeddedParsed = parseIfObject(firstObject, 'embedded_object');
    if (embeddedParsed) {
      return embeddedParsed;
    }
  }

  return { object: null, method: 'none' };
}

function extractFirstJSONObjectFromText(text) {
  if (typeof text !== 'string' || text.length === 0) return null;

  let startIndex = -1;
  let depth = 0;
  let inString = false;
  let isEscaped = false;

  for (let i = 0; i < text.length; i += 1) {
    const char = text[i];

    if (inString) {
      if (isEscaped) {
        isEscaped = false;
      } else if (char === '\\') {
        isEscaped = true;
      } else if (char === '"') {
        inString = false;
      }
      continue;
    }

    if (char === '"') {
      inString = true;
      continue;
    }

    if (char === '{') {
      if (depth === 0) {
        startIndex = i;
      }
      depth += 1;
      continue;
    }

    if (char === '}') {
      if (depth > 0) {
        depth -= 1;
        if (depth === 0 && startIndex !== -1) {
          const candidate = text.slice(startIndex, i + 1);
          const parsed = parsePossiblyBrokenJSONObject(candidate);
          if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
            return candidate;
          }
          startIndex = -1;
        }
      }
    }
  }

  return null;
}

function parsePossiblyBrokenJSONObject(candidate) {
  if (typeof candidate !== 'string') return null;
  const trimmed = candidate.trim();
  if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) {
    return null;
  }

  try {
    return JSON.parse(trimmed);
  } catch (_error) {
    // Attempt tolerant repair for common model formatting mistakes
  }

  const repaired = repairJsonLikeString(trimmed);
  if (!repaired) {
    return null;
  }

  try {
    return JSON.parse(repaired);
  } catch (_error) {
    return null;
  }
}

function repairJsonLikeString(jsonLike) {
  if (typeof jsonLike !== 'string' || jsonLike.length === 0) {
    return null;
  }

  const withoutTrailingCommas = jsonLike.replace(/,\s*([}\]])/g, '$1');

  let repaired = '';
  let inString = false;
  let isEscaped = false;

  for (let i = 0; i < withoutTrailingCommas.length; i += 1) {
    const char = withoutTrailingCommas[i];

    if (inString) {
      if (isEscaped) {
        repaired += char;
        isEscaped = false;
        continue;
      }

      if (char === '\\') {
        repaired += char;
        isEscaped = true;
        continue;
      }

      if (char === '"') {
        repaired += char;
        inString = false;
        continue;
      }

      if (char === '\n') {
        repaired += '\\n';
        continue;
      }

      if (char === '\r') {
        repaired += '\\r';
        continue;
      }

      if (char === '\t') {
        repaired += '\\t';
        continue;
      }

      repaired += char;
      continue;
    }

    if (char === '"') {
      inString = true;
      repaired += char;
      continue;
    }

    repaired += char;
  }

  return repaired;
}

/**
 * Build a fallback response when JSON parsing fails
 * Extracts what we can from the response text
 */
function buildFallbackResponse(responseText) {
  console.warn('[buildFallbackResponse] Using fallback response structure');

  let reply = "I... I don't know what to say.";
  if (typeof responseText === 'string' && responseText.trim().length > 0) {
    const quotedReplyMatch = responseText.match(/"npc_reply"\s*:\s*"([\s\S]*?)"/);
    if (quotedReplyMatch && quotedReplyMatch[1]) {
      reply = quotedReplyMatch[1];
    } else {
      const firstLine = responseText
        .replace(/[{}\[\]"]/g, ' ')
        .replace(/\s+/g, ' ')
        .trim()
        .split(/\n|\r/)[0]
        .trim();
      if (firstLine.length > 0) {
        reply = firstLine;
      }
    }
  }
  reply = reply.replace(/^npc_reply\s*:?\s*/i, '').trim();
  
  return normalizeGeminiResponse({
    npc_reply: reply.substring(0, 200),
    relationship_delta: 0,
    rumor: null,
    quest_progress: null,
    npc_mood_change: 'confused'
  });
}

/**
 * Build system prompt that defines NPC personality and constraints
 * Emphasizes JSON response format to maximize model compliance
 */
function buildSystemPrompt(npcName, personality, relationship, rumors, activeTasks = [], townContext = {}, demoContext = {}) {
  const { traits = [], speech_pattern = "natural", current_mood = "neutral" } = personality;
  const openTasks = Array.isArray(activeTasks) ? activeTasks : [];
  const demoFocus = Array.isArray(townContext?.demo_focus) ? townContext.demo_focus : ['baker', 'merch', 'guard'];
  const partyGoal = townContext?.party_goal || 'Help the mayor complete party prep by earning citizen approvals.';
  
  const relationshipContext = relationship > 50 ? "likes the player" :
                              relationship > 0 ? "is neutral with the player" :
                              relationship > -50 ? "doesn't trust the player" :
                              "dislikes the player";
  
  // Extract demo script instruction if present
  const scriptInstruction = demoContext?.script_instruction || '';
  const isScriptedTurn = demoContext?.is_scripted_turn === true;
  
  let demoConstraint = '';
  if (isScriptedTurn && scriptInstruction) {
    demoConstraint = `\n\n⚠️ CRITICAL DEMO SCRIPT REQUIREMENT ⚠️
THIS IS A SCRIPTED DEMO TURN. YOU MUST FOLLOW THIS EXACT INSTRUCTION:
${scriptInstruction}

FAILURE TO FOLLOW THIS INSTRUCTION WILL BREAK THE DEMO.
Your response will be validated against this requirement.
Stay under 160 characters and be natural, but MUST include the key elements specified above.`;
  }
  
  return `ROLE: You are ${npcName} in DuckTown.
Traits: ${traits.join(", ") || "unknown"}
Speech: ${speech_pattern}
Current Mood: ${current_mood}
Player Relationship: ${relationship}/100 (${relationshipContext})
PRIMARY GAME GOAL: ${partyGoal}
CURRENT ACTIVE TASKS:
${openTasks.length > 0 ? openTasks.map((t, i) => `${i + 1}. ${t}`).join("\n") : "No explicit tasks provided"}
DEMO FOCUS NPCS (can change per demo): ${demoFocus.join(', ')}${demoConstraint}

KNOWN RUMORS:
${rumors && rumors.length > 0 ? rumors.map((r, i) => `${i + 1}. "${r.text}" (${r.tags?.join(", ") || "general"})`).join("\n") : "None yet"}

TASK: Generate one useful, in-character line that helps or reacts to task progress.
Aim to nudge the player toward concrete next steps, approvals, or actionable rumors.

YOU MUST RESPOND WITH ONLY VALID JSON. NO MARKDOWN, NO CODE BLOCKS, NO EXTRA TEXT.
START YOUR RESPONSE WITH { AND END WITH }

REQUIRED JSON FORMAT:
{
  "npc_reply": "Your dialogue here",
  "relationship_delta": 0,
  "rumor": null,
  "quest_progress": null,
  "npc_mood_change": "neutral"
}

RULES:
1. Return ONLY a single JSON object starting with { and ending with }.
2. DO NOT wrap in markdown code blocks or triple-backtick json tags.
3. npc_reply must be <= 160 chars, specific, and in-character.
4. relationship_delta must be an integer from -10 to 10.
5. rumor can be null OR {"text": "...", "tags": ["task|npc|event"], "confidence": 0.0-1.0}.
6. quest_progress can be null OR {"task": "...", "status": "hint|progress|complete"}.
7. npc_mood_change must be a single mood word.
8. Avoid generic filler. Tie response to current tasks when possible.`;
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
