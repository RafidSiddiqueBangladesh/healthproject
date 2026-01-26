const express = require('express');
const OpenAI = require('openai');
const { protect } = require('../middleware/auth');
const User = require('../models/User');
const NutritionLog = require('../models/NutritionLog');
const Exercise = require('../models/Exercise');

const router = express.Router();

// Initialize OpenAI
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
});

// All routes require authentication
router.use(protect);

// @desc    Get AI-powered daily routine suggestions
// @route   GET /api/ai/daily-routine
// @access  Private
router.get('/daily-routine', async (req, res) => {
  try {
    const user = req.user;

    // Get recent nutrition data
    const recentLogs = await NutritionLog.find({
      user: user._id,
      date: { $gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) }
    }).populate('foods.food', 'name category');

    // Prepare context for AI
    const context = {
      userProfile: {
        age: user.age,
        gender: user.gender,
        height: user.height,
        weight: user.weight,
        bmi: user.bmi,
        bmiCategory: user.bmiCategory,
        healthConditions: user.healthConditions,
        dietaryPreferences: user.dietaryPreferences,
        fitnessGoals: user.fitnessGoals,
        activityLevel: user.activityLevel
      },
      recentMeals: recentLogs.slice(0, 10).map(log => ({
        meal: log.meal,
        foods: log.foods.map(f => f.food.name),
        date: log.date
      }))
    };

    const prompt = `Based on this user's profile and recent eating habits, suggest a personalized daily meal routine. Consider their health conditions, dietary preferences, and fitness goals.

User Profile:
- Age: ${context.userProfile.age}
- BMI: ${context.userProfile.bmi} (${context.userProfile.bmiCategory})
- Health Conditions: ${context.userProfile.healthConditions.join(', ') || 'None'}
- Dietary Preferences: ${context.userProfile.dietaryPreferences.join(', ') || 'None'}
- Fitness Goals: ${context.userProfile.fitnessGoals.join(', ') || 'General health'}
- Activity Level: ${context.userProfile.activityLevel}

Recent Meals (last 7 days):
${context.recentMeals.map(meal => `${meal.date.toDateString()}: ${meal.meal} - ${meal.foods.join(', ')}`).join('\n')}

Please provide:
1. Breakfast suggestion with specific foods and portions
2. Lunch suggestion with alternatives for cost/health
3. Dinner suggestion
4. Snack recommendations
5. Any specific nutritional advice

Format the response as a JSON object with keys: breakfast, lunch, dinner, snacks, advice`;

    const completion = await openai.chat.completions.create({
      model: "gpt-3.5-turbo",
      messages: [
        { role: "system", content: "You are a professional nutritionist providing personalized meal planning advice." },
        { role: "user", content: prompt }
      ],
      max_tokens: 1000,
      temperature: 0.7
    });

    const aiResponse = completion.choices[0].message.content;

    try {
      const routine = JSON.parse(aiResponse);
      res.json({
        success: true,
        data: routine
      });
    } catch (parseError) {
      // If AI doesn't return valid JSON, return as text
      res.json({
        success: true,
        data: {
          routine: aiResponse,
          advice: "Please consult with a healthcare professional for personalized nutrition advice."
        }
      });
    }
  } catch (error) {
    console.error('AI routine error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to generate AI routine suggestions'
    });
  }
});

// @desc    Get AI-powered food alternatives
// @route   POST /api/ai/food-alternatives
// @access  Private
router.post('/food-alternatives', async (req, res) => {
  try {
    const { foodName, preferences, budget } = req.body;
    const user = req.user;

    const prompt = `Suggest healthy, affordable alternatives to "${foodName}" considering:
- User's dietary preferences: ${user.dietaryPreferences.join(', ') || 'None'}
- Health conditions: ${user.healthConditions.join(', ') || 'None'}
- Budget preference: ${budget || 'moderate'}
- Local/seasonal availability

For each alternative, provide:
1. Alternative food name
2. Why it's a good substitute (health/nutrition benefits)
3. Approximate cost comparison
4. Preparation suggestions

Format as JSON array of objects with keys: name, reason, costComparison, preparation`;

    const completion = await openai.chat.completions.create({
      model: "gpt-3.5-turbo",
      messages: [
        { role: "system", content: "You are a nutrition expert suggesting healthy food alternatives." },
        { role: "user", content: prompt }
      ],
      max_tokens: 800,
      temperature: 0.6
    });

    const aiResponse = completion.choices[0].message.content;

    try {
      const alternatives = JSON.parse(aiResponse);
      res.json({
        success: true,
        data: alternatives
      });
    } catch (parseError) {
      res.json({
        success: true,
        data: [{
          name: "Please check with a nutritionist",
          reason: "AI suggestion parsing failed",
          costComparison: "N/A",
          preparation: "Consult professional"
        }]
      });
    }
  } catch (error) {
    console.error('AI alternatives error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to generate food alternatives'
    });
  }
});

// @desc    Get AI-powered exercise recommendations
// @route   GET /api/ai/exercise-recommendations
// @access  Private
router.get('/exercise-recommendations', async (req, res) => {
  try {
    const user = req.user;
    const { goal, duration, equipment } = req.query;

    // Get user's exercise history
    const recentExercises = await Exercise.find({
      _id: { $in: user.recentExercises || [] }
    }).select('name category difficulty');

    const prompt = `Recommend personalized exercises for this user:

User Profile:
- Age: ${user.age}
- Fitness Goals: ${user.fitnessGoals.join(', ') || goal || 'General fitness'}
- Activity Level: ${user.activityLevel}
- Health Conditions: ${user.healthConditions.join(', ') || 'None'}
- Available Equipment: ${equipment || 'Basic (dumbbells, mat)'}
- Session Duration: ${duration || '30'} minutes

Recent Exercises: ${recentExercises.map(e => e.name).join(', ') || 'None'}

Provide 3-5 exercise recommendations with:
1. Exercise name and type
2. Sets, reps, and duration
3. Difficulty level
4. Benefits for their goals
5. Safety considerations

Format as JSON array of objects with keys: name, type, sets, reps, duration, difficulty, benefits, safety`;

    const completion = await openai.chat.completions.create({
      model: "gpt-3.5-turbo",
      messages: [
        { role: "system", content: "You are a certified fitness trainer providing safe, effective exercise recommendations." },
        { role: "user", content: prompt }
      ],
      max_tokens: 1000,
      temperature: 0.6
    });

    const aiResponse = completion.choices[0].message.content;

    try {
      const recommendations = JSON.parse(aiResponse);
      res.json({
        success: true,
        data: recommendations
      });
    } catch (parseError) {
      res.json({
        success: true,
        data: [{
          name: "Consult a fitness professional",
          type: "General",
          sets: 1,
          reps: 1,
          duration: "30 min",
          difficulty: "Beginner",
          benefits: "Professional guidance recommended",
          safety: "Always consult healthcare provider before starting exercise program"
        }]
      });
    }
  } catch (error) {
    console.error('AI exercise error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to generate exercise recommendations'
    });
  }
});

// @desc    Get AI-powered health insights
// @route   GET /api/ai/health-insights
// @access  Private
router.get('/health-insights', async (req, res) => {
  try {
    const user = req.user;

    // Get recent health data
    const recentNutrition = await NutritionLog.find({
      user: user._id,
      date: { $gte: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) }
    }).select('totalNutrition date');

    const prompt = `Analyze this user's health data and provide insights:

User Profile:
- BMI: ${user.bmi} (${user.bmiCategory})
- Health Conditions: ${user.healthConditions.join(', ') || 'None'}
- Fitness Goals: ${user.fitnessGoals.join(', ') || 'General health'}
- Dietary Preferences: ${user.dietaryPreferences.join(', ') || 'None'}

Recent Nutrition Data (last 30 days):
Average daily calories: ${calculateAverage(recentNutrition, 'calories')}
Average daily protein: ${calculateAverage(recentNutrition, 'protein')}g
Average daily carbs: ${calculateAverage(recentNutrition, 'carbs')}g
Average daily fat: ${calculateAverage(recentNutrition, 'fat')}g

Provide 3-5 actionable health insights with:
1. Insight type (nutrition, exercise, lifestyle)
2. Specific recommendation
3. Expected benefit
4. Implementation difficulty (easy/medium/hard)

Format as JSON array of objects with keys: type, recommendation, benefit, difficulty`;

    const completion = await openai.chat.completions.create({
      model: "gpt-3.5-turbo",
      messages: [
        { role: "system", content: "You are a health and wellness expert providing data-driven insights." },
        { role: "user", content: prompt }
      ],
      max_tokens: 800,
      temperature: 0.5
    });

    const aiResponse = completion.choices[0].message.content;

    try {
      const insights = JSON.parse(aiResponse);
      res.json({
        success: true,
        data: insights
      });
    } catch (parseError) {
      res.json({
        success: true,
        data: [{
          type: "General",
          recommendation: "Maintain balanced nutrition and regular exercise",
          benefit: "Overall health improvement",
          difficulty: "Medium"
        }]
      });
    }
  } catch (error) {
    console.error('AI insights error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to generate health insights'
    });
  }
});

// @desc    AI-powered cooking suggestions
// @route   POST /api/ai/cooking-suggestions
// @access  Private
router.post('/cooking-suggestions', async (req, res) => {
  try {
    const { ingredients, dietaryRestrictions, servings, cuisine } = req.body;
    const user = req.user;

    const prompt = `Create cooking suggestions based on available ingredients:

Available Ingredients: ${ingredients.join(', ')}
Dietary Restrictions: ${dietaryRestrictions || user.dietaryPreferences.join(', ') || 'None'}
Servings: ${servings || 2}
Preferred Cuisine: ${cuisine || 'Any'}
User Health Goals: ${user.fitnessGoals.join(', ') || 'General health'}

Suggest 2-3 recipes with:
1. Recipe name and cuisine type
2. Key ingredients used
3. Simple preparation steps
4. Nutritional benefits
5. Cost-saving tips

Format as JSON array of objects with keys: name, cuisine, ingredients, steps, nutrition, costTips`;

    const completion = await openai.chat.completions.create({
      model: "gpt-3.5-turbo",
      messages: [
        { role: "system", content: "You are a creative chef providing healthy, budget-friendly recipes." },
        { role: "user", content: prompt }
      ],
      max_tokens: 1200,
      temperature: 0.7
    });

    const aiResponse = completion.choices[0].message.content;

    try {
      const suggestions = JSON.parse(aiResponse);
      res.json({
        success: true,
        data: suggestions
      });
    } catch (parseError) {
      res.json({
        success: true,
        data: [{
          name: "Simple Vegetable Stir Fry",
          cuisine: "International",
          ingredients: ingredients.slice(0, 5),
          steps: ["Wash and chop vegetables", "Heat oil in pan", "Add vegetables and stir fry", "Season to taste", "Serve hot"],
          nutrition: "High in vitamins and fiber",
          costTips: "Use seasonal vegetables for better value"
        }]
      });
    }
  } catch (error) {
    console.error('AI cooking error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to generate cooking suggestions'
    });
  }
});

// Helper function to calculate averages
function calculateAverage(logs, nutrient) {
  if (!logs.length) return 0;
  const total = logs.reduce((sum, log) => sum + (log.totalNutrition[nutrient] || 0), 0);
  return Math.round(total / logs.length);
}

module.exports = router;