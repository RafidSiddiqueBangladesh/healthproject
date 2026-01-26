const mongoose = require('mongoose');

const exerciseSchema = new mongoose.Schema({
  name: {
    type: String,
    required: [true, 'Exercise name is required'],
    trim: true,
    maxlength: [100, 'Exercise name cannot exceed 100 characters']
  },
  category: {
    type: String,
    required: true,
    enum: ['cardio', 'strength', 'flexibility', 'balance', 'sports', 'yoga', 'pilates', 'hiit', 'crossfit', 'other'],
    default: 'other'
  },
  difficulty: {
    type: String,
    enum: ['beginner', 'intermediate', 'advanced'],
    default: 'beginner'
  },
  targetMuscles: [{
    type: String,
    enum: ['chest', 'back', 'shoulders', 'arms', 'core', 'legs', 'glutes', 'full_body', 'cardio']
  }],
  equipment: [{
    type: String,
    enum: ['none', 'dumbbells', 'barbell', 'resistance_bands', 'kettlebell', 'pull_up_bar', 'bench', 'treadmill', 'bike', 'yoga_mat', 'other']
  }],
  instructions: [{
    step: Number,
    description: {
      type: String,
      required: true
    },
    image: String,
    video: String
  }],
  duration: {
    type: Number, // in minutes
    min: [1, 'Duration must be at least 1 minute'],
    max: [180, 'Duration cannot exceed 180 minutes']
  },
  caloriesBurned: {
    type: Number,
    min: [0, 'Calories burned cannot be negative']
  },
  sets: {
    type: Number,
    min: [1, 'Sets must be at least 1'],
    default: 1
  },
  reps: {
    type: Number,
    min: [1, 'Reps must be at least 1']
  },
  restTime: {
    type: Number, // in seconds
    default: 60
  },
  vrArSupported: {
    type: Boolean,
    default: false
  },
  vrArModel: {
    type: String,
    default: ''
  },
  aiRecommendations: {
    suitableFor: [{
      type: String,
      enum: ['weight_loss', 'muscle_gain', 'endurance', 'flexibility', 'stress_relief', 'beginners', 'seniors']
    }],
    contraindications: [{
      type: String,
      enum: ['back_pain', 'knee_pain', 'shoulder_pain', 'pregnancy', 'heart_conditions', 'diabetes']
    }]
  },
  image: {
    type: String,
    default: ''
  },
  video: {
    type: String,
    default: ''
  },
  popularity: {
    type: Number,
    default: 0
  },
  verified: {
    type: Boolean,
    default: false
  },
  createdBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  }
}, {
  timestamps: true,
  toJSON: { virtuals: true },
  toObject: { virtuals: true }
});

// Indexes
exerciseSchema.index({ name: 'text', category: 1 });
exerciseSchema.index({ category: 1, difficulty: 1 });
exerciseSchema.index({ targetMuscles: 1 });
exerciseSchema.index({ 'aiRecommendations.suitableFor': 1 });

// Virtual for estimated calories based on user weight
exerciseSchema.virtual('estimatedCalories').get(function() {
  // This would be calculated based on user data in the application logic
  return this.caloriesBurned || 0;
});

// Static method to find exercises by user profile
exerciseSchema.statics.findByUserProfile = function(userProfile) {
  const { fitnessGoals, healthConditions, activityLevel, age } = userProfile;

  let query = {};

  // Filter by fitness goals
  if (fitnessGoals && fitnessGoals.length > 0) {
    query['aiRecommendations.suitableFor'] = { $in: fitnessGoals };
  }

  // Exclude exercises with contraindications
  if (healthConditions && healthConditions.length > 0) {
    query['aiRecommendations.contraindications'] = { $nin: healthConditions };
  }

  // Adjust difficulty based on activity level and age
  if (activityLevel === 'sedentary' || age > 60) {
    query.difficulty = { $in: ['beginner', 'intermediate'] };
  }

  return this.find(query).limit(20);
};

// Static method to get exercise recommendations
exerciseSchema.statics.getRecommendations = function(userId, preferences = {}) {
  const { category, difficulty, duration, equipment } = preferences;

  let query = { verified: true };

  if (category) query.category = category;
  if (difficulty) query.difficulty = difficulty;
  if (duration) {
    query.duration = { $lte: duration + 15, $gte: duration - 15 };
  }
  if (equipment && equipment.length > 0) {
    query.equipment = { $in: equipment };
  }

  return this.find(query)
    .sort({ popularity: -1 })
    .limit(10);
};

module.exports = mongoose.model('Exercise', exerciseSchema);