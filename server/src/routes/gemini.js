const express = require('express');
const router = express.Router();
const geminiService = require('../services/geminiService');
const validateGeminiJson = require('../utils/validateGeminiJson');

const DEFAULT_GEMINI_MODEL = process.env.GEMINI_MODEL || 'gemini-2.5-flash';

/**
 * POST /api/gemini
 * 
 * Generates NPC dialogue via Google Gemini API
 * 
 * Request body:
 * {
 *   npc_id: string,
 *   npc_name: string,
 *   npc_personality: { traits, speech_pattern, current_mood },
 *   player_message: string,
 *   player_relationship: int (-100 to 100),
 *   dialogue_history: Array<{role, text}>,
 *   known_rumors: Array<Object>
 * }
 * 
 * Response (200):
 * {
 *   success: true,
 *   npc_reply: string,
 *   relationship_delta: int,
 *   rumor: optional object,
 *   quest_progress: optional object,
 *   npc_mood_change: string,
 *   metadata: { model_used, tokens_used, processing_time_ms }
 * }
 */
router.post('/gemini', async (req, res) => {
  const startTime = Date.now();

  try {
    // Support two request formats:
    // A) { npc_id, npc_name, player_message, ... }
    // B) { prompt }
    // If Format B is provided, map it to Format A for compatibility.
    let requestBody = req.body;
    const hasFormatA =
      typeof requestBody?.npc_id === 'string' &&
      typeof requestBody?.npc_name === 'string' &&
      typeof requestBody?.player_message === 'string';

    const hasFormatB = typeof requestBody?.prompt === 'string';

    if (!hasFormatA && hasFormatB) {
      requestBody = {
        npc_id: 'npc_test',
        npc_name: 'Test NPC',
        npc_personality: {
          traits: ['neutral'],
          speech_pattern: 'natural',
          current_mood: 'neutral'
        },
        player_message: requestBody.prompt,
        player_relationship: 0,
        dialogue_history: [],
        known_rumors: [],
        town_context: {}
      };
      console.log('[Gemini Route] Using legacy format: prompt');
    } else {
      console.log('[Gemini Route] Using format: npc_id/npc_name/player_message');
    }

    // Step 1: Validate incoming request
    console.log('[Gemini Route] Received request for NPC:', requestBody.npc_id);
    
    const validationError = validateGeminiJson.validateRequest(requestBody);
    if (validationError) {
      console.log('[Gemini Route] Request validation failed:', validationError);
      return res.status(400).json({
        success: false,
        error: 'Invalid request schema',
        details: validationError
      });
    }
    
    // Step 2: Call Gemini API via service
    const geminiResponse = await geminiService.callGemini(requestBody);
    
    // Step 3: Validate Gemini response
    const responseValidationError = validateGeminiJson.validateResponse(geminiResponse);
    if (responseValidationError) {
      console.log('[Gemini Route] Response validation failed:', responseValidationError);
      return res.status(422).json({
        success: false,
        error: 'Gemini response failed validation',
        details: responseValidationError,
        raw_response: geminiResponse || 'No response'
      });
    }
    
    // Step 4: Build successful response with metadata
    const processingTime = Date.now() - startTime;
    const response = {
      ...geminiResponse,
      metadata: {
        model_used: DEFAULT_GEMINI_MODEL,
        tokens_used: null, // TODO: Extract from Gemini response if available
        processing_time_ms: processingTime
      }
    };
    
    console.log(`[Gemini Route] Success for ${requestBody.npc_id} (${processingTime}ms)`);
    res.status(200).json(response);
    
  } catch (error) {
    const processingTime = Date.now() - startTime;
    
    if (error.code === 'GEMINI_API_KEY_MISSING') {
      console.error('[Gemini Route] API key not configured');
      return res.status(500).json({
        success: false,
        error: 'Internal server error',
        error_code: 'GEMINI_API_KEY_MISSING',
        details: 'Gemini API key not configured. Set GEMINI_API_KEY in .env'
      });
    }
    
    if (error.code === 'GEMINI_API_ERROR') {
      console.error('[Gemini Route] Gemini API error:', error.message);

      if (error.httpStatus === 401) {
        return res.status(401).json({
          success: false,
          error: 'Gemini authentication failed',
          error_code: 'GEMINI_AUTH_FAILED',
          details: 'Gemini API key is invalid or not authorized for this API.'
        });
      }

      if (error.httpStatus === 403) {
        return res.status(403).json({
          success: false,
          error: 'Gemini access forbidden',
          error_code: 'GEMINI_ACCESS_FORBIDDEN',
          details: 'Project/API key does not have permission. Check API enablement and billing.'
        });
      }

      if (error.httpStatus === 429) {
        return res.status(429).json({
          success: false,
          error: 'Gemini quota exceeded',
          error_code: 'GEMINI_QUOTA_EXCEEDED',
          details: 'Gemini quota/rate-limit exceeded. Check plan, billing, and project quotas.',
          upstream: error.upstreamMessage || null
        });
      }

      return res.status(503).json({
        success: false,
        error: 'External service error',
        error_code: 'GEMINI_API_UNAVAILABLE',
        details: 'Failed to reach Gemini API. Check upstream status, network, and API key.',
        upstream: error.upstreamMessage || null
      });
    }
    
    // Generic error
    console.error('[Gemini Route] Unhandled error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
      details: error.message
    });
  }
});

module.exports = router;
