const express = require('express');
const multer = require('multer');
const { createWorker } = require('tesseract.js');
const sharp = require('sharp');
const fs = require('fs').promises;
const path = require('path');
const { protect } = require('../middleware/auth');
const Food = require('../models/Food');
const NutritionLog = require('../models/NutritionLog');

const router = express.Router();

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, 'uploads/');
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({
  storage: storage,
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB limit
  },
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Only image files are allowed'));
    }
  }
});

// Ensure uploads directory exists
const ensureUploadsDir = async () => {
  try {
    await fs.access('uploads/');
  } catch {
    await fs.mkdir('uploads/');
  }
};

// All routes require authentication
router.use(protect);

// @desc    Process food label OCR
// @route   POST /api/ocr/food-label
// @access  Private
router.post('/food-label', upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'No image file provided'
      });
    }

    await ensureUploadsDir();

    const worker = await createWorker('eng');

    // Preprocess image for better OCR
    const processedImagePath = `uploads/processed-${Date.now()}.png`;
    await sharp(req.file.path)
      .resize(800, null, { withoutEnlargement: true })
      .sharpen()
      .greyscale()
      .normalize()
      .toFile(processedImagePath);

    const { data: { text } } = await worker.recognize(processedImagePath);
    await worker.terminate();

    // Clean up processed image
    await fs.unlink(processedImagePath);
    await fs.unlink(req.file.path);

    // Parse nutritional information from OCR text
    const nutritionData = parseNutritionLabel(text);

    res.json({
      success: true,
      data: {
        rawText: text,
        parsedNutrition: nutritionData
      }
    });

  } catch (error) {
    console.error('OCR food label error:', error);

    // Clean up files on error
    if (req.file && req.file.path) {
      try {
        await fs.unlink(req.file.path);
      } catch (cleanupError) {
        console.error('Cleanup error:', cleanupError);
      }
    }

    res.status(500).json({
      success: false,
      message: 'Failed to process food label image'
    });
  }
});

// @desc    Process receipt OCR for meal logging
// @route   POST /api/ocr/receipt
// @access  Private
router.post('/receipt', upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'No image file provided'
      });
    }

    await ensureUploadsDir();

    const worker = await createWorker('eng');

    // Preprocess image for receipt OCR
    const processedImagePath = `uploads/processed-${Date.now()}.png`;
    await sharp(req.file.path)
      .resize(1000, null, { withoutEnlargement: true })
      .sharpen({ sigma: 1.5 })
      .greyscale()
      .normalize()
      .toFile(processedImagePath);

    const { data: { text } } = await worker.recognize(processedImagePath);
    await worker.terminate();

    // Clean up processed image
    await fs.unlink(processedImagePath);
    await fs.unlink(req.file.path);

    // Parse receipt data
    const receiptData = parseReceipt(text);

    // Try to match items with food database
    const matchedFoods = await matchReceiptItemsToFoods(receiptData.items);

    res.json({
      success: true,
      data: {
        rawText: text,
        parsedReceipt: receiptData,
        matchedFoods: matchedFoods
      }
    });

  } catch (error) {
    console.error('OCR receipt error:', error);

    // Clean up files on error
    if (req.file && req.file.path) {
      try {
        await fs.unlink(req.file.path);
      } catch (cleanupError) {
        console.error('Cleanup error:', cleanupError);
      }
    }

    res.status(500).json({
      success: false,
      message: 'Failed to process receipt image'
    });
  }
});

// @desc    Process handwritten food diary entry
// @route   POST /api/ocr/handwritten
// @access  Private
router.post('/handwritten', upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'No image file provided'
      });
    }

    await ensureUploadsDir();

    const worker = await createWorker('eng');

    // Preprocess image for handwritten text
    const processedImagePath = `uploads/processed-${Date.now()}.png`;
    await sharp(req.file.path)
      .resize(800, null, { withoutEnlargement: true })
      .sharpen({ sigma: 2 })
      .greyscale()
      .normalize()
      .linear(1.2, -10) // Increase contrast
      .toFile(processedImagePath);

    const { data: { text } } = await worker.recognize(processedImagePath);
    await worker.terminate();

    // Clean up processed image
    await fs.unlink(processedImagePath);
    await fs.unlink(req.file.path);

    // Parse handwritten food entries
    const foodEntries = parseHandwrittenDiary(text);

    res.json({
      success: true,
      data: {
        rawText: text,
        parsedEntries: foodEntries
      }
    });

  } catch (error) {
    console.error('OCR handwritten error:', error);

    // Clean up files on error
    if (req.file && req.file.path) {
      try {
        await fs.unlink(req.file.path);
      } catch (cleanupError) {
        console.error('Cleanup error:', cleanupError);
      }
    }

    res.status(500).json({
      success: false,
      message: 'Failed to process handwritten text'
    });
  }
});

// @desc    Quick nutrition scan from any image
// @route   POST /api/ocr/quick-scan
// @access  Private
router.post('/quick-scan', upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'No image file provided'
      });
    }

    await ensureUploadsDir();

    const worker = await createWorker('eng');

    // Basic preprocessing
    const processedImagePath = `uploads/processed-${Date.now()}.png`;
    await sharp(req.file.path)
      .resize(600, null, { withoutEnlargement: true })
      .greyscale()
      .normalize()
      .toFile(processedImagePath);

    const { data: { text } } = await worker.recognize(processedImagePath);
    await worker.terminate();

    // Clean up processed image
    await fs.unlink(processedImagePath);
    await fs.unlink(req.file.path);

    // Extract any nutritional information found
    const nutritionInfo = extractNutritionInfo(text);

    // Search for matching foods in database
    const matchedFoods = await searchFoodsByText(text);

    res.json({
      success: true,
      data: {
        rawText: text,
        extractedNutrition: nutritionInfo,
        possibleMatches: matchedFoods
      }
    });

  } catch (error) {
    console.error('OCR quick scan error:', error);

    // Clean up files on error
    if (req.file && req.file.path) {
      try {
        await fs.unlink(req.file.path);
      } catch (cleanupError) {
        console.error('Cleanup error:', cleanupError);
      }
    }

    res.status(500).json({
      success: false,
      message: 'Failed to process image'
    });
  }
});

// Helper functions for parsing OCR text

function parseNutritionLabel(text) {
  const lines = text.split('\n').map(line => line.trim()).filter(line => line);

  const nutrition = {
    servingSize: '',
    calories: 0,
    totalFat: 0,
    saturatedFat: 0,
    transFat: 0,
    cholesterol: 0,
    sodium: 0,
    totalCarbs: 0,
    dietaryFiber: 0,
    sugars: 0,
    protein: 0,
    vitamins: {}
  };

  lines.forEach(line => {
    const lowerLine = line.toLowerCase();

    // Extract serving size
    if (lowerLine.includes('serving size') || lowerLine.includes('servings per')) {
      nutrition.servingSize = line;
    }

    // Extract nutritional values
    if (lowerLine.includes('calories')) {
      const match = line.match(/(\d+)/);
      if (match) nutrition.calories = parseInt(match[1]);
    }

    if (lowerLine.includes('total fat')) {
      const match = line.match(/(\d+(?:\.\d+)?)/);
      if (match) nutrition.totalFat = parseFloat(match[1]);
    }

    if (lowerLine.includes('saturated fat')) {
      const match = line.match(/(\d+(?:\.\d+)?)/);
      if (match) nutrition.saturatedFat = parseFloat(match[1]);
    }

    if (lowerLine.includes('cholesterol')) {
      const match = line.match(/(\d+)/);
      if (match) nutrition.cholesterol = parseInt(match[1]);
    }

    if (lowerLine.includes('sodium')) {
      const match = line.match(/(\d+)/);
      if (match) nutrition.sodium = parseInt(match[1]);
    }

    if (lowerLine.includes('total carbohydrate') || lowerLine.includes('total carbs')) {
      const match = line.match(/(\d+(?:\.\d+)?)/);
      if (match) nutrition.totalCarbs = parseFloat(match[1]);
    }

    if (lowerLine.includes('dietary fiber') || lowerLine.includes('fiber')) {
      const match = line.match(/(\d+(?:\.\d+)?)/);
      if (match) nutrition.dietaryFiber = parseFloat(match[1]);
    }

    if (lowerLine.includes('sugars') && !lowerLine.includes('added')) {
      const match = line.match(/(\d+(?:\.\d+)?)/);
      if (match) nutrition.sugars = parseFloat(match[1]);
    }

    if (lowerLine.includes('protein')) {
      const match = line.match(/(\d+(?:\.\d+)?)/);
      if (match) nutrition.protein = parseFloat(match[1]);
    }
  });

  return nutrition;
}

function parseReceipt(text) {
  const lines = text.split('\n').map(line => line.trim()).filter(line => line);

  const receipt = {
    store: '',
    date: '',
    items: [],
    subtotal: 0,
    tax: 0,
    total: 0
  };

  lines.forEach(line => {
    const lowerLine = line.toLowerCase();

    // Extract store name
    if (lowerLine.includes('store') || lowerLine.includes('market') || lowerLine.includes('restaurant')) {
      if (!receipt.store) receipt.store = line;
    }

    // Extract date
    const dateMatch = line.match(/(\d{1,2}[-\/]\d{1,2}[-\/]\d{2,4})/);
    if (dateMatch && !receipt.date) {
      receipt.date = dateMatch[1];
    }

    // Extract items (lines that look like item descriptions with prices)
    const itemMatch = line.match(/^(.+?)\s+(\d+(?:\.\d{2})?)$/);
    if (itemMatch && itemMatch[2] && parseFloat(itemMatch[2]) > 0) {
      receipt.items.push({
        name: itemMatch[1].trim(),
        price: parseFloat(itemMatch[2])
      });
    }

    // Extract totals
    if (lowerLine.includes('subtotal')) {
      const match = line.match(/(\d+(?:\.\d{2})?)/);
      if (match) receipt.subtotal = parseFloat(match[1]);
    }

    if (lowerLine.includes('tax')) {
      const match = line.match(/(\d+(?:\.\d{2})?)/);
      if (match) receipt.tax = parseFloat(match[1]);
    }

    if (lowerLine.includes('total') && !lowerLine.includes('subtotal')) {
      const match = line.match(/(\d+(?:\.\d{2})?)/);
      if (match) receipt.total = parseFloat(match[1]);
    }
  });

  return receipt;
}

function parseHandwrittenDiary(text) {
  const lines = text.split('\n').map(line => line.trim()).filter(line => line);

  const entries = [];
  let currentMeal = '';
  let currentFoods = [];

  lines.forEach(line => {
    const lowerLine = line.toLowerCase();

    // Check for meal headers
    if (lowerLine.includes('breakfast') || lowerLine.includes('lunch') ||
        lowerLine.includes('dinner') || lowerLine.includes('snack')) {
      // Save previous meal if exists
      if (currentMeal && currentFoods.length > 0) {
        entries.push({
          meal: currentMeal,
          foods: currentFoods
        });
      }

      currentMeal = line;
      currentFoods = [];
    } else if (currentMeal && line.length > 2) {
      // Add food item to current meal
      currentFoods.push(line);
    }
  });

  // Add last meal
  if (currentMeal && currentFoods.length > 0) {
    entries.push({
      meal: currentMeal,
      foods: currentFoods
    });
  }

  return entries;
}

function extractNutritionInfo(text) {
  const lowerText = text.toLowerCase();

  const nutrition = {
    calories: null,
    protein: null,
    carbs: null,
    fat: null
  };

  // Extract calories
  const calMatch = lowerText.match(/(\d+)\s*calories?/);
  if (calMatch) nutrition.calories = parseInt(calMatch[1]);

  // Extract protein
  const protMatch = lowerText.match(/(\d+(?:\.\d+)?)\s*g\s*protein/);
  if (protMatch) nutrition.protein = parseFloat(protMatch[1]);

  // Extract carbs
  const carbMatch = lowerText.match(/(\d+(?:\.\d+)?)\s*g\s*(?:carbs?|carbohydrates?)/);
  if (carbMatch) nutrition.carbs = parseFloat(carbMatch[1]);

  // Extract fat
  const fatMatch = lowerText.match(/(\d+(?:\.\d+)?)\s*g\s*fat/);
  if (fatMatch) nutrition.fat = parseFloat(fatMatch[1]);

  return nutrition;
}

async function matchReceiptItemsToFoods(items) {
  const matchedFoods = [];

  for (const item of items) {
    try {
      // Search for food by name similarity
      const food = await Food.findOne({
        name: { $regex: item.name, $options: 'i' }
      }).select('name nutrition category');

      if (food) {
        matchedFoods.push({
          receiptItem: item.name,
          matchedFood: food.name,
          nutrition: food.nutrition,
          category: food.category
        });
      }
    } catch (error) {
      console.error('Food matching error:', error);
    }
  }

  return matchedFoods;
}

async function searchFoodsByText(text) {
  const words = text.toLowerCase().split(/\s+/).filter(word => word.length > 2);

  try {
    const foods = await Food.find({
      $or: [
        { name: { $regex: words.join('|'), $options: 'i' } },
        { category: { $regex: words.join('|'), $options: 'i' } }
      ]
    }).limit(5).select('name nutrition category');

    return foods;
  } catch (error) {
    console.error('Food search error:', error);
    return [];
  }
}

module.exports = router;