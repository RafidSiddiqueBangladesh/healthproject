const express = require('express');
const { protect } = require('../middleware/auth');
const Exercise = require('../models/Exercise');
const ExerciseLog = require('../models/ExerciseLog');
const User = require('../models/User');
const { searchYouTubeVideos } = require('../services/youtube');

const router = express.Router();

// All routes require authentication
router.use(protect);

// @desc    Get all exercises
// @route   GET /api/exercises
// @access  Private
router.get('/', async (req, res) => {
  try {
    const { category, difficulty, search, limit = 20, page = 1 } = req.query;

    const query = {};

    if (category && category !== 'all') {
      query.category = category;
    }

    if (difficulty && difficulty !== 'all') {
      query.difficulty = difficulty;
    }

    if (search) {
      query.$or = [
        { name: { $regex: search, $options: 'i' } },
        { category: { $regex: search, $options: 'i' } },
        { description: { $regex: search, $options: 'i' } }
      ];
    }

    const exercises = await Exercise.find(query)
      .limit(parseInt(limit))
      .skip((parseInt(page) - 1) * parseInt(limit))
      .sort({ name: 1 });

    const total = await Exercise.countDocuments(query);

    res.json({
      success: true,
      data: exercises,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / parseInt(limit))
      }
    });
  } catch (error) {
    console.error('Get exercises error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get exercises'
    });
  }
});

// @desc    Search exercise videos from YouTube
// @route   GET /api/exercises/youtube/search
// @access  Private
router.get('/youtube/search', async (req, res) => {
  try {
    const { q, maxResults = 8 } = req.query;
    if (!q || !String(q).trim()) {
      return res.status(400).json({
        success: false,
        message: 'q query is required'
      });
    }

    const videos = await searchYouTubeVideos({
      query: `${q} exercise tutorial`,
      maxResults: Number(maxResults) || 8
    });

    res.json({ success: true, data: videos });
  } catch (error) {
    console.error('Exercise YouTube search error:', error);
    res.status(500).json({ success: false, message: 'Failed to search exercise videos' });
  }
});

// @desc    Get exercise by ID
// @route   GET /api/exercises/:id
// @access  Private
router.get('/:id', async (req, res) => {
  try {
    const exercise = await Exercise.findById(req.params.id);

    if (!exercise) {
      return res.status(404).json({
        success: false,
        message: 'Exercise not found'
      });
    }

    res.json({
      success: true,
      data: exercise
    });
  } catch (error) {
    console.error('Get exercise error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get exercise'
    });
  }
});

// @desc    Get exercise categories
// @route   GET /api/exercises/categories/list
// @access  Private
router.get('/categories/list', async (req, res) => {
  try {
    const categories = await Exercise.distinct('category');

    res.json({
      success: true,
      data: categories
    });
  } catch (error) {
    console.error('Get categories error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get exercise categories'
    });
  }
});

// @desc    Log exercise completion
// @route   POST /api/exercises/log
// @access  Private
router.post('/log', async (req, res) => {
  try {
    const { exerciseId, duration, sets, reps, weight, notes, date } = req.body;
    const user = req.user;

    // Validate exercise exists
    const exercise = await Exercise.findById(exerciseId);
    if (!exercise) {
      return res.status(404).json({
        success: false,
        message: 'Exercise not found'
      });
    }

    // Calculate calories burned
    const caloriesBurned = calculateCaloriesBurned(exercise, user, duration, sets, reps, weight);

    // Create exercise log
    const exerciseLog = new ExerciseLog({
      user: user._id,
      exercise: exerciseId,
      duration: duration || exercise.duration,
      sets: sets || 1,
      reps: reps || exercise.reps,
      weight: weight || 0,
      caloriesBurned,
      notes,
      date: date ? new Date(date) : new Date()
    });

    await exerciseLog.save();

    // Update user stats
    await updateUserExerciseStats(user._id, exerciseLog);

    // Award points
    const pointsEarned = exercise.points || 10;
    await User.findByIdAndUpdate(user._id, {
      $inc: { points: pointsEarned },
      lastWorkoutDate: new Date()
    });

    res.json({
      success: true,
      data: exerciseLog,
      pointsEarned,
      message: 'Exercise logged successfully'
    });
  } catch (error) {
    console.error('Log exercise error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to log exercise'
    });
  }
});

// @desc    Get user's exercise logs
// @route   GET /api/exercises/logs
// @access  Private
router.get('/logs', async (req, res) => {
  try {
    const { limit = 20, page = 1, startDate, endDate } = req.query;
    const user = req.user;

    const query = { user: user._id };

    if (startDate && endDate) {
      query.date = {
        $gte: new Date(startDate),
        $lte: new Date(endDate)
      };
    }

    const logs = await ExerciseLog.find(query)
      .populate('exercise', 'name category difficulty')
      .limit(parseInt(limit))
      .skip((parseInt(page) - 1) * parseInt(limit))
      .sort({ date: -1 });

    const total = await ExerciseLog.countDocuments(query);

    res.json({
      success: true,
      data: logs,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / parseInt(limit))
      }
    });
  } catch (error) {
    console.error('Get exercise logs error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get exercise logs'
    });
  }
});

// @desc    Get exercise statistics
// @route   GET /api/exercises/stats
// @access  Private
router.get('/stats', async (req, res) => {
  try {
    const user = req.user;
    const { period = 'month' } = req.query;

    // Calculate date range
    const days = period === 'week' ? 7 : period === 'month' ? 30 : 90;
    const startDate = new Date(Date.now() - days * 24 * 60 * 60 * 1000);

    // Get exercise logs for the period
    const logs = await ExerciseLog.find({
      user: user._id,
      date: { $gte: startDate }
    }).populate('exercise', 'category');

    // Calculate statistics
    const stats = {
      period,
      totalWorkouts: logs.length,
      totalDuration: logs.reduce((sum, log) => sum + (log.duration || 0), 0),
      totalCaloriesBurned: logs.reduce((sum, log) => sum + (log.caloriesBurned || 0), 0),
      categoryBreakdown: {},
      weeklyProgress: [],
      personalRecords: {}
    };

    // Category breakdown
    logs.forEach(log => {
      const category = log.exercise?.category || 'other';
      if (!stats.categoryBreakdown[category]) {
        stats.categoryBreakdown[category] = 0;
      }
      stats.categoryBreakdown[category]++;
    });

    // Weekly progress (simplified)
    const weeklyData = {};
    logs.forEach(log => {
      const week = getWeekNumber(log.date);
      if (!weeklyData[week]) {
        weeklyData[week] = { workouts: 0, duration: 0, calories: 0 };
      }
      weeklyData[week].workouts++;
      weeklyData[week].duration += log.duration || 0;
      weeklyData[week].calories += log.caloriesBurned || 0;
    });

    stats.weeklyProgress = Object.entries(weeklyData).map(([week, data]) => ({
      week,
      ...data
    }));

    res.json({
      success: true,
      data: stats
    });
  } catch (error) {
    console.error('Get exercise stats error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get exercise statistics'
    });
  }
});

// @desc    Get recommended exercises
// @route   GET /api/exercises/recommended
// @access  Private
router.get('/recommended', async (req, res) => {
  try {
    const user = req.user;
    const { goal, equipment = 'none', timeLimit } = req.query;

    let query = {};

    // Filter by user's fitness goals
    if (goal) {
      query.category = getExercisesForGoal(goal);
    } else if (user.fitnessGoals && user.fitnessGoals.length > 0) {
      const categories = user.fitnessGoals.flatMap(goal => getExercisesForGoal(goal));
      query.category = { $in: categories };
    }

    // Filter by equipment availability
    if (equipment !== 'full') {
      query.equipment = { $in: ['none', 'minimal'] };
    }

    // Filter by time limit
    if (timeLimit) {
      query.duration = { $lte: parseInt(timeLimit) };
    }

    // Consider user's fitness level
    const userLevel = user.fitnessLevel || 'beginner';
    query.difficulty = getDifficultyForLevel(userLevel);

    const exercises = await Exercise.find(query)
      .limit(10)
      .sort({ difficulty: 1 }); // Start with easier exercises

    res.json({
      success: true,
      data: exercises
    });
  } catch (error) {
    console.error('Get recommended exercises error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get recommended exercises'
    });
  }
});

// @desc    Create custom exercise
// @route   POST /api/exercises/custom
// @access  Private
router.post('/custom', async (req, res) => {
  try {
    const { name, category, difficulty, duration, caloriesBurn, instructions, equipment } = req.body;
    const user = req.user;

    const exercise = new Exercise({
      name,
      category,
      difficulty,
      duration,
      caloriesBurn,
      instructions,
      equipment: equipment || ['none'],
      isCustom: true,
      createdBy: user._id
    });

    await exercise.save();

    res.json({
      success: true,
      data: exercise,
      message: 'Custom exercise created successfully'
    });
  } catch (error) {
    console.error('Create custom exercise error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to create custom exercise'
    });
  }
});

// Helper functions

function calculateCaloriesBurned(exercise, user, duration, sets, reps, weight) {
  // Basic calorie calculation based on exercise and user data
  let baseCalories = exercise.caloriesBurn || 100;

  // Adjust for duration
  const actualDuration = duration || exercise.duration || 30;
  baseCalories = (baseCalories / 30) * actualDuration; // Assuming base is for 30 minutes

  // Adjust for weight
  if (user.weight) {
    baseCalories = baseCalories * (user.weight / 70); // Normalize to 70kg
  }

  // Adjust for intensity (sets, reps, weight)
  if (weight && reps) {
    const volume = sets * reps * weight;
    baseCalories *= (1 + volume / 1000); // Increase based on volume
  }

  return Math.round(baseCalories);
}

async function updateUserExerciseStats(userId, exerciseLog) {
  try {
    const user = await User.findById(userId);

    // Update exercise statistics
    const updates = {
      $inc: {
        'exerciseStats.totalWorkouts': 1,
        'exerciseStats.totalDuration': exerciseLog.duration || 0,
        'exerciseStats.totalCaloriesBurned': exerciseLog.caloriesBurned || 0
      },
      $addToSet: {
        recentExercises: exerciseLog.exercise
      }
    };

    // Update streak
    const today = new Date().toDateString();
    const lastWorkout = user.lastWorkoutDate?.toDateString();

    if (lastWorkout === today) {
      // Already worked out today, don't change streak
    } else if (lastWorkout === new Date(Date.now() - 24 * 60 * 60 * 1000).toDateString()) {
      // Worked out yesterday, increment streak
      updates.$inc['exerciseStats.currentStreak'] = 1;
    } else {
      // Streak broken, reset to 1
      updates['exerciseStats.currentStreak'] = 1;
    }

    // Update longest streak
    const currentStreak = (user.exerciseStats?.currentStreak || 0) + (updates.$inc['exerciseStats.currentStreak'] || 0);
    if (currentStreak > (user.exerciseStats?.longestStreak || 0)) {
      updates['exerciseStats.longestStreak'] = currentStreak;
    }

    await User.findByIdAndUpdate(userId, updates);
  } catch (error) {
    console.error('Update user exercise stats error:', error);
  }
}

function getWeekNumber(date) {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  d.setDate(d.getDate() + 4 - (d.getDay() || 7));
  const yearStart = new Date(d.getFullYear(), 0, 1);
  const weekNo = Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
  return `${d.getFullYear()}-W${weekNo}`;
}

function getExercisesForGoal(goal) {
  const goalCategories = {
    'weight_loss': ['cardio', 'hiit', 'strength'],
    'muscle_gain': ['strength', 'weightlifting', 'bodybuilding'],
    'endurance': ['cardio', 'running', 'cycling'],
    'flexibility': ['yoga', 'pilates', 'stretching'],
    'general_fitness': ['cardio', 'strength', 'yoga'],
    'stress_relief': ['yoga', 'meditation', 'light_cardio']
  };

  return goalCategories[goal.toLowerCase()] || ['cardio'];
}

function getDifficultyForLevel(level) {
  const difficulties = {
    'beginner': ['beginner'],
    'intermediate': ['beginner', 'intermediate'],
    'advanced': ['intermediate', 'advanced']
  };

  return { $in: difficulties[level] || ['beginner'] };
}

module.exports = router;
