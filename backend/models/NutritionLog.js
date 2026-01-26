const mongoose = require('mongoose');

const nutritionLogSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  date: {
    type: Date,
    required: true,
    default: Date.now
  },
  meal: {
    type: String,
    required: true,
    enum: ['breakfast', 'lunch', 'dinner', 'snacks']
  },
  foods: [{
    food: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Food',
      required: true
    },
    quantity: {
      type: Number,
      required: true,
      min: [0.1, 'Quantity must be at least 0.1']
    },
    unit: {
      type: String,
      required: true,
      enum: ['g', 'kg', 'ml', 'l', 'cup', 'tbsp', 'tsp', 'oz', 'lb', 'piece', 'slice'],
      default: 'g'
    },
    calories: {
      type: Number,
      required: true
    },
    nutritionalInfo: {
      protein: Number,
      carbs: Number,
      fat: Number,
      fiber: Number,
      sugar: Number,
      sodium: Number
    }
  }],
  totalNutrition: {
    calories: { type: Number, default: 0 },
    protein: { type: Number, default: 0 },
    carbs: { type: Number, default: 0 },
    fat: { type: Number, default: 0 },
    fiber: { type: Number, default: 0 },
    sugar: { type: Number, default: 0 },
    sodium: { type: Number, default: 0 }
  },
  inputMethod: {
    type: String,
    enum: ['manual', 'voice', 'ocr', 'barcode', 'ai_suggestion'],
    default: 'manual'
  },
  voiceTranscript: {
    type: String,
    default: ''
  },
  ocrImage: {
    type: String,
    default: ''
  },
  aiSuggestions: [{
    foodId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Food'
    },
    confidence: Number,
    reason: String
  }],
  location: {
    latitude: Number,
    longitude: Number,
    address: String
  },
  mood: {
    type: String,
    enum: ['happy', 'sad', 'neutral', 'stressed', 'energetic', 'tired'],
    default: 'neutral'
  },
  notes: {
    type: String,
    maxlength: [500, 'Notes cannot exceed 500 characters']
  },
  isCompleted: {
    type: Boolean,
    default: false
  }
}, {
  timestamps: true,
  toJSON: { virtuals: true },
  toObject: { virtuals: true }
});

// Indexes
nutritionLogSchema.index({ user: 1, date: -1 });
nutritionLogSchema.index({ user: 1, meal: 1, date: -1 });

// Pre-save middleware to calculate totals
nutritionLogSchema.pre('save', function(next) {
  this.totalNutrition = {
    calories: 0,
    protein: 0,
    carbs: 0,
    fat: 0,
    fiber: 0,
    sugar: 0,
    sodium: 0
  };

  this.foods.forEach(item => {
    this.totalNutrition.calories += item.calories;
    if (item.nutritionalInfo) {
      this.totalNutrition.protein += item.nutritionalInfo.protein || 0;
      this.totalNutrition.carbs += item.nutritionalInfo.carbs || 0;
      this.totalNutrition.fat += item.nutritionalInfo.fat || 0;
      this.totalNutrition.fiber += item.nutritionalInfo.fiber || 0;
      this.totalNutrition.sugar += item.nutritionalInfo.sugar || 0;
      this.totalNutrition.sodium += item.nutritionalInfo.sodium || 0;
    }
  });

  next();
});

// Virtual for day total
nutritionLogSchema.virtual('dayTotal').get(async function() {
  const NutritionLog = mongoose.model('NutritionLog');
  const startOfDay = new Date(this.date);
  startOfDay.setHours(0, 0, 0, 0);
  const endOfDay = new Date(this.date);
  endOfDay.setHours(23, 59, 59, 999);

  const logs = await NutritionLog.find({
    user: this.user,
    date: { $gte: startOfDay, $lte: endOfDay }
  });

  return logs.reduce((total, log) => {
    total.calories += log.totalNutrition.calories;
    total.protein += log.totalNutrition.protein;
    total.carbs += log.totalNutrition.carbs;
    total.fat += log.totalNutrition.fat;
    return total;
  }, { calories: 0, protein: 0, carbs: 0, fat: 0 });
});

// Static method to get daily summary
nutritionLogSchema.statics.getDailySummary = function(userId, date) {
  const startOfDay = new Date(date);
  startOfDay.setHours(0, 0, 0, 0);
  const endOfDay = new Date(date);
  endOfDay.setHours(23, 59, 59, 999);

  return this.aggregate([
    {
      $match: {
        user: mongoose.Types.ObjectId(userId),
        date: { $gte: startOfDay, $lte: endOfDay }
      }
    },
    {
      $group: {
        _id: '$meal',
        totalCalories: { $sum: '$totalNutrition.calories' },
        totalProtein: { $sum: '$totalNutrition.protein' },
        totalCarbs: { $sum: '$totalNutrition.carbs' },
        totalFat: { $sum: '$totalNutrition.fat' },
        foodCount: { $sum: { $size: '$foods' } }
      }
    },
    {
      $sort: { _id: 1 }
    }
  ]);
};

// Static method to get weekly summary
nutritionLogSchema.statics.getWeeklySummary = function(userId, startDate) {
  const endDate = new Date(startDate);
  endDate.setDate(endDate.getDate() + 7);

  return this.aggregate([
    {
      $match: {
        user: mongoose.Types.ObjectId(userId),
        date: { $gte: startDate, $lt: endDate }
      }
    },
    {
      $group: {
        _id: {
          $dateToString: { format: '%Y-%m-%d', date: '$date' }
        },
        totalCalories: { $sum: '$totalNutrition.calories' },
        totalProtein: { $sum: '$totalNutrition.protein' },
        totalCarbs: { $sum: '$totalNutrition.carbs' },
        totalFat: { $sum: '$totalNutrition.fat' },
        mealsLogged: { $addToSet: '$meal' }
      }
    },
    {
      $project: {
        date: '$_id',
        totalCalories: 1,
        totalProtein: 1,
        totalCarbs: 1,
        totalFat: 1,
        mealCount: { $size: '$mealsLogged' }
      }
    },
    {
      $sort: { date: 1 }
    }
  ]);
};

module.exports = mongoose.model('NutritionLog', nutritionLogSchema);