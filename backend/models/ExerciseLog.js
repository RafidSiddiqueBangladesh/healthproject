const mongoose = require('mongoose');

const exerciseLogSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  exercise: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Exercise',
    required: true
  },
  date: {
    type: Date,
    required: true,
    default: Date.now
  },
  duration: {
    type: Number, // in minutes
    required: true,
    min: [1, 'Duration must be at least 1 minute']
  },
  sets: [{
    setNumber: Number,
    reps: Number,
    weight: Number, // in kg
    restTime: Number, // in seconds
    completed: {
      type: Boolean,
      default: true
    }
  }],
  totalCaloriesBurned: {
    type: Number,
    default: 0
  },
  heartRate: {
    average: Number,
    max: Number,
    zones: {
      fatBurn: Number, // percentage of time in fat burn zone
      cardio: Number,  // percentage of time in cardio zone
      peak: Number     // percentage of time in peak zone
    }
  },
  wearableData: {
    deviceId: String,
    steps: Number,
    distance: Number, // in km
    elevation: Number, // in meters
    rawData: mongoose.Schema.Types.Mixed
  },
  location: {
    latitude: Number,
    longitude: Number,
    address: String
  },
  weather: {
    temperature: Number,
    humidity: Number,
    conditions: String
  },
  mood: {
    before: {
      type: String,
      enum: ['excited', 'neutral', 'tired', 'stressed', 'motivated']
    },
    after: {
      type: String,
      enum: ['accomplished', 'tired', 'energized', 'sore', 'neutral']
    }
  },
  difficulty: {
    type: String,
    enum: ['easy', 'moderate', 'hard', 'very_hard'],
    default: 'moderate'
  },
  notes: {
    type: String,
    maxlength: [500, 'Notes cannot exceed 500 characters']
  },
  isCompleted: {
    type: Boolean,
    default: true
  },
  pointsEarned: {
    type: Number,
    default: 0
  },
  vrArUsed: {
    type: Boolean,
    default: false
  },
  aiFeedback: {
    rating: {
      type: Number,
      min: 1,
      max: 5
    },
    suggestions: [String],
    nextRecommendedExercise: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Exercise'
    }
  }
}, {
  timestamps: true,
  toJSON: { virtuals: true },
  toObject: { virtuals: true }
});

// Indexes
exerciseLogSchema.index({ user: 1, date: -1 });
exerciseLogSchema.index({ user: 1, exercise: 1 });

// Pre-save middleware to calculate points
exerciseLogSchema.pre('save', function(next) {
  // Calculate points based on duration, difficulty, and completion
  let basePoints = this.duration * 2; // 2 points per minute

  const difficultyMultiplier = {
    'easy': 1,
    'moderate': 1.5,
    'hard': 2,
    'very_hard': 2.5
  };

  this.pointsEarned = Math.round(basePoints * (difficultyMultiplier[this.difficulty] || 1));

  // Bonus for VR/AR usage
  if (this.vrArUsed) {
    this.pointsEarned += 10;
  }

  next();
});

// Virtual for total reps completed
exerciseLogSchema.virtual('totalReps').get(function() {
  return this.sets.reduce((total, set) => {
    return total + (set.completed ? set.reps : 0);
  }, 0);
});

// Virtual for total weight lifted
exerciseLogSchema.virtual('totalWeight').get(function() {
  return this.sets.reduce((total, set) => {
    return total + (set.completed ? (set.reps * set.weight) : 0);
  }, 0);
});

// Static method to get daily exercise summary
exerciseLogSchema.statics.getDailySummary = function(userId, date) {
  const startOfDay = new Date(date);
  startOfDay.setHours(0, 0, 0, 0);
  const endOfDay = new Date(date);
  endOfDay.setHours(23, 59, 59, 999);

  return this.aggregate([
    {
      $match: {
        user: mongoose.Types.ObjectId(userId),
        date: { $gte: startOfDay, $lte: endOfDay },
        isCompleted: true
      }
    },
    {
      $group: {
        _id: null,
        totalDuration: { $sum: '$duration' },
        totalCalories: { $sum: '$totalCaloriesBurned' },
        totalPoints: { $sum: '$pointsEarned' },
        exercisesCompleted: { $addToSet: '$exercise' },
        averageHeartRate: { $avg: '$heartRate.average' }
      }
    },
    {
      $project: {
        totalDuration: 1,
        totalCalories: 1,
        totalPoints: 1,
        exerciseCount: { $size: '$exercisesCompleted' },
        averageHeartRate: { $round: ['$averageHeartRate', 0] }
      }
    }
  ]);
};

// Static method to get weekly progress
exerciseLogSchema.statics.getWeeklyProgress = function(userId, startDate) {
  const endDate = new Date(startDate);
  endDate.setDate(endDate.getDate() + 7);

  return this.aggregate([
    {
      $match: {
        user: mongoose.Types.ObjectId(userId),
        date: { $gte: startDate, $lt: endDate },
        isCompleted: true
      }
    },
    {
      $group: {
        _id: {
          $dateToString: { format: '%Y-%m-%d', date: '$date' }
        },
        totalDuration: { $sum: '$duration' },
        totalCalories: { $sum: '$totalCaloriesBurned' },
        totalPoints: { $sum: '$pointsEarned' },
        exercises: { $addToSet: '$exercise' }
      }
    },
    {
      $project: {
        date: '$_id',
        totalDuration: 1,
        totalCalories: 1,
        totalPoints: 1,
        exerciseCount: { $size: '$exercises' }
      }
    },
    {
      $sort: { date: 1 }
    }
  ]);
};

// Static method to get exercise streaks
exerciseLogSchema.statics.getExerciseStreak = function(userId) {
  return this.aggregate([
    {
      $match: {
        user: mongoose.Types.ObjectId(userId),
        isCompleted: true
      }
    },
    {
      $sort: { date: -1 }
    },
    {
      $group: {
        _id: {
          $dateToString: { format: '%Y-%m-%d', date: '$date' }
        },
        exercises: { $sum: 1 }
      }
    },
    {
      $sort: { '_id': -1 }
    },
    {
      $limit: 30
    }
  ]);
};

module.exports = mongoose.model('ExerciseLog', exerciseLogSchema);