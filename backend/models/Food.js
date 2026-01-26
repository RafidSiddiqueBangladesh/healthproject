const mongoose = require('mongoose');

const foodSchema = new mongoose.Schema({
  name: {
    type: String,
    required: [true, 'Food name is required'],
    trim: true,
    maxlength: [100, 'Food name cannot exceed 100 characters']
  },
  category: {
    type: String,
    required: true,
    enum: ['vegetables', 'fruits', 'grains', 'proteins', 'dairy', 'fats', 'beverages', 'snacks', 'other'],
    default: 'other'
  },
  nutritionalInfo: {
    calories: {
      type: Number,
      required: true,
      min: [0, 'Calories cannot be negative']
    },
    protein: {
      type: Number,
      default: 0,
      min: [0, 'Protein cannot be negative']
    },
    carbs: {
      type: Number,
      default: 0,
      min: [0, 'Carbs cannot be negative']
    },
    fat: {
      type: Number,
      default: 0,
      min: [0, 'Fat cannot be negative']
    },
    fiber: {
      type: Number,
      default: 0,
      min: [0, 'Fiber cannot be negative']
    },
    sugar: {
      type: Number,
      default: 0,
      min: [0, 'Sugar cannot be negative']
    },
    sodium: {
      type: Number,
      default: 0,
      min: [0, 'Sodium cannot be negative']
    },
    vitamins: {
      vitaminA: { type: Number, default: 0 },
      vitaminC: { type: Number, default: 0 },
      vitaminD: { type: Number, default: 0 },
      vitaminE: { type: Number, default: 0 },
      vitaminK: { type: Number, default: 0 },
      vitaminB12: { type: Number, default: 0 }
    },
    minerals: {
      calcium: { type: Number, default: 0 },
      iron: { type: Number, default: 0 },
      magnesium: { type: Number, default: 0 },
      potassium: { type: Number, default: 0 },
      zinc: { type: Number, default: 0 }
    }
  },
  servingSize: {
    amount: {
      type: Number,
      required: true,
      min: [0, 'Serving size cannot be negative']
    },
    unit: {
      type: String,
      required: true,
      enum: ['g', 'kg', 'ml', 'l', 'cup', 'tbsp', 'tsp', 'oz', 'lb', 'piece', 'slice'],
      default: 'g'
    }
  },
  alternatives: [{
    foodId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Food'
    },
    reason: {
      type: String,
      enum: ['cheaper', 'healthier', 'local', 'seasonal', 'low_calorie', 'high_protein', 'other']
    },
    description: String
  }],
  dietaryTags: [{
    type: String,
    enum: ['vegetarian', 'vegan', 'gluten_free', 'dairy_free', 'keto', 'paleo', 'low_carb', 'high_protein', 'organic', 'local']
  }],
  allergens: [{
    type: String,
    enum: ['nuts', 'dairy', 'eggs', 'soy', 'wheat', 'fish', 'shellfish', 'peanuts', 'sesame', 'sulfites']
  }],
  seasonalAvailability: [{
    type: String,
    enum: ['spring', 'summer', 'fall', 'winter', 'year_round']
  }],
  region: {
    type: String,
    default: 'global'
  },
  priceRange: {
    min: { type: Number, default: 0 },
    max: { type: Number, default: 0 },
    currency: { type: String, default: 'USD' }
  },
  image: {
    type: String,
    default: ''
  },
  barcode: {
    type: String,
    sparse: true,
    unique: true
  },
  verified: {
    type: Boolean,
    default: false
  },
  verifiedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  },
  source: {
    type: String,
    enum: ['manual', 'ocr', 'api', 'user_submitted'],
    default: 'manual'
  },
  popularity: {
    type: Number,
    default: 0
  }
}, {
  timestamps: true,
  toJSON: { virtuals: true },
  toObject: { virtuals: true }
});

// Indexes for better query performance
foodSchema.index({ name: 'text', category: 1 });
foodSchema.index({ category: 1 });
foodSchema.index({ 'dietaryTags': 1 });
foodSchema.index({ barcode: 1 });
foodSchema.index({ verified: 1 });

// Virtual for nutritional density score
foodSchema.virtual('nutritionalDensity').get(function() {
  const nutrients = this.nutritionalInfo;
  const totalNutrients = nutrients.protein + nutrients.fiber + nutrients.vitaminC + nutrients.calcium + nutrients.iron;
  return totalNutrients / nutrients.calories;
});

// Static method to find food alternatives
foodSchema.statics.findAlternatives = function(foodId, preferences = [], budget = 'any') {
  return this.find({
    _id: { $ne: foodId },
    category: this.category,
    dietaryTags: { $in: preferences },
    ...(budget !== 'any' && {
      'priceRange.max': { $lte: budget === 'low' ? 5 : budget === 'medium' ? 15 : 100 }
    })
  }).limit(5);
};

// Static method to search foods
foodSchema.statics.searchFoods = function(query, filters = {}) {
  const searchQuery = {
    $text: { $search: query },
    ...filters
  };

  return this.find(searchQuery, { score: { $meta: 'textScore' } })
    .sort({ score: { $meta: 'textScore' } })
    .limit(20);
};

module.exports = mongoose.model('Food', foodSchema);