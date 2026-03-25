const express = require('express');
const { protect } = require('../middleware/auth');
const { openRouterChat } = require('../services/openrouter');
const { searchYouTubeVideos } = require('../services/youtube');

const router = express.Router();

// Protect AI endpoints so usage stays tied to authenticated users.
router.use(protect);

// @desc    General AI chat
// @route   POST /api/ai/chat
// @access  Private
router.post('/chat', async (req, res) => {
  try {
    const { prompt, messages, model, temperature, maxTokens } = req.body || {};

    if (!prompt && (!Array.isArray(messages) || messages.length === 0)) {
      return res.status(400).json({
        success: false,
        message: 'Either prompt or messages is required'
      });
    }

    const normalizedMessages = Array.isArray(messages) && messages.length > 0
      ? messages
      : [{ role: 'user', content: String(prompt || '') }];

    const responseText = await openRouterChat({
      messages: normalizedMessages,
      model,
      temperature: Number.isFinite(temperature) ? Number(temperature) : 0.2,
      maxTokens: Number.isFinite(maxTokens) ? Number(maxTokens) : 900
    });

    return res.json({
      success: true,
      data: {
        text: responseText
      }
    });
  } catch (error) {
    console.error('AI chat error:', error?.response?.data || error.message || error);
    return res.status(500).json({
      success: false,
      message: 'Failed to generate AI response'
    });
  }
});

// @desc    Search YouTube videos
// @route   GET /api/ai/youtube/search?q=<query>&maxResults=5
// @access  Private
router.get('/youtube/search', async (req, res) => {
  try {
    const query = String(req.query.q || '').trim();
    const maxResults = Math.max(1, Math.min(parseInt(req.query.maxResults, 10) || 5, 15));

    if (!query) {
      return res.status(400).json({
        success: false,
        message: 'q query parameter is required'
      });
    }

    const videos = await searchYouTubeVideos({ query, maxResults });

    return res.json({
      success: true,
      data: videos
    });
  } catch (error) {
    console.error('YouTube search error:', error?.response?.data || error.message || error);
    return res.status(500).json({
      success: false,
      message: 'Failed to search YouTube videos'
    });
  }
});

module.exports = router;
