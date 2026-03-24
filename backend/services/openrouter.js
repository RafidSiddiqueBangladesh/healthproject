const axios = require('axios');

const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions';

function extractJsonFromText(text) {
  if (!text || typeof text !== 'string') return null;

  const codeBlockMatch = text.match(/```json\s*([\s\S]*?)```/i);
  if (codeBlockMatch) {
    try {
      return JSON.parse(codeBlockMatch[1]);
    } catch (error) {
      // Continue and try a raw object extraction fallback.
    }
  }

  const firstBrace = text.indexOf('{');
  const firstBracket = text.indexOf('[');
  let start = -1;

  if (firstBrace === -1) {
    start = firstBracket;
  } else if (firstBracket === -1) {
    start = firstBrace;
  } else {
    start = Math.min(firstBrace, firstBracket);
  }

  if (start < 0) return null;

  const candidate = text.slice(start).trim();
  try {
    return JSON.parse(candidate);
  } catch (error) {
    return null;
  }
}

async function openRouterChat({ messages, model, maxTokens = 900, temperature = 0.2 }) {
  if (!process.env.OPENROUTER_API_KEY) {
    throw new Error('OPENROUTER_API_KEY is not configured');
  }

  const response = await axios.post(
    OPENROUTER_URL,
    {
      model: model || process.env.OPENROUTER_MODEL || 'google/gemini-2.0-flash-lite-001',
      messages,
      max_tokens: maxTokens,
      temperature
    },
    {
      headers: {
        Authorization: `Bearer ${process.env.OPENROUTER_API_KEY}`,
        'Content-Type': 'application/json',
        'HTTP-Referer': process.env.OPENROUTER_SITE_URL || 'http://localhost:5000',
        'X-Title': process.env.OPENROUTER_APP_NAME || 'NutriCare Backend'
      },
      timeout: 45000
    }
  );

  const content = response.data?.choices?.[0]?.message?.content;
  if (!content) {
    throw new Error('OpenRouter returned an empty response');
  }

  return content;
}

async function openRouterJson(params) {
  const text = await openRouterChat(params);
  const parsed = extractJsonFromText(text);

  if (!parsed) {
    throw new Error('Failed to parse JSON from OpenRouter response');
  }

  return parsed;
}

module.exports = {
  openRouterChat,
  openRouterJson,
  extractJsonFromText
};
