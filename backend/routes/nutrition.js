const express = require('express');
const { body, validationResult } = require('express-validator');
const multer = require('multer');
const fs = require('fs').promises;
const path = require('path');
const NutritionLog = require('../models/NutritionLog');
const Food = require('../models/Food');
const { protect } = require('../middleware/auth');
const { openRouterJson } = require('../services/openrouter');
const { parseFoodItemsFallback, estimateCalories } = require('../services/food_parser');

const router = express.Router();

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, 'uploads/'),
  filename: (req, file, cb) => {
    const uniqueSuffix = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
    cb(null, `nutrition-${uniqueSuffix}${path.extname(file.originalname)}`);
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

// All routes require authentication
router.use(protect);

// @desc    Get food chart for dashboard
// @route   GET /api/nutrition/food-chart
// @access  Private
router.get('/food-chart', async (req, res) => {
  try {
    const userId = req.user._id;
    const { date } = req.query;

    // Default to today if no date provided
    const targetDate = date ? new Date(date) : new Date();

    // Get daily summary
    const dailySummary = await NutritionLog.getDailySummary(userId, targetDate);

    // Get user's nutritional goals (calculated based on profile)
    const user = req.user;
    let dailyGoals = {
      calories: 2000, // Default
      protein: 150,
      carbs: 250,
      fat: 67
    };

    // Calculate BMR and TDEE for personalized goals
    if (user.height && user.weight && user.dateOfBirth && user.gender && user.activityLevel) {
      const age = user.age;
      let bmr;

      if (user.gender === 'male') {
        bmr = 88.362 + (13.397 * user.weight) + (4.799 * user.height) - (5.677 * age);
      } else {
        bmr = 447.593 + (9.247 * user.weight) + (3.098 * user.height) - (4.330 * age);
      }

      const activityMultipliers = {
        'sedentary': 1.2,
        'lightly_active': 1.375,
        'moderately_active': 1.55,
        'very_active': 1.725,
        'extremely_active': 1.9
      };

      const tdee = bmr * activityMultipliers[user.activityLevel];

      // Adjust based on fitness goals
      if (user.fitnessGoals.includes('weight_loss')) {
        dailyGoals.calories = Math.round(tdee - 500);
      } else if (user.fitnessGoals.includes('weight_gain')) {
        dailyGoals.calories = Math.round(tdee + 500);
      } else {
        dailyGoals.calories = Math.round(tdee);
      }

      dailyGoals.protein = Math.round(user.weight * 1.6); // 1.6g per kg body weight
      dailyGoals.carbs = Math.round((dailyGoals.calories * 0.5) / 4); // 50% of calories from carbs
      dailyGoals.fat = Math.round((dailyGoals.calories * 0.25) / 9); // 25% of calories from fat
    }

    // Calculate progress percentages
    const progress = {
      calories: 0,
      protein: 0,
      carbs: 0,
      fat: 0
    };

    if (dailySummary.length > 0) {
      const totals = dailySummary.reduce((acc, meal) => {
        acc.calories += meal.totalCalories;
        acc.protein += meal.totalProtein;
        acc.carbs += meal.totalCarbs;
        acc.fat += meal.totalFat;
        return acc;
      }, { calories: 0, protein: 0, carbs: 0, fat: 0 });

      progress.calories = Math.round((totals.calories / dailyGoals.calories) * 100);
      progress.protein = Math.round((totals.protein / dailyGoals.protein) * 100);
      progress.carbs = Math.round((totals.carbs / dailyGoals.carbs) * 100);
      progress.fat = Math.round((totals.fat / dailyGoals.fat) * 100);
    }

    res.json({
      success: true,
      data: {
        date: targetDate.toISOString().split('T')[0],
        goals: dailyGoals,
        progress: progress,
        meals: dailySummary,
        recommendations: {
          nextMeal: getNextMealSuggestion(targetDate),
          alternatives: await getFoodAlternatives(userId)
        }
      }
    });
  } catch (error) {
    console.error('Food chart error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @desc    Parse voice transcript into structured food list
// @route   POST /api/nutrition/voice/parse
// @access  Private
router.post('/voice/parse', async (req, res) => {
  try {
    const { transcript = '' } = req.body;

    if (!transcript.trim()) {
      return res.status(400).json({
        success: false,
        message: 'transcript is required'
      });
    }

    let items;
    try {
      items = await openRouterJson({
        model: process.env.OPENROUTER_TEXT_MODEL || 'google/gemini-2.0-flash-lite-001',
        messages: [
          {
            role: 'system',
            content: 'Convert the spoken food text (Bangla or English) into strict JSON array: [{"name":"","quantity":number,"unit":"piece|g|kg|cup|slice|default","grams":number,"calories":number|null}]. If amount is missing set quantity=1, unit="default", grams=100. Return only JSON.'
          },
          { role: 'user', content: transcript }
        ],
        temperature: 0.1,
        maxTokens: 800
      });
    } catch (error) {
      items = parseFoodItemsFallback(transcript);
    }

    const normalizedItems = normalizeParsedItems(items);

    res.json({
      success: true,
      data: {
        transcript,
        items: normalizedItems
      }
    });
  } catch (error) {
    console.error('Nutrition voice parse error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to parse nutrition voice data'
    });
  }
});

// @desc    Parse voice and save into nutrition logs
// @route   POST /api/nutrition/voice/log
// @access  Private
router.post('/voice/log', async (req, res) => {
  try {
    const { transcript = '', meal = 'snacks', date } = req.body;
    if (!transcript.trim()) {
      return res.status(400).json({ success: false, message: 'transcript is required' });
    }

    let parsedItems;
    try {
      parsedItems = await openRouterJson({
        model: process.env.OPENROUTER_TEXT_MODEL || 'google/gemini-2.0-flash-lite-001',
        messages: [
          {
            role: 'system',
            content: 'Convert this spoken nutrition text into JSON array with fields name, quantity, unit, grams, calories. If amount missing default quantity=1, unit=default, grams=100.'
          },
          { role: 'user', content: transcript }
        ],
        temperature: 0.1,
        maxTokens: 800
      });
    } catch (error) {
      parsedItems = parseFoodItemsFallback(transcript);
    }

    const normalizedItems = normalizeParsedItems(parsedItems);
    const log = await createNutritionLogFromItems({
      userId: req.user._id,
      meal,
      date,
      items: normalizedItems,
      inputMethod: 'voice',
      voiceTranscript: transcript
    });

    res.status(201).json({
      success: true,
      message: 'Voice nutrition log created',
      data: log
    });
  } catch (error) {
    console.error('Nutrition voice log error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to save voice nutrition log'
    });
  }
});

// @desc    Parse screenshot and return food list
// @route   POST /api/nutrition/ocr/parse
// @access  Private
router.post('/ocr/parse', upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, message: 'image is required' });
    }

    const imageBuffer = await fs.readFile(req.file.path);
    const base64 = imageBuffer.toString('base64');

    let parsedItems;
    try {
      parsedItems = await openRouterJson({
        model: process.env.OPENROUTER_VISION_MODEL || 'google/gemini-2.0-flash-lite-001',
        messages: [
          {
            role: 'system',
            content: 'Read this image and return nutrition entry JSON array with fields name, quantity, unit, grams, calories. If quantity is missing set quantity=1, unit=default, grams=100. Return JSON only.'
          },
          {
            role: 'user',
            content: [
              { type: 'text', text: 'Extract food items and amounts from this image.' },
              { type: 'image_url', image_url: { url: `data:${req.file.mimetype};base64,${base64}` } }
            ]
          }
        ],
        maxTokens: 1200
      });
    } finally {
      await fs.unlink(req.file.path);
    }

    const normalizedItems = normalizeParsedItems(parsedItems);
    res.json({ success: true, data: { items: normalizedItems } });
  } catch (error) {
    console.error('Nutrition OCR parse error:', error);

    if (req.file?.path) {
      try {
        await fs.unlink(req.file.path);
      } catch (cleanupError) {
        console.error('Nutrition OCR cleanup error:', cleanupError);
      }
    }

    res.status(500).json({ success: false, message: 'Failed to parse nutrition screenshot' });
  }
});

// @desc    Parse screenshot and save nutrition log
// @route   POST /api/nutrition/ocr/log
// @access  Private
router.post('/ocr/log', upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, message: 'image is required' });
    }

    const { meal = 'snacks', date } = req.body;
    const imageBuffer = await fs.readFile(req.file.path);
    const base64 = imageBuffer.toString('base64');

    let parsedItems;
    try {
      parsedItems = await openRouterJson({
        model: process.env.OPENROUTER_VISION_MODEL || 'google/gemini-2.0-flash-lite-001',
        messages: [
          {
            role: 'system',
            content: 'Read this food image and return strict JSON array with fields name, quantity, unit, grams, calories. Missing amount should default to quantity=1, unit=default, grams=100.'
          },
          {
            role: 'user',
            content: [
              { type: 'text', text: 'Extract nutrition log items from this image.' },
              { type: 'image_url', image_url: { url: `data:${req.file.mimetype};base64,${base64}` } }
            ]
          }
        ],
        maxTokens: 1200
      });
    } finally {
      await fs.unlink(req.file.path);
    }

    const normalizedItems = normalizeParsedItems(parsedItems);
    const log = await createNutritionLogFromItems({
      userId: req.user._id,
      meal,
      date,
      items: normalizedItems,
      inputMethod: 'ocr',
      ocrImage: req.file.filename
    });

    res.status(201).json({
      success: true,
      message: 'OCR nutrition log created',
      data: log
    });
  } catch (error) {
    console.error('Nutrition OCR log error:', error);

    if (req.file?.path) {
      try {
        await fs.unlink(req.file.path);
      } catch (cleanupError) {
        console.error('Nutrition OCR cleanup error:', cleanupError);
      }
    }

    res.status(500).json({ success: false, message: 'Failed to save OCR nutrition log' });
  }
});

// @desc    Save pre-parsed nutrition items from frontend
// @route   POST /api/nutrition/items/log
// @access  Private
router.post('/items/log', async (req, res) => {
  try {
    const { items = [], meal = 'snacks', date, inputMethod = 'manual', voiceTranscript = '', ocrImage = '' } = req.body;

    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'items array is required'
      });
    }

    const normalizedItems = normalizeParsedItems(items);

    const log = await createNutritionLogFromItems({
      userId: req.user._id,
      meal,
      date,
      items: normalizedItems,
      inputMethod,
      voiceTranscript,
      ocrImage
    });

    res.status(201).json({
      success: true,
      data: log,
      message: 'Nutrition items saved'
    });
  } catch (error) {
    console.error('Save nutrition items error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to save nutrition items'
    });
  }
});

// @desc    Get calorie chart data for date range
// @route   GET /api/nutrition/calorie-chart
// @access  Private
router.get('/calorie-chart', async (req, res) => {
  try {
    const { startDate, endDate } = req.query;

    const end = endDate ? new Date(endDate) : new Date();
    const start = startDate ? new Date(startDate) : new Date(end.getTime() - 6 * 24 * 60 * 60 * 1000);

    const logs = await NutritionLog.find({
      user: req.user._id,
      date: { $gte: start, $lte: end }
    }).sort({ date: 1 });

    const totalsByDate = {};
    for (const log of logs) {
      const key = new Date(log.date).toISOString().split('T')[0];
      if (!totalsByDate[key]) {
        totalsByDate[key] = { calories: 0, protein: 0, carbs: 0, fat: 0 };
      }
      totalsByDate[key].calories += log.totalNutrition.calories || 0;
      totalsByDate[key].protein += log.totalNutrition.protein || 0;
      totalsByDate[key].carbs += log.totalNutrition.carbs || 0;
      totalsByDate[key].fat += log.totalNutrition.fat || 0;
    }

    const chart = Object.entries(totalsByDate).map(([dateKey, totals]) => ({
      date: dateKey,
      calories: Number(totals.calories.toFixed(1)),
      protein: Number(totals.protein.toFixed(1)),
      carbs: Number(totals.carbs.toFixed(1)),
      fat: Number(totals.fat.toFixed(1))
    }));

    res.json({
      success: true,
      data: chart
    });
  } catch (error) {
    console.error('Calorie chart error:', error);
    res.status(500).json({ success: false, message: 'Failed to build calorie chart' });
  }
});

// @desc    Add food to nutrition log
// @route   POST /api/nutrition/log
// @access  Private
router.post('/log', [
  body('foodId').isMongoId().withMessage('Valid food ID is required'),
  body('quantity').isFloat({ min: 0.1 }).withMessage('Quantity must be at least 0.1'),
  body('unit').isIn(['g', 'kg', 'ml', 'l', 'cup', 'tbsp', 'tsp', 'oz', 'lb', 'piece', 'slice']).withMessage('Invalid unit'),
  body('meal').isIn(['breakfast', 'lunch', 'dinner', 'snacks']).withMessage('Invalid meal type')
], async (req, res) => {
  try {
    // Check for validation errors
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        message: 'Validation failed',
        errors: errors.array()
      });
    }

    const { foodId, quantity, unit, meal, date, notes } = req.body;
    const userId = req.user._id;

    // Get food details
    const food = await Food.findById(foodId);
    if (!food) {
      return res.status(404).json({
        success: false,
        message: 'Food not found'
      });
    }

    // Calculate nutritional values based on quantity
    const multiplier = quantity / food.servingSize.amount;
    const calories = Math.round(food.nutritionalInfo.calories * multiplier);
    const nutritionalInfo = {
      protein: Math.round(food.nutritionalInfo.protein * multiplier),
      carbs: Math.round(food.nutritionalInfo.carbs * multiplier),
      fat: Math.round(food.nutritionalInfo.fat * multiplier),
      fiber: Math.round(food.nutritionalInfo.fiber * multiplier),
      sugar: Math.round(food.nutritionalInfo.sugar * multiplier),
      sodium: Math.round(food.nutritionalInfo.sodium * multiplier)
    };

    // Check if log exists for this meal and date
    const logDate = date ? new Date(date) : new Date();
    let nutritionLog = await NutritionLog.findOne({
      user: userId,
      meal: meal,
      date: {
        $gte: new Date(logDate.getFullYear(), logDate.getMonth(), logDate.getDate()),
        $lt: new Date(logDate.getFullYear(), logDate.getMonth(), logDate.getDate() + 1)
      }
    });

    if (nutritionLog) {
      // Add to existing log
      nutritionLog.foods.push({
        food: foodId,
        quantity,
        unit,
        calories,
        nutritionalInfo
      });
    } else {
      // Create new log
      nutritionLog = new NutritionLog({
        user: userId,
        meal,
        date: logDate,
        foods: [{
          food: foodId,
          quantity,
          unit,
          calories,
          nutritionalInfo
        }],
        notes
      });
    }

    await nutritionLog.save();

    // Award points
    req.user.points += 5;
    await req.user.save();

    res.status(201).json({
      success: true,
      message: 'Food logged successfully',
      data: nutritionLog,
      pointsEarned: 5
    });
  } catch (error) {
    console.error('Log food error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @desc    Get nutrition logs for a date range
// @route   GET /api/nutrition/logs
// @access  Private
router.get('/logs', async (req, res) => {
  try {
    const userId = req.user._id;
    const { startDate, endDate, meal } = req.query;

    let query = { user: userId };

    if (startDate && endDate) {
      query.date = {
        $gte: new Date(startDate),
        $lte: new Date(endDate)
      };
    }

    if (meal) {
      query.meal = meal;
    }

    const logs = await NutritionLog.find(query)
      .populate('foods.food', 'name category nutritionalInfo')
      .sort({ date: -1, meal: 1 });

    res.json({
      success: true,
      count: logs.length,
      data: logs
    });
  } catch (error) {
    console.error('Get logs error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @desc    Delete nutrition log entry
// @route   DELETE /api/nutrition/log/:id
// @access  Private
router.delete('/log/:id', async (req, res) => {
  try {
    const log = await NutritionLog.findById(req.params.id);

    if (!log) {
      return res.status(404).json({
        success: false,
        message: 'Nutrition log not found'
      });
    }

    if (log.user.toString() !== req.user._id.toString()) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to delete this log'
      });
    }

    await log.remove();

    res.json({
      success: true,
      message: 'Nutrition log deleted successfully'
    });
  } catch (error) {
    console.error('Delete log error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @desc    Search foods
// @route   GET /api/nutrition/foods/search
// @access  Private
router.get('/foods/search', async (req, res) => {
  try {
    const { q, category, dietaryTags } = req.query;

    let query = {};

    if (q) {
      query.$text = { $search: q };
    }

    if (category) {
      query.category = category;
    }

    if (dietaryTags) {
      const tags = Array.isArray(dietaryTags) ? dietaryTags : [dietaryTags];
      query.dietaryTags = { $in: tags };
    }

    const foods = await Food.find(query)
      .select('name category nutritionalInfo servingSize dietaryTags allergens image')
      .limit(20);

    res.json({
      success: true,
      count: foods.length,
      data: foods
    });
  } catch (error) {
    console.error('Search foods error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// Helper function to get next meal suggestion
function getNextMealSuggestion(date) {
  const hour = date.getHours();
  const meals = ['breakfast', 'lunch', 'dinner', 'snacks'];

  if (hour < 10) return 'breakfast';
  if (hour < 14) return 'lunch';
  if (hour < 20) return 'dinner';
  return 'snacks';
}

// Helper function to get food alternatives
async function getFoodAlternatives(userId) {
  try {
    // Get user's recent foods and suggest alternatives
    const recentLogs = await NutritionLog.find({ user: userId })
      .sort({ createdAt: -1 })
      .limit(10)
      .populate('foods.food');

    const alternatives = [];

    for (const log of recentLogs) {
      for (const foodItem of log.foods) {
        const food = foodItem.food;
        if (food && food.alternatives && food.alternatives.length > 0) {
          const alt = await Food.findById(food.alternatives[0].foodId)
            .select('name category nutritionalInfo');
          if (alt) {
            alternatives.push({
              original: food.name,
              alternative: alt.name,
              reason: food.alternatives[0].reason
            });
          }
        }
      }
    }

    return alternatives.slice(0, 5);
  } catch (error) {
    console.error('Get alternatives error:', error);
    return [];
  }
}

function normalizeParsedItems(items) {
  if (!Array.isArray(items)) return [];

  return items
    .filter((item) => item && item.name)
    .map((item) => {
      const name = String(item.name).trim();
      const quantity = Number(item.quantity) > 0 ? Number(item.quantity) : 1;
      const unit = item.unit ? String(item.unit).toLowerCase() : 'default';
      const grams = Number(item.grams) > 0 ? Number(item.grams) : unit === 'default' ? 100 : 100;
      const calories = Number(item.calories) > 0 ? Number(item.calories) : estimateCalories(name, grams);

      return {
        name,
        quantity,
        unit,
        grams,
        calories: Number(calories.toFixed(1))
      };
    });
}

function inferCategory(name) {
  const text = String(name || '').toLowerCase();

  if (/(apple|banana|orange|mango|fruit)/i.test(text)) return 'fruits';
  if (/(rice|bread|oat|noodle|grain|dal|lentil)/i.test(text)) return 'grains';
  if (/(chicken|fish|egg|meat|beef|protein)/i.test(text)) return 'proteins';
  if (/(milk|cheese|yogurt)/i.test(text)) return 'dairy';
  if (/(potato|spinach|vegetable|salad|carrot)/i.test(text)) return 'vegetables';

  return 'other';
}

async function findOrCreateFoodByName(item) {
  const escapedName = item.name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

  let food = await Food.findOne({ name: { $regex: `^${escapedName}$`, $options: 'i' } });
  if (food) return food;

  food = await Food.create({
    name: item.name,
    category: inferCategory(item.name),
    nutritionalInfo: {
      calories: item.calories,
      protein: Number((item.grams * 0.03).toFixed(1)),
      carbs: Number((item.grams * 0.15).toFixed(1)),
      fat: Number((item.grams * 0.02).toFixed(1)),
      fiber: Number((item.grams * 0.02).toFixed(1)),
      sugar: Number((item.grams * 0.01).toFixed(1)),
      sodium: 0
    },
    servingSize: {
      amount: item.grams || 100,
      unit: 'g'
    },
    source: 'manual',
    verified: false
  });

  return food;
}

async function createNutritionLogFromItems({ userId, meal, date, items, inputMethod, voiceTranscript = '', ocrImage = '' }) {
  const safeMeal = ['breakfast', 'lunch', 'dinner', 'snacks'].includes(meal) ? meal : 'snacks';
  const logDate = date ? new Date(date) : new Date();

  const foods = [];
  for (const item of items) {
    const food = await findOrCreateFoodByName(item);

    const grams = item.grams || 100;
    const multiplier = grams / (food.servingSize.amount || 100);

    foods.push({
      food: food._id,
      quantity: grams,
      unit: 'g',
      calories: Number((food.nutritionalInfo.calories * multiplier).toFixed(1)),
      nutritionalInfo: {
        protein: Number(((food.nutritionalInfo.protein || 0) * multiplier).toFixed(1)),
        carbs: Number(((food.nutritionalInfo.carbs || 0) * multiplier).toFixed(1)),
        fat: Number(((food.nutritionalInfo.fat || 0) * multiplier).toFixed(1)),
        fiber: Number(((food.nutritionalInfo.fiber || 0) * multiplier).toFixed(1)),
        sugar: Number(((food.nutritionalInfo.sugar || 0) * multiplier).toFixed(1)),
        sodium: Number(((food.nutritionalInfo.sodium || 0) * multiplier).toFixed(1))
      }
    });
  }

  const log = await NutritionLog.create({
    user: userId,
    meal: safeMeal,
    date: logDate,
    foods,
    inputMethod,
    voiceTranscript,
    ocrImage,
    isCompleted: true
  });

  return NutritionLog.findById(log._id).populate('foods.food', 'name nutritionalInfo servingSize');
}

ensureUploadsDir().catch((error) => {
  console.error('Failed to initialize uploads dir for nutrition route:', error);
});

module.exports = router;
