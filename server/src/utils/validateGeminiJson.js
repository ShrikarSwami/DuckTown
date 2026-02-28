/**
 * Validation utility for Gemini API requests and responses
 */

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
  validateResponse
};
