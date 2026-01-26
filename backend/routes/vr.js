const express = require('express');
const { protect } = require('../middleware/auth');
const User = require('../models/User');
const Exercise = require('../models/Exercise');
const NutritionLog = require('../models/NutritionLog');

const router = express.Router();

// All routes require authentication
router.use(protect);

// @desc    Get VR exercise session data
// @route   GET /api/vr/exercise-session/:exerciseId
// @access  Private
router.get('/exercise-session/:exerciseId', async (req, res) => {
  try {
    const { exerciseId } = req.params;
    const user = req.user;

    const exercise = await Exercise.findById(exerciseId);
    if (!exercise) {
      return res.status(404).json({
        success: false,
        message: 'Exercise not found'
      });
    }

    // Generate VR session configuration
    const vrSession = {
      exercise: {
        id: exercise._id,
        name: exercise.name,
        category: exercise.category,
        difficulty: exercise.difficulty,
        instructions: exercise.instructions,
        duration: exercise.duration,
        caloriesBurn: exercise.caloriesBurn
      },
      environment: {
        scene: getVRSceneForExercise(exercise.category),
        lighting: 'natural',
        audio: {
          backgroundMusic: true,
          voiceGuidance: true,
          ambientSounds: true
        }
      },
      tracking: {
        bodyParts: getTrackedBodyParts(exercise.category),
        accuracy: 'high',
        feedback: 'real-time'
      },
      gamification: {
        points: exercise.points || 10,
        achievements: getAchievementsForExercise(exercise),
        progressTracking: true
      },
      userCustomization: {
        avatar: user.avatar || 'default',
        environmentPreference: user.vrPreferences?.environment || 'gym',
        difficultyModifier: calculateDifficultyModifier(user, exercise)
      }
    };

    res.json({
      success: true,
      data: vrSession
    });

  } catch (error) {
    console.error('VR exercise session error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to generate VR exercise session'
    });
  }
});

// @desc    Get AR nutrition visualization
// @route   GET /api/ar/nutrition-visualization
// @access  Private
router.get('/nutrition-visualization', async (req, res) => {
  try {
    const user = req.user;
    const { period = 'week' } = req.query;

    // Calculate date range
    const days = period === 'week' ? 7 : period === 'month' ? 30 : 1;
    const startDate = new Date(Date.now() - days * 24 * 60 * 60 * 1000);

    // Get nutrition logs
    const logs = await NutritionLog.find({
      user: user._id,
      date: { $gte: startDate }
    }).sort({ date: 1 });

    // Generate AR visualization data
    const visualization = {
      timeRange: period,
      dataPoints: logs.map(log => ({
        date: log.date,
        nutrition: log.totalNutrition,
        meal: log.meal
      })),
      charts: {
        calories: generateCalorieChart(logs),
        macronutrients: generateMacroChart(logs),
        trends: analyzeNutritionTrends(logs)
      },
      arElements: {
        floatingCharts: true,
        nutrientSpheres: true,
        progressRings: true,
        goalIndicators: true
      },
      interactions: {
        tapToDetail: true,
        swipeToNavigate: true,
        pinchToZoom: true
      },
      goals: {
        dailyCalories: calculateRecommendedCalories(user),
        macroTargets: calculateMacroTargets(user)
      }
    };

    res.json({
      success: true,
      data: visualization
    });

  } catch (error) {
    console.error('AR nutrition visualization error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to generate AR nutrition visualization'
    });
  }
});

// @desc    Get VR meditation/guidance session
// @route   GET /api/vr/meditation-session
// @access  Private
router.get('/meditation-session', async (req, res) => {
  try {
    const user = req.user;
    const { type = 'stress-relief', duration = 10 } = req.query;

    const meditationSession = {
      type: type,
      duration: parseInt(duration),
      environment: {
        scene: getMeditationScene(type),
        lighting: 'soft',
        particles: true,
        breathingGuide: true
      },
      audio: {
        backgroundSounds: getMeditationAudio(type),
        guidedVoice: true,
        binauralBeats: type === 'focus',
        volumeControl: true
      },
      visuals: {
        mandala: true,
        breathingOrb: true,
        energyFlow: true,
        natureElements: true
      },
      tracking: {
        heartRate: true,
        breathing: true,
        focus: true
      },
      personalization: {
        userStressLevel: user.stressLevel || 'moderate',
        preferredScenes: user.vrPreferences?.meditationScenes || ['forest', 'ocean'],
        voicePreference: user.voicePreference || 'calm_female'
      }
    };

    res.json({
      success: true,
      data: meditationSession
    });

  } catch (error) {
    console.error('VR meditation session error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to generate VR meditation session'
    });
  }
});

// @desc    Get AR body scan/health assessment
// @route   GET /api/ar/body-scan
// @access  Private
router.get('/body-scan', async (req, res) => {
  try {
    const user = req.user;

    const bodyScan = {
      userMetrics: {
        height: user.height,
        weight: user.weight,
        bmi: user.bmi,
        bodyFat: user.bodyFat || null,
        muscleMass: user.muscleMass || null
      },
      scanAreas: {
        fullBody: true,
        organs: ['heart', 'lungs', 'liver', 'kidneys'],
        muscles: ['core', 'arms', 'legs', 'back'],
        joints: ['shoulders', 'knees', 'hips', 'ankles']
      },
      visualizations: {
        bodyOutline: true,
        organHighlights: true,
        muscleGroups: true,
        fatDistribution: user.bodyFat ? true : false,
        postureAnalysis: true
      },
      healthIndicators: {
        cardiovascular: calculateCardioHealth(user),
        flexibility: user.flexibility || 'unknown',
        strength: user.strength || 'unknown',
        balance: user.balance || 'unknown'
      },
      recommendations: {
        exercises: getRecommendedExercises(user),
        nutrition: getNutritionRecommendations(user),
        lifestyle: getLifestyleTips(user)
      },
      arFeatures: {
        bodyRotation: true,
        zoomControls: true,
        layerToggling: true,
        measurementTools: true
      }
    };

    res.json({
      success: true,
      data: bodyScan
    });

  } catch (error) {
    console.error('AR body scan error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to generate AR body scan'
    });
  }
});

// @desc    Get VR cooking tutorial
// @route   GET /api/vr/cooking-tutorial/:recipeId
// @access  Private
router.get('/cooking-tutorial/:recipeId', async (req, res) => {
  try {
    const { recipeId } = req.params;
    const user = req.user;

    // For now, create a mock recipe tutorial
    // In production, this would fetch from a recipe database
    const tutorial = {
      recipe: {
        id: recipeId,
        name: 'Healthy Vegetable Stir Fry',
        difficulty: 'easy',
        prepTime: 15,
        cookTime: 10,
        servings: 2
      },
      vrEnvironment: {
        kitchen: 'modern',
        lighting: 'bright',
        tools: ['wok', 'cutting_board', 'knife', 'spatula'],
        ingredients: [
          { name: 'broccoli', quantity: '2 cups', position: 'counter_left' },
          { name: 'carrots', quantity: '2 medium', position: 'counter_right' },
          { name: 'bell_peppers', quantity: '1 cup', position: 'fridge' }
        ]
      },
      steps: [
        {
          step: 1,
          instruction: 'Wash and chop all vegetables',
          duration: 5,
          vrActions: ['pick_up_knife', 'chop_vegetables', 'wash_hands'],
          audioCue: 'chop_chop_chop',
          visualGuide: 'highlight_cutting_board'
        },
        {
          step: 2,
          instruction: 'Heat oil in wok',
          duration: 2,
          vrActions: ['turn_on_stove', 'pour_oil'],
          audioCue: 'sizzle',
          visualGuide: 'show_temperature_gauge'
        }
      ],
      safety: {
        reminders: ['Use oven mitts', 'Keep fingers away from blade'],
        emergency: 'Stop cooking if fire starts'
      },
      nutrition: {
        calories: 250,
        protein: 8,
        carbs: 35,
        fat: 12
      },
      personalization: {
        dietaryAdjustments: user.dietaryPreferences,
        skillLevel: user.cookingSkill || 'beginner'
      }
    };

    res.json({
      success: true,
      data: tutorial
    });

  } catch (error) {
    console.error('VR cooking tutorial error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to generate VR cooking tutorial'
    });
  }
});

// @desc    Save VR/AR session data
// @route   POST /api/vr/save-session
// @access  Private
router.post('/save-session', async (req, res) => {
  try {
    const { sessionType, sessionData, duration, score } = req.body;
    const user = req.user;

    // Update user VR/AR statistics
    const updateData = {
      $inc: {
        [`vrStats.${sessionType}Sessions`]: 1,
        [`vrStats.${sessionType}Time`]: duration,
        [`vrStats.${sessionType}Score`]: score || 0
      },
      $push: {
        [`vrStats.${sessionType}History`]: {
          date: new Date(),
          duration: duration,
          score: score || 0,
          data: sessionData
        }
      }
    };

    // Keep only last 50 sessions
    updateData.$push[`vrStats.${sessionType}History`].$slice = -50;

    await User.findByIdAndUpdate(user._id, updateData);

    res.json({
      success: true,
      message: 'VR/AR session data saved successfully'
    });

  } catch (error) {
    console.error('Save VR session error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to save VR/AR session data'
    });
  }
});

// Helper functions

function getVRSceneForExercise(category) {
  const scenes = {
    cardio: 'running_track',
    strength: 'gym',
    yoga: 'zen_garden',
    pilates: 'studio',
    dance: 'dance_floor',
    martial_arts: 'dojo'
  };
  return scenes[category] || 'gym';
}

function getTrackedBodyParts(category) {
  const tracking = {
    cardio: ['legs', 'arms', 'torso'],
    strength: ['arms', 'shoulders', 'back', 'legs'],
    yoga: ['full_body', 'spine', 'hips'],
    pilates: ['core', 'legs', 'arms'],
    dance: ['full_body', 'hips', 'legs'],
    martial_arts: ['arms', 'legs', 'torso']
  };
  return tracking[category] || ['full_body'];
}

function getAchievementsForExercise(exercise) {
  return [
    {
      name: 'First Rep',
      description: 'Complete your first repetition',
      points: 5,
      unlocked: false
    },
    {
      name: 'Perfect Form',
      description: 'Maintain proper form throughout',
      points: 10,
      unlocked: false
    },
    {
      name: 'Speed Demon',
      description: 'Complete faster than average time',
      points: 15,
      unlocked: false
    }
  ];
}

function calculateDifficultyModifier(user, exercise) {
  const userLevel = user.fitnessLevel || 'beginner';
  const exerciseDifficulty = exercise.difficulty;

  const modifiers = {
    beginner: { easy: 0.8, medium: 1.0, hard: 1.2 },
    intermediate: { easy: 1.0, medium: 1.0, hard: 1.0 },
    advanced: { easy: 1.2, medium: 0.9, hard: 0.8 }
  };

  return modifiers[userLevel]?.[exerciseDifficulty] || 1.0;
}

function generateCalorieChart(logs) {
  return {
    type: 'line',
    data: logs.map(log => ({
      date: log.date,
      calories: log.totalNutrition.calories
    })),
    target: 2000, // Default daily target
    average: logs.reduce((sum, log) => sum + log.totalNutrition.calories, 0) / logs.length
  };
}

function generateMacroChart(logs) {
  const avgMacros = logs.reduce((acc, log) => {
    acc.protein += log.totalNutrition.protein || 0;
    acc.carbs += log.totalNutrition.carbs || 0;
    acc.fat += log.totalNutrition.fat || 0;
    return acc;
  }, { protein: 0, carbs: 0, fat: 0 });

  const count = logs.length;
  return {
    protein: avgMacros.protein / count,
    carbs: avgMacros.carbs / count,
    fat: avgMacros.fat / count
  };
}

function analyzeNutritionTrends(logs) {
  if (logs.length < 2) return { trend: 'insufficient_data' };

  const recent = logs.slice(-7); // Last 7 days
  const earlier = logs.slice(-14, -7); // Previous 7 days

  const recentAvg = recent.reduce((sum, log) => sum + log.totalNutrition.calories, 0) / recent.length;
  const earlierAvg = earlier.reduce((sum, log) => sum + log.totalNutrition.calories, 0) / earlier.length;

  const change = ((recentAvg - earlierAvg) / earlierAvg) * 100;

  return {
    trend: change > 5 ? 'increasing' : change < -5 ? 'decreasing' : 'stable',
    changePercent: change,
    direction: change > 0 ? 'up' : 'down'
  };
}

function calculateRecommendedCalories(user) {
  // Basic BMR calculation (simplified)
  const bmr = user.gender === 'male'
    ? 88.362 + (13.397 * user.weight) + (4.799 * user.height) - (5.677 * user.age)
    : 447.593 + (9.247 * user.weight) + (3.098 * user.height) - (4.330 * user.age);

  const activityMultiplier = {
    sedentary: 1.2,
    light: 1.375,
    moderate: 1.55,
    active: 1.725,
    very_active: 1.9
  };

  return Math.round(bmr * (activityMultiplier[user.activityLevel] || 1.2));
}

function calculateMacroTargets(user) {
  const calories = calculateRecommendedCalories(user);
  return {
    protein: Math.round(calories * 0.15 / 4), // 15% of calories from protein
    carbs: Math.round(calories * 0.55 / 4),   // 55% of calories from carbs
    fat: Math.round(calories * 0.30 / 9)      // 30% of calories from fat
  };
}

function getMeditationScene(type) {
  const scenes = {
    'stress-relief': 'peaceful_forest',
    'focus': 'mountain_summit',
    'sleep': 'starry_night',
    'mindfulness': 'zen_garden',
    'energy': 'sunrise_beach'
  };
  return scenes[type] || 'zen_garden';
}

function getMeditationAudio(type) {
  const audio = {
    'stress-relief': ['gentle_rain', 'soft_waves', 'birdsong'],
    'focus': ['white_noise', 'tibetan_bowls', 'binaural_beats'],
    'sleep': ['whale_sounds', 'crickets', 'wind_chimes'],
    'mindfulness': ['tibetan_bowls', 'nature_ambience'],
    'energy': ['uplifting_music', 'ocean_waves']
  };
  return audio[type] || ['nature_sounds'];
}

function calculateCardioHealth(user) {
  // Simplified cardio health calculation
  let score = 50; // Base score

  if (user.age < 30) score += 10;
  else if (user.age > 60) score -= 10;

  if (user.activityLevel === 'active' || user.activityLevel === 'very_active') score += 15;
  else if (user.activityLevel === 'sedentary') score -= 10;

  if (user.bmi < 25) score += 10;
  else if (user.bmi > 30) score -= 15;

  return Math.max(0, Math.min(100, score));
}

function getRecommendedExercises(user) {
  const recommendations = [];

  if (user.bmi > 25) {
    recommendations.push('cardio', 'strength_training');
  }

  if (user.flexibility === 'poor') {
    recommendations.push('yoga', 'stretching');
  }

  if (user.strength === 'weak') {
    recommendations.push('weight_training', 'bodyweight_exercises');
  }

  return recommendations.length > 0 ? recommendations : ['general_fitness'];
}

function getNutritionRecommendations(user) {
  const recommendations = [];

  if (user.bmi > 25) {
    recommendations.push('reduce_calorie_intake', 'increase_protein');
  }

  if (user.healthConditions.includes('diabetes')) {
    recommendations.push('low_glycemic_foods', 'balanced_meals');
  }

  if (user.dietaryPreferences.includes('vegetarian')) {
    recommendations.push('plant_based_protein', 'iron_rich_foods');
  }

  return recommendations.length > 0 ? recommendations : ['balanced_diet'];
}

function getLifestyleTips(user) {
  const tips = [];

  if (user.activityLevel === 'sedentary') {
    tips.push('increase_daily_activity', 'take_regular_walks');
  }

  if (user.stressLevel === 'high') {
    tips.push('practice_meditation', 'get_enough_sleep');
  }

  return tips.length > 0 ? tips : ['maintain_healthy_habits'];
}

module.exports = router;