const express = require('express');
const { protect } = require('../middleware/auth');
const User = require('../models/User');

const router = express.Router();

// All routes require authentication
router.use(protect);

// @desc    Get user profile
// @route   GET /api/users/profile
// @access  Private
router.get('/profile', async (req, res) => {
  try {
    const user = await User.findById(req.user._id).select('-password');
    res.json({
      success: true,
      data: user
    });
  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get user profile'
    });
  }
});

// @desc    Update user profile
// @route   PUT /api/users/profile
// @access  Private
router.put('/profile', async (req, res) => {
  try {
    const allowedFields = [
      'name', 'email', 'age', 'gender', 'height', 'weight',
      'healthConditions', 'dietaryPreferences', 'fitnessGoals',
      'activityLevel', 'avatar', 'bio', 'location'
    ];

    const updates = {};
    allowedFields.forEach(field => {
      if (req.body[field] !== undefined) {
        updates[field] = req.body[field];
      }
    });

    // Recalculate BMI if weight or height changed
    if (updates.weight || updates.height) {
      const weight = updates.weight || req.user.weight;
      const height = updates.height || req.user.height;

      if (weight && height) {
        updates.bmi = weight / ((height / 100) ** 2);
        updates.bmiCategory = getBMICategory(updates.bmi);
      }
    }

    const user = await User.findByIdAndUpdate(
      req.user._id,
      updates,
      { new: true, runValidators: true }
    ).select('-password');

    res.json({
      success: true,
      data: user,
      message: 'Profile updated successfully'
    });
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update profile'
    });
  }
});

// @desc    Update user preferences
// @route   PUT /api/users/preferences
// @access  Private
router.put('/preferences', async (req, res) => {
  try {
    const { notifications, privacy, units, language, theme } = req.body;

    const updates = {};
    if (notifications !== undefined) updates.notifications = notifications;
    if (privacy !== undefined) updates.privacy = privacy;
    if (units !== undefined) updates.units = units;
    if (language !== undefined) updates.language = language;
    if (theme !== undefined) updates.theme = theme;

    const user = await User.findByIdAndUpdate(
      req.user._id,
      { preferences: updates },
      { new: true, runValidators: true }
    ).select('-password');

    res.json({
      success: true,
      data: user.preferences,
      message: 'Preferences updated successfully'
    });
  } catch (error) {
    console.error('Update preferences error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update preferences'
    });
  }
});

// @desc    Get user statistics
// @route   GET /api/users/stats
// @access  Private
router.get('/stats', async (req, res) => {
  try {
    const user = req.user;

    // Get basic stats
    const stats = {
      joinDate: user.createdAt,
      totalLogins: user.loginCount || 0,
      lastLogin: user.lastLogin,
      profileCompleteness: calculateProfileCompleteness(user),
      streakData: {
        currentStreak: user.currentStreak || 0,
        longestStreak: user.longestStreak || 0,
        lastActivityDate: user.lastActivityDate
      },
      achievements: user.achievements || [],
      level: calculateUserLevel(user),
      points: user.points || 0
    };

    res.json({
      success: true,
      data: stats
    });
  } catch (error) {
    console.error('Get stats error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get user statistics'
    });
  }
});

// @desc    Delete user account
// @route   DELETE /api/users/account
// @access  Private
router.delete('/account', async (req, res) => {
  try {
    // Soft delete - mark as inactive instead of removing
    await User.findByIdAndUpdate(req.user._id, {
      isActive: false,
      deletedAt: new Date()
    });

    res.json({
      success: true,
      message: 'Account deactivated successfully'
    });
  } catch (error) {
    console.error('Delete account error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to delete account'
    });
  }
});

// @desc    Upload profile picture
// @route   POST /api/users/upload-avatar
// @access  Private
router.post('/upload-avatar', require('../middleware/upload').single('avatar'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'No file uploaded'
      });
    }

    const avatarUrl = `/uploads/avatars/${req.file.filename}`;

    await User.findByIdAndUpdate(req.user._id, { avatar: avatarUrl });

    res.json({
      success: true,
      data: { avatarUrl },
      message: 'Avatar uploaded successfully'
    });
  } catch (error) {
    console.error('Upload avatar error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to upload avatar'
    });
  }
});

// @desc    Get user dashboard data
// @route   GET /api/users/dashboard
// @access  Private
router.get('/dashboard', async (req, res) => {
  try {
    const user = req.user;

    // Aggregate dashboard data
    const dashboard = {
      profile: {
        name: user.name,
        avatar: user.avatar,
        level: calculateUserLevel(user),
        points: user.points || 0
      },
      health: {
        bmi: user.bmi,
        bmiCategory: user.bmiCategory,
        weight: user.weight,
        height: user.height
      },
      goals: {
        fitnessGoals: user.fitnessGoals,
        dietaryPreferences: user.dietaryPreferences,
        weeklyTargets: {
          workouts: 3,
          waterIntake: 8, // glasses
          sleepHours: 7
        }
      },
      recentActivity: {
        lastWorkout: user.lastWorkoutDate,
        lastMealLog: user.lastMealLogDate,
        streak: user.currentStreak || 0
      },
      notifications: user.notifications || []
    };

    res.json({
      success: true,
      data: dashboard
    });
  } catch (error) {
    console.error('Get dashboard error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get dashboard data'
    });
  }
});

// Helper functions

function getBMICategory(bmi) {
  if (bmi < 18.5) return 'underweight';
  if (bmi < 25) return 'normal';
  if (bmi < 30) return 'overweight';
  return 'obese';
}

function calculateProfileCompleteness(user) {
  const fields = [
    'name', 'email', 'age', 'gender', 'height', 'weight',
    'healthConditions', 'dietaryPreferences', 'fitnessGoals', 'activityLevel'
  ];

  const completedFields = fields.filter(field => {
    const value = user[field];
    return value !== null && value !== undefined &&
           (Array.isArray(value) ? value.length > 0 : String(value).trim() !== '');
  });

  return Math.round((completedFields.length / fields.length) * 100);
}

function calculateUserLevel(user) {
  const points = user.points || 0;
  // Simple leveling system: 100 points per level
  return Math.floor(points / 100) + 1;
}

module.exports = router;