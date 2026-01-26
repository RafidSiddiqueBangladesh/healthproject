const express = require('express');
const { body, validationResult } = require('express-validator');
const NutritionLog = require('../models/NutritionLog');
const Food = require('../models/Food');
const { protect } = require('../middleware/auth');

const router = express.Router();

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

module.exports = router;