require('dotenv').config();
const express = require('express');
const cors = require('cors');
const geminiRoutes = require('./src/routes/gemini');

const app = express();
const PORT = process.env.BACKEND_PORT || 8080;

// Middleware
app.use(cors());
app.use(express.json());

// Request logging middleware
app.use((req, res, next) => {
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] ${req.method} ${req.path}`);
  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// API routes
app.use('/api', geminiRoutes);

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: `${req.method} ${req.path} does not exist`
  });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({
    error: 'Internal Server Error',
    message: 'An unexpected error occurred. Check server logs.'
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`\n🦆 Duck Party backend running on http://localhost:${PORT}`);
  console.log(`📍 Health check: GET http://localhost:${PORT}/health`);
  console.log(`💬 NPC dialogue: POST http://localhost:${PORT}/api/gemini\n`);
  
  // Verify API key is set
  if (!process.env.GEMINI_API_KEY) {
    console.warn('⚠️  WARNING: GEMINI_API_KEY not set in .env');
    console.warn('   Set it to enable NPC dialogue via Gemini API\n');
  }
});
