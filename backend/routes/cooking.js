const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs').promises;
const { protect } = require('../middleware/auth');
const CookingInventoryItem = require('../models/CookingInventoryItem');
const { openRouterJson } = require('../services/openrouter');
const { parseFoodItemsFallback } = require('../services/food_parser');
const { searchYouTubeVideos } = require('../services/youtube');

const router = express.Router();

const DEFAULT_SHELF_LIFE_DAYS = {
  salad: 30,
  meat: 365,
  fish: 7,
  egg: 30,
  rice: 180,
  potato: 60,
  default: 30
};

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, 'uploads/'),
  filename: (req, file, cb) => {
    const uniqueSuffix = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
    cb(null, `cooking-${uniqueSuffix}${path.extname(file.originalname)}`);
  }
});

const upload = multer({
  storage,
  limits: { fileSize: 8 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) return cb(null, true);
    return cb(new Error('Only image files are allowed'));
  }
});

async function ensureUploadsDir() {
  try {
    await fs.access('uploads/');
  } catch (error) {
    await fs.mkdir('uploads/');
  }
}

function buildExpiryDate(name, boughtAtInput, expiryAtInput) {
  const boughtAt = boughtAtInput ? new Date(boughtAtInput) : new Date();
  if (expiryAtInput) return new Date(expiryAtInput);

  const lower = String(name || '').toLowerCase();
  const key = Object.keys(DEFAULT_SHELF_LIFE_DAYS).find((k) => k !== 'default' && lower.includes(k));
  const days = key ? DEFAULT_SHELF_LIFE_DAYS[key] : DEFAULT_SHELF_LIFE_DAYS.default;

  const expiryAt = new Date(boughtAt);
  expiryAt.setDate(expiryAt.getDate() + days);
  return expiryAt;
}

router.use(protect);

router.get('/inventory', async (req, res) => {
  try {
    const items = await CookingInventoryItem.find({ user: req.user._id }).sort({ createdAt: -1 });
    res.json({ success: true, data: items });
  } catch (error) {
    console.error('Get cooking inventory error:', error);
    res.status(500).json({ success: false, message: 'Failed to load inventory' });
  }
});

router.post('/inventory', async (req, res) => {
  try {
    const {
      name,
      quantity = 1,
      unit = 'default',
      grams = 100,
      boughtAt,
      expiryAt,
      cost = 0,
      currency = 'BDT',
      source = 'manual'
    } = req.body;

    if (!name || !String(name).trim()) {
      return res.status(400).json({ success: false, message: 'Item name is required' });
    }

    const item = await CookingInventoryItem.create({
      user: req.user._id,
      name: String(name).trim(),
      quantity: Number(quantity) || 1,
      unit,
      grams: Number(grams) || 100,
      boughtAt: boughtAt ? new Date(boughtAt) : new Date(),
      expiryAt: buildExpiryDate(name, boughtAt, expiryAt),
      cost: Number(cost) || 0,
      currency,
      source
    });

    res.status(201).json({ success: true, data: item });
  } catch (error) {
    console.error('Create cooking inventory item error:', error);
    res.status(500).json({ success: false, message: 'Failed to create inventory item' });
  }
});

router.delete('/inventory/:id', async (req, res) => {
  try {
    const deleted = await CookingInventoryItem.findOneAndDelete({
      _id: req.params.id,
      user: req.user._id
    });

    if (!deleted) {
      return res.status(404).json({ success: false, message: 'Inventory item not found' });
    }

    res.json({ success: true, message: 'Inventory item deleted' });
  } catch (error) {
    console.error('Delete cooking inventory item error:', error);
    res.status(500).json({ success: false, message: 'Failed to delete inventory item' });
  }
});

router.post('/inventory/voice-parse', async (req, res) => {
  try {
    const { transcript = '' } = req.body;
    if (!transcript.trim()) {
      return res.status(400).json({ success: false, message: 'transcript is required' });
    }

    let items;
    try {
      items = await openRouterJson({
        model: process.env.OPENROUTER_TEXT_MODEL || 'google/gemini-2.0-flash-lite-001',
        messages: [
          {
            role: 'system',
            content: 'Convert user spoken kitchen items (English/Bangla) into strict JSON array: [{"name":"","quantity":number,"unit":"piece|g|kg|cup|slice|default","grams":number,"cost":number|null}]. If no amount is spoken use quantity=1 and unit="default" and grams=100. Return JSON only.'
          },
          { role: 'user', content: transcript }
        ],
        temperature: 0.1,
        maxTokens: 700
      });
    } catch (error) {
      items = parseFoodItemsFallback(transcript).map((item) => ({ ...item, cost: null }));
    }

    res.json({ success: true, data: { transcript, items } });
  } catch (error) {
    console.error('Cooking voice parse error:', error);
    res.status(500).json({ success: false, message: 'Failed to parse cooking voice data' });
  }
});

router.post('/inventory/ocr-parse', upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, message: 'image is required' });
    }

    const imageBuffer = await fs.readFile(req.file.path);
    const base64 = imageBuffer.toString('base64');

    let items = [];
    try {
      items = await openRouterJson({
        model: process.env.OPENROUTER_VISION_MODEL || 'google/gemini-2.0-flash-lite-001',
        messages: [
          {
            role: 'system',
            content: 'Read this grocery/ingredient image and return strict JSON array: [{"name":"","quantity":number,"unit":"piece|g|kg|cup|slice|default","grams":number,"cost":number|null}]. If amount missing use quantity=1, unit="default", grams=100. Return JSON only.'
          },
          {
            role: 'user',
            content: [
              { type: 'text', text: 'Extract ingredients and quantities from this image' },
              { type: 'image_url', image_url: { url: `data:${req.file.mimetype};base64,${base64}` } }
            ]
          }
        ],
        maxTokens: 1000
      });
    } finally {
      await fs.unlink(req.file.path);
    }

    res.json({ success: true, data: { items } });
  } catch (error) {
    console.error('Cooking OCR parse error:', error);

    if (req.file?.path) {
      try {
        await fs.unlink(req.file.path);
      } catch (cleanupError) {
        console.error('Cleanup error:', cleanupError);
      }
    }

    res.status(500).json({ success: false, message: 'Failed to parse cooking screenshot' });
  }
});

router.post('/inventory/bulk', async (req, res) => {
  try {
    const { items = [], source = 'manual' } = req.body;
    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ success: false, message: 'items array is required' });
    }

    const docs = items
      .filter((item) => item?.name)
      .map((item) => ({
        user: req.user._id,
        name: String(item.name).trim(),
        quantity: Number(item.quantity) || 1,
        unit: item.unit || 'default',
        grams: Number(item.grams) || 100,
        cost: Number(item.cost) || 0,
        currency: item.currency || 'BDT',
        boughtAt: item.boughtAt ? new Date(item.boughtAt) : new Date(),
        expiryAt: buildExpiryDate(item.name, item.boughtAt, item.expiryAt),
        source
      }));

    const created = await CookingInventoryItem.insertMany(docs);
    res.status(201).json({ success: true, count: created.length, data: created });
  } catch (error) {
    console.error('Bulk cooking inventory add error:', error);
    res.status(500).json({ success: false, message: 'Failed to add inventory items' });
  }
});

router.get('/ai/suggestions', async (req, res) => {
  try {
    const inventory = await CookingInventoryItem.find({ user: req.user._id }).sort({ expiryAt: 1 }).limit(30);

    const promptData = inventory.map((item) => ({
      name: item.name,
      quantity: item.quantity,
      unit: item.unit,
      expiryAt: item.expiryAt,
      cost: item.cost
    }));

    let suggestions;
    try {
      suggestions = await openRouterJson({
        messages: [
          {
            role: 'system',
            content: 'You are a practical Bangladeshi home cooking assistant. Return JSON with keys: suggestion, recipes (array of {name,reason}), keywords (array). Prioritize near-expiry ingredients and low cost.'
          },
          { role: 'user', content: JSON.stringify(promptData) }
        ],
        model: process.env.OPENROUTER_TEXT_MODEL || 'google/gemini-2.0-flash-lite-001',
        maxTokens: 900
      });
    } catch (error) {
      suggestions = {
        suggestion: 'Use near-expiry ingredients first and build simple curries or stir fry meals.',
        recipes: inventory.slice(0, 3).map((item) => ({
          name: `${item.name} quick recipe`,
          reason: 'Uses available inventory to reduce waste'
        })),
        keywords: inventory.slice(0, 3).map((item) => item.name)
      };
    }

    res.json({ success: true, data: suggestions });
  } catch (error) {
    console.error('Cooking AI suggestions error:', error);
    res.status(500).json({ success: false, message: 'Failed to build cooking suggestions' });
  }
});

router.get('/videos/search', async (req, res) => {
  try {
    const { q } = req.query;
    if (!q || !String(q).trim()) {
      return res.status(400).json({ success: false, message: 'q query is required' });
    }

    const videos = await searchYouTubeVideos({ query: String(q), maxResults: 8 });
    res.json({ success: true, data: videos });
  } catch (error) {
    console.error('Cooking video search error:', error);
    res.status(500).json({ success: false, message: error.message || 'Failed to search cooking videos' });
  }
});

ensureUploadsDir().catch((error) => {
  console.error('Failed to initialize uploads dir for cooking route:', error);
});

module.exports = router;
