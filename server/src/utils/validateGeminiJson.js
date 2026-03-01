/**
 * Validation utility for Gemini API requests and responses
 */

function clampNumber(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

/**
 * Smart trim text at sentence boundary if exceeds max length
 * Only used as lightweight safeguard for gameplay readability
 * @param {string} text - Text to trim
 * @param {number} maxChars - Maximum character limit (default 500)
 * @returns {string} Trimmed text
 */
function smartTrimAtSentence(text, maxChars = 500) {
  if (!text || text.length <= maxChars) {
    return text;
  }

  console.log(`[smartTrimAtSentence] Text exceeds ${maxChars} chars (${text.length}), trimming at sentence boundary...`);

  // Find last sentence-ending punctuation before maxChars
  const truncated = text.substring(0, maxChars);
  const lastPeriod = truncated.lastIndexOf('.');
  const lastExclaim = truncated.lastIndexOf('!');
  const lastQuestion = truncated.lastIndexOf('?');
  
  const sentenceEnd = Math.max(lastPeriod, lastExclaim, lastQuestion);
  
  if (sentenceEnd > maxChars * 0.7) {
    // Good sentence break found (at least 70% of max length)
    const trimmed = text.substring(0, sentenceEnd + 1).trim();
    console.log(`[smartTrimAtSentence] Trimmed from ${text.length} to ${trimmed.length} chars at sentence boundary`);
    return trimmed;
  }

  // No good sentence break, trim at last space
  const lastSpace = truncated.lastIndexOf(' ');
  if (lastSpace > 0) {
    const trimmed = text.substring(0, lastSpace).trim();
    console.log(`[smartTrimAtSentence] Trimmed from ${text.length} to ${trimmed.length} chars at word boundary`);
    return trimmed;
  }

  // Last resort: hard cut with ellipsis
  console.log(`[smartTrimAtSentence] Hard cut from ${text.length} to ${maxChars} chars`);
  return truncated.trim() + '...';
}

function toSafeString(value) {
  if (typeof value === 'string') return value;
  if (value === null || value === undefined) return '';
  return String(value);
}

function sanitizeRumor(rumor) {
  if (!rumor || typeof rumor !== 'object' || Array.isArray(rumor)) {
    return null;
  }

  const text = toSafeString(rumor.text).trim();
  if (!text) {
    return null;
  }

  const tags = Array.isArray(rumor.tags)
    ? rumor.tags
      .filter(tag => typeof tag === 'string')
      .map(tag => tag.trim())
      .filter(Boolean)
    : [];

  const confidenceRaw = Number(rumor.confidence);
  const confidence = Number.isFinite(confidenceRaw)
    ? clampNumber(confidenceRaw, 0, 1)
    : 0.5;

  return {
    text: text.substring(0, 240),
    tags,
    confidence
  };
}

function sanitizeQuestProgress(questProgress) {
  if (!questProgress || typeof questProgress !== 'object' || Array.isArray(questProgress)) {
    return null;
  }

  const task = toSafeString(questProgress.task).trim();
  if (!task) {
    return null;
  }

  const allowedStatus = new Set(['hint', 'progress', 'complete']);
  const statusRaw = toSafeString(questProgress.status).trim().toLowerCase();
  const status = allowedStatus.has(statusRaw) ? statusRaw : 'hint';

  return {
    task: task.substring(0, 160),
    status
  };
}

/**
 * Normalize Gemini response into the backend response contract.
 * This is intentionally forgiving so legacy/partial payloads still work.
 * @param {Object} response - Parsed Gemini response object
 * @param {Object} options - Normalization options
 * @returns {Object} Normalized response
 */
function normalizeGeminiResponse(response, options = {}) {
  const fallbackReply = toSafeString(options.fallbackReply || "I... I don't know what to say.").trim() || "I... I don't know what to say.";
  const source = (response && typeof response === 'object' && !Array.isArray(response)) ? response : {};

  const npcReply = toSafeString(source.npc_reply).trim() || fallbackReply;
  const relationshipRaw = Number(source.relationship_delta);
  const relationshipDelta = Number.isFinite(relationshipRaw)
    ? clampNumber(Math.round(relationshipRaw), -50, 50)
    : 0;

  const npcMoodRaw = toSafeString(source.npc_mood_change).trim();
  const npcMood = npcMoodRaw || 'neutral';

  // Apply smart trimming only as lightweight safeguard (prefer not trimming)
  const finalReply = smartTrimAtSentence(npcReply, 500);
  
  // Log character length for verification
  console.log(`[VERIFY] npc_reply chars=${finalReply.length}`);
  if (finalReply.length !== npcReply.length) {
    console.warn(`[normalizeGeminiResponse] Reply was trimmed from ${npcReply.length} to ${finalReply.length} chars`);
  }

  return {
    success: true,
    npc_reply: finalReply,
    relationship_delta: relationshipDelta,
    rumor: sanitizeRumor(source.rumor),
    quest_progress: sanitizeQuestProgress(source.quest_progress),
    npc_mood_change: npcMood.substring(0, 64)
  };
}

/**
 * Validate incoming request from game client
 * @param {Object} request - The request body
 * @returns {Object|null} Error object if invalid, null if valid
 */
function validateRequest(request) {
  const errors = {
    missing_fields: [],
    invalid_fields: []
  };
  
  // Check required fields
  const requiredFields = ['npc_id', 'npc_name', 'player_message'];
  
  for (const field of requiredFields) {
    if (!(field in request)) {
      errors.missing_fields.push(field);
    }
  }
  
  // Check field types and values
  if (request.npc_id && typeof request.npc_id !== 'string') {
    errors.invalid_fields.push({
      field: 'npc_id',
      reason: 'must be a string'
    });
  }
  
  if (request.npc_name && typeof request.npc_name !== 'string') {
    errors.invalid_fields.push({
      field: 'npc_name',
      reason: 'must be a string'
    });
  }
  
  if (request.player_message && typeof request.player_message !== 'string') {
    errors.invalid_fields.push({
      field: 'player_message',
      reason: 'must be a string'
    });
  }
  
  if (request.player_message && request.player_message.length === 0) {
    errors.invalid_fields.push({
      field: 'player_message',
      reason: 'cannot be empty'
    });
  }
  
  if ('player_relationship' in request) {
    if (typeof request.player_relationship !== 'number') {
      errors.invalid_fields.push({
        field: 'player_relationship',
        reason: 'must be a number'
      });
    } else if (request.player_relationship < -100 || request.player_relationship > 100) {
      errors.invalid_fields.push({
        field: 'player_relationship',
        reason: 'must be between -100 and 100'
      });
    }
  }
  
  if (request.dialogue_history && !Array.isArray(request.dialogue_history)) {
    errors.invalid_fields.push({
      field: 'dialogue_history',
      reason: 'must be an array'
    });
  }
  
  if (request.dialogue_history && request.dialogue_history.length > 20) {
    errors.invalid_fields.push({
      field: 'dialogue_history',
      reason: 'exceeds maximum length (20 messages)'
    });
  }
  
  if (request.known_rumors && !Array.isArray(request.known_rumors)) {
    errors.invalid_fields.push({
      field: 'known_rumors',
      reason: 'must be an array'
    });
  }
  
  // Return null if valid, error object if invalid
  if (errors.missing_fields.length === 0 && errors.invalid_fields.length === 0) {
    return null;
  }
  
  return errors;
}

/**
 * Validate Gemini API response
 * @param {Object} response - The Gemini response
 * @returns {Object|null} Error object if invalid, null if valid
 */
function validateResponse(response) {
  const errors = {
    missing_fields: [],
    schema_violations: []
  };
  
  if (!response) {
    errors.missing_fields.push('entire response');
    return errors;
  }
  
  // Check required field: npc_reply
  if (!('npc_reply' in response)) {
    errors.missing_fields.push('npc_reply');
  }
  
  // Validate npc_reply type and length
  if (response.npc_reply !== undefined) {
    if (typeof response.npc_reply !== 'string') {
      errors.schema_violations.push({
        field: 'npc_reply',
        expected: 'string',
        received: typeof response.npc_reply
      });
    }
    
    if (response.npc_reply.length === 0) {
      errors.schema_violations.push({
        field: 'npc_reply',
        reason: 'cannot be empty string'
      });
    }
    
    if (response.npc_reply.length > 300) {
      errors.schema_violations.push({
        field: 'npc_reply',
        reason: `exceeds maximum length (300 chars, got ${response.npc_reply.length})`
      });
    }
  }
  
  // Validate optional fields
  
  if (response.relationship_delta !== undefined) {
    if (typeof response.relationship_delta !== 'number' || !Number.isInteger(response.relationship_delta)) {
      errors.schema_violations.push({
        field: 'relationship_delta',
        expected: 'integer',
        received: typeof response.relationship_delta
      });
    }
    
    if (response.relationship_delta < -50 || response.relationship_delta > 50) {
      errors.schema_violations.push({
        field: 'relationship_delta',
        reason: 'must be between -50 and 50'
      });
    }
  }
  
  if (response.rumor !== undefined && response.rumor !== null) {
    if (typeof response.rumor !== 'object') {
      errors.schema_violations.push({
        field: 'rumor',
        expected: 'object or null',
        received: typeof response.rumor
      });
    } else {
      // Validate rumor sub-fields
      if (!('text' in response.rumor)) {
        errors.schema_violations.push({
          field: 'rumor.text',
          reason: 'required if rumor is present'
        });
      }
      
      if (response.rumor.text && typeof response.rumor.text !== 'string') {
        errors.schema_violations.push({
          field: 'rumor.text',
          expected: 'string',
          received: typeof response.rumor.text
        });
      }
      
      if (response.rumor.tags && !Array.isArray(response.rumor.tags)) {
        errors.schema_violations.push({
          field: 'rumor.tags',
          expected: 'array',
          received: typeof response.rumor.tags
        });
      }
      
      if (response.rumor.confidence !== undefined && typeof response.rumor.confidence !== 'number') {
        errors.schema_violations.push({
          field: 'rumor.confidence',
          expected: 'number',
          received: typeof response.rumor.confidence
        });
      }
    }
  }

  if (response.quest_progress !== undefined && response.quest_progress !== null) {
    if (typeof response.quest_progress !== 'object' || Array.isArray(response.quest_progress)) {
      errors.schema_violations.push({
        field: 'quest_progress',
        expected: 'object or null',
        received: typeof response.quest_progress
      });
    } else {
      if (!('task' in response.quest_progress) || typeof response.quest_progress.task !== 'string' || response.quest_progress.task.length === 0) {
        errors.schema_violations.push({
          field: 'quest_progress.task',
          reason: 'required non-empty string if quest_progress is present'
        });
      }

      if (!('status' in response.quest_progress) || typeof response.quest_progress.status !== 'string') {
        errors.schema_violations.push({
          field: 'quest_progress.status',
          reason: 'required string if quest_progress is present'
        });
      }
    }
  }
  
  if (response.npc_mood_change !== undefined && response.npc_mood_change !== null) {
    if (typeof response.npc_mood_change !== 'string') {
      errors.schema_violations.push({
        field: 'npc_mood_change',
        expected: 'string or null',
        received: typeof response.npc_mood_change
      });
    }
  }
  
  // Return null if valid, error object if invalid
  if (errors.missing_fields.length === 0 && errors.schema_violations.length === 0) {
    return null;
  }
  
  return errors;
}

module.exports = {
  validateRequest,
  validateResponse,
  normalizeGeminiResponse
};
