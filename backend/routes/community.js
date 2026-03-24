const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs').promises;
const { protect } = require('../middleware/auth');
const User = require('../models/User');
const Message = require('../models/Message');

const router = express.Router();

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, 'uploads/messages/'),
  filename: (req, file, cb) => {
    const uniqueSuffix = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
    cb(null, `message-${uniqueSuffix}${path.extname(file.originalname)}`);
  }
});

const messageUpload = multer({
  storage,
  limits: {
    fileSize: 8 * 1024 * 1024,
    files: 5
  },
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) return cb(null, true);
    return cb(new Error('Only image files are allowed'));
  }
});

async function ensureMessageUploadsDir() {
  try {
    await fs.access('uploads/messages/');
  } catch (error) {
    await fs.mkdir('uploads/messages/', { recursive: true });
  }
}

// All routes require authentication
router.use(protect);

// @desc    Get community feed
// @route   GET /api/community/feed
// @access  Private
router.get('/feed', async (req, res) => {
  try {
    const { limit = 20, page = 1, type = 'all' } = req.query;
    const user = req.user;

    // Mock community posts - in real app, this would be a separate collection
    const mockPosts = [
      {
        id: '1',
        author: {
          id: 'user1',
          name: 'Sarah Johnson',
          avatar: '/avatars/sarah.jpg',
          level: 15
        },
        type: 'achievement',
        content: 'Just completed my 100th workout! Feeling amazing! 💪',
        timestamp: new Date(Date.now() - 2 * 60 * 60 * 1000),
        likes: 24,
        comments: 8,
        achievement: {
          type: 'workout_milestone',
          value: 100
        }
      },
      {
        id: '2',
        author: {
          id: 'user2',
          name: 'Mike Chen',
          avatar: '/avatars/mike.jpg',
          level: 22
        },
        type: 'recipe',
        content: 'Made this healthy chicken stir-fry today. So delicious and only 450 calories!',
        image: '/posts/recipe1.jpg',
        timestamp: new Date(Date.now() - 4 * 60 * 60 * 1000),
        likes: 31,
        comments: 12,
        recipe: {
          name: 'Healthy Chicken Stir-Fry',
          calories: 450,
          prepTime: 15,
          cookTime: 10
        }
      },
      {
        id: '3',
        author: {
          id: 'user3',
          name: 'Emma Davis',
          avatar: '/avatars/emma.jpg',
          level: 8
        },
        type: 'question',
        content: 'What are your favorite healthy snacks for work? Looking for ideas that are easy to prepare!',
        timestamp: new Date(Date.now() - 6 * 60 * 60 * 1000),
        likes: 15,
        comments: 23,
        tags: ['snacks', 'work', 'healthy']
      }
    ];

    // Filter by type if specified
    let filteredPosts = mockPosts;
    if (type !== 'all') {
      filteredPosts = mockPosts.filter(post => post.type === type);
    }

    // Paginate
    const startIndex = (parseInt(page) - 1) * parseInt(limit);
    const endIndex = startIndex + parseInt(limit);
    const paginatedPosts = filteredPosts.slice(startIndex, endIndex);

    res.json({
      success: true,
      data: paginatedPosts,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: filteredPosts.length,
        pages: Math.ceil(filteredPosts.length / parseInt(limit))
      }
    });
  } catch (error) {
    console.error('Get community feed error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get community feed'
    });
  }
});

// @desc    Search users
// @route   GET /api/community/search-users
// @access  Private
router.get('/search-users', async (req, res) => {
  try {
    const { query, limit = 10 } = req.query;

    if (!query || query.length < 2) {
      return res.status(400).json({
        success: false,
        message: 'Search query must be at least 2 characters'
      });
    }

    const users = await User.find({
      $and: [
        {
          $or: [
            { name: { $regex: query, $options: 'i' } },
            { email: { $regex: query, $options: 'i' } }
          ]
        },
        { _id: { $ne: req.user._id } }, // Exclude current user
        { isActive: true }
      ]
    })
    .select('name email avatar bio fitnessGoals level points')
    .limit(parseInt(limit));

    const userProfiles = users.map(user => ({
      id: user._id,
      name: user.name,
      email: user.email,
      avatar: user.avatar,
      bio: user.bio,
      fitnessGoals: user.fitnessGoals,
      level: user.level || 1,
      points: user.points || 0,
      isFollowing: false // In real app, check follow relationship
    }));

    res.json({
      success: true,
      data: userProfiles
    });
  } catch (error) {
    console.error('Search users error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to search users'
    });
  }
});

// @desc    Get user profile for community
// @route   GET /api/community/profile/:userId
// @access  Private
router.get('/profile/:userId', async (req, res) => {
  try {
    const { userId } = req.params;

    const user = await User.findById(userId).select('-password -emergencyContacts');

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    const profile = {
      id: user._id,
      name: user.name,
      avatar: user.avatar,
      bio: user.bio,
      location: user.location,
      joinDate: user.createdAt,
      level: user.level || 1,
      points: user.points || 0,
      fitnessGoals: user.fitnessGoals,
      achievements: user.achievements || [],
      stats: {
        totalWorkouts: user.exerciseStats?.totalWorkouts || 0,
        currentStreak: user.exerciseStats?.currentStreak || 0,
        totalCaloriesBurned: user.exerciseStats?.totalCaloriesBurned || 0
      },
      isFollowing: false, // In real app, check follow relationship
      followersCount: 0, // Mock data
      followingCount: 0  // Mock data
    };

    res.json({
      success: true,
      data: profile
    });
  } catch (error) {
    console.error('Get community profile error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get user profile'
    });
  }
});

// @desc    Get leaderboard
// @route   GET /api/community/leaderboard
// @access  Private
router.get('/leaderboard', async (req, res) => {
  try {
    const { type = 'points', period = 'all-time', limit = 50 } = req.query;

    let sortField;
    switch (type) {
      case 'points':
        sortField = 'points';
        break;
      case 'workouts':
        sortField = 'exerciseStats.totalWorkouts';
        break;
      case 'calories':
        sortField = 'exerciseStats.totalCaloriesBurned';
        break;
      case 'streak':
        sortField = 'exerciseStats.currentStreak';
        break;
      default:
        sortField = 'points';
    }

    const users = await User.find({ isActive: true })
      .select('name avatar level points exerciseStats')
      .sort({ [sortField]: -1 })
      .limit(parseInt(limit));

    const leaderboard = users.map((user, index) => ({
      rank: index + 1,
      id: user._id,
      name: user.name,
      avatar: user.avatar,
      level: user.level || 1,
      points: user.points || 0,
      stats: {
        workouts: user.exerciseStats?.totalWorkouts || 0,
        caloriesBurned: user.exerciseStats?.totalCaloriesBurned || 0,
        currentStreak: user.exerciseStats?.currentStreak || 0
      }
    }));

    res.json({
      success: true,
      data: {
        type,
        period,
        leaderboard
      }
    });
  } catch (error) {
    console.error('Get leaderboard error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get leaderboard'
    });
  }
});

// @desc    Get challenges
// @route   GET /api/community/challenges
// @access  Private
router.get('/challenges', async (req, res) => {
  try {
    const { status = 'active' } = req.query;

    // Mock challenges - in real app, this would be a separate collection
    const challenges = [
      {
        id: '1',
        title: '30-Day Fitness Challenge',
        description: 'Complete at least one workout every day for 30 days',
        type: 'fitness',
        duration: 30,
        participants: 1247,
        status: 'active',
        startDate: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000),
        endDate: new Date(Date.now() + 25 * 24 * 60 * 60 * 1000),
        rewards: {
          points: 500,
          badge: 'Fitness Warrior'
        },
        progress: 17 // days completed
      },
      {
        id: '2',
        title: 'Healthy Eating Month',
        description: 'Log all meals and maintain a balanced diet for 30 days',
        type: 'nutrition',
        duration: 30,
        participants: 892,
        status: 'active',
        startDate: new Date(Date.now() - 10 * 24 * 60 * 60 * 1000),
        endDate: new Date(Date.now() + 20 * 24 * 60 * 60 * 1000),
        rewards: {
          points: 400,
          badge: 'Nutrition Master'
        },
        progress: 10
      },
      {
        id: '3',
        title: 'Step Count Challenge',
        description: 'Walk 10,000 steps every day for 14 days',
        type: 'activity',
        duration: 14,
        participants: 2156,
        status: 'upcoming',
        startDate: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000),
        endDate: new Date(Date.now() + 16 * 24 * 60 * 60 * 1000),
        rewards: {
          points: 300,
          badge: 'Step Master'
        },
        progress: 0
      }
    ];

    let filteredChallenges = challenges;
    if (status !== 'all') {
      filteredChallenges = challenges.filter(challenge => challenge.status === status);
    }

    res.json({
      success: true,
      data: filteredChallenges
    });
  } catch (error) {
    console.error('Get challenges error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get challenges'
    });
  }
});

// @desc    Join challenge
// @route   POST /api/community/challenges/:challengeId/join
// @access  Private
router.post('/challenges/:challengeId/join', async (req, res) => {
  try {
    const { challengeId } = req.params;
    const user = req.user;

    // In real app, this would update a challenge participants collection
    // For now, just return success

    res.json({
      success: true,
      message: 'Successfully joined challenge',
      challengeId
    });
  } catch (error) {
    console.error('Join challenge error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to join challenge'
    });
  }
});

// @desc    Get user achievements
// @route   GET /api/community/achievements
// @access  Private
router.get('/achievements', async (req, res) => {
  try {
    const user = req.user;

    const achievements = [
      {
        id: 'first_workout',
        name: 'First Workout',
        description: 'Complete your first workout',
        icon: '🏃',
        unlocked: (user.exerciseStats?.totalWorkouts || 0) > 0,
        unlockedDate: user.createdAt,
        points: 50
      },
      {
        id: 'week_warrior',
        name: 'Week Warrior',
        description: 'Complete workouts for 7 consecutive days',
        icon: '⚔️',
        unlocked: (user.exerciseStats?.longestStreak || 0) >= 7,
        unlockedDate: null,
        points: 200
      },
      {
        id: 'calorie_crusher',
        name: 'Calorie Crusher',
        description: 'Burn 10,000 calories through exercise',
        icon: '🔥',
        unlocked: (user.exerciseStats?.totalCaloriesBurned || 0) >= 10000,
        unlockedDate: null,
        points: 300
      },
      {
        id: 'nutrition_ninja',
        name: 'Nutrition Ninja',
        description: 'Log meals for 30 consecutive days',
        icon: '🥦',
        unlocked: false, // Would need nutrition streak tracking
        unlockedDate: null,
        points: 250
      },
      {
        id: 'social_butterfly',
        name: 'Social Butterfly',
        description: 'Connect with 10 other users',
        icon: '🦋',
        unlocked: false,
        unlockedDate: null,
        points: 150
      }
    ];

    const stats = {
      totalAchievements: achievements.filter(a => a.unlocked).length,
      totalPoints: achievements.filter(a => a.unlocked).reduce((sum, a) => sum + a.points, 0),
      recentAchievements: achievements.filter(a => a.unlocked).slice(0, 3)
    };

    res.json({
      success: true,
      data: {
        achievements,
        stats
      }
    });
  } catch (error) {
    console.error('Get achievements error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get achievements'
    });
  }
});

// @desc    Send message to user (supports text + images)
// @route   POST /api/community/messages
// @access  Private
router.post('/messages', messageUpload.array('images', 5), async (req, res) => {
  try {
    const { recipientId, text = '' } = req.body;
    const sender = req.user;

    if (!recipientId) {
      return res.status(400).json({ success: false, message: 'recipientId is required' });
    }

    if (!text.trim() && (!req.files || req.files.length === 0)) {
      return res.status(400).json({ success: false, message: 'Message text or image is required' });
    }

    const recipient = await User.findById(recipientId);
    if (!recipient) {
      return res.status(404).json({
        success: false,
        message: 'Recipient not found'
      });
    }

    const images = (req.files || []).map((file) => `/uploads/messages/${file.filename}`);

    const messageData = await Message.create({
      sender: sender._id,
      recipient: recipientId,
      text: text.trim(),
      images
    });

    const populated = await Message.findById(messageData._id)
      .populate('sender', 'name avatar')
      .populate('recipient', 'name avatar');

    res.status(201).json({
      success: true,
      data: populated,
      message: 'Message sent successfully'
    });
  } catch (error) {
    console.error('Send message error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to send message'
    });
  }
});

// @desc    Get direct messages (conversation or inbox)
// @route   GET /api/community/messages
// @access  Private
router.get('/messages', async (req, res) => {
  try {
    const { limit = 20, page = 1, userId } = req.query;
    const me = req.user._id;
    const parsedLimit = Number(limit) || 20;
    const parsedPage = Number(page) || 1;

    const baseQuery = userId
      ? {
          $or: [
            { sender: me, recipient: userId },
            { sender: userId, recipient: me }
          ]
        }
      : {
          $or: [{ sender: me }, { recipient: me }]
        };

    const messages = await Message.find(baseQuery)
      .populate('sender', 'name avatar')
      .populate('recipient', 'name avatar')
      .sort({ createdAt: -1 })
      .skip((parsedPage - 1) * parsedLimit)
      .limit(parsedLimit);

    const total = await Message.countDocuments(baseQuery);

    if (userId) {
      await Message.updateMany(
        { sender: userId, recipient: me, readAt: null },
        { $set: { readAt: new Date() } }
      );
    }

    res.json({
      success: true,
      data: messages,
      pagination: {
        page: parsedPage,
        limit: parsedLimit,
        total,
        pages: Math.ceil(total / parsedLimit)
      }
    });
  } catch (error) {
    console.error('Get messages error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get messages'
    });
  }
});

ensureMessageUploadsDir().catch((error) => {
  console.error('Failed to initialize message uploads directory:', error);
});

module.exports = router;
