const express = require('express');
const router = express.Router();
const geminiService = require('../services/geminiService');
const validateGeminiJson = require('../utils/validateGeminiJson');

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
    // Step 1: Validate incoming request
    console.log('[Gemini Route] Received request for NPC:', req.body.npc_id);
    
    const validationError = validateGeminiJson.validateRequest(req.body);
    if (validationError) {
      console.log('[Gemini Route] Request validation failed:', validationError);
      return res.status(400).json({
        success: false,
        error: 'Invalid request schema',
        details: validationError
      });
    }
    
    // Step 2: Call Gemini API via service
    const geminiResponse = await geminiService.callGemini(req.body);
    
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
        model_used: 'gemini-2.0-flash',
        tokens_used: null, // TODO: Extract from Gemini response if available
        processing_time_ms: processingTime
      }
    };
    
    console.log(`[Gemini Route] Success for ${req.body.npc_id} (${processingTime}ms)`);
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
      return res.status(503).json({
        success: false,
        error: 'External service error',
        error_code: 'GEMINI_API_UNAVAILABLE',
        details: 'Failed to reach Gemini API. Check your internet connection and API key.'
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
