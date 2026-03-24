const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema({
  name: {
    type: String,
    required: [true, 'Name is required'],
    trim: true,
    maxlength: [50, 'Name cannot exceed 50 characters']
  },
  email: {
    type: String,
    required: [true, 'Email is required'],
    unique: true,
    lowercase: true,
    validate: {
      validator: function(email) {
        return /^\w+([.-]?\w+)*@\w+([.-]?\w+)*(\.\w{2,3})+$/.test(email);
      },
      message: 'Please enter a valid email'
    }
  },
  password: {
    type: String,
    required: function() {
      return !this.supabaseId;
    },
    minlength: [6, 'Password must be at least 6 characters'],
    select: false // Don't include password in queries by default
  },
  authProvider: {
    type: String,
    enum: ['email', 'google', 'facebook', 'supabase_oauth'],
    default: 'email'
  },
  supabaseId: {
    type: String,
    unique: true,
    sparse: true
  },
  avatar: {
    type: String,
    default: ''
  },
  phone: {
    type: String,
    default: ''
  },
  dateOfBirth: {
    type: Date
  },
  gender: {
    type: String,
    enum: ['male', 'female', 'other'],
    default: 'other'
  },
  height: {
    type: Number, // in cm
    min: [50, 'Height must be at least 50cm'],
    max: [250, 'Height cannot exceed 250cm']
  },
  weight: {
    type: Number, // in kg
    min: [20, 'Weight must be at least 20kg'],
    max: [300, 'Weight cannot exceed 300kg']
  },
  bmi: {
    type: Number,
    default: 0
  },
  bmiCategory: {
    type: String,
    enum: ['Underweight', 'Normal', 'Overweight', 'Obese'],
    default: 'Normal'
  },
  healthConditions: [{
    type: String,
    enum: ['diabetes', 'hypertension', 'heart_disease', 'asthma', 'thyroid', 'other']
  }],
  allergies: [{
    type: String
  }],
  dietaryPreferences: [{
    type: String,
    enum: ['vegetarian', 'vegan', 'gluten_free', 'dairy_free', 'keto', 'paleo', 'other']
  }],
  fitnessGoals: [{
    type: String,
    enum: ['weight_loss', 'weight_gain', 'muscle_building', 'endurance', 'flexibility', 'general_fitness']
  }],
  activityLevel: {
    type: String,
    enum: ['sedentary', 'lightly_active', 'moderately_active', 'very_active', 'extremely_active'],
    default: 'moderately_active'
  },
  points: {
    type: Number,
    default: 0
  },
  level: {
    type: Number,
    default: 1
  },
  achievements: [{
    title: String,
    description: String,
    icon: String,
    unlockedAt: {
      type: Date,
      default: Date.now
    }
  }],
  location: {
    type: {
      type: String,
      enum: ['Point'],
      default: 'Point'
    },
    coordinates: {
      type: [Number], // [longitude, latitude]
      default: [0, 0]
    },
    address: String,
    city: String,
    country: String
  },
  wearableDevices: [{
    deviceId: String,
    deviceType: {
      type: String,
      enum: ['fitbit', 'apple_watch', 'garmin', 'samsung', 'other']
    },
    connectedAt: {
      type: Date,
      default: Date.now
    },
    lastSync: Date,
    isActive: {
      type: Boolean,
      default: true
    }
  }],
  emergencyContacts: [{
    name: String,
    phone: String,
    relationship: String
  }],
  notifications: {
    email: { type: Boolean, default: true },
    push: { type: Boolean, default: true },
    sms: { type: Boolean, default: false }
  },
  isVerified: {
    type: Boolean,
    default: false
  },
  verificationToken: String,
  resetPasswordToken: String,
  resetPasswordExpire: Date,
  lastLogin: Date,
  isActive: {
    type: Boolean,
    default: true
  }
}, {
  timestamps: true,
  toJSON: { virtuals: true },
  toObject: { virtuals: true }
});

// Index for location-based queries
userSchema.index({ 'location.coordinates': '2dsphere' });

// Virtual for age
userSchema.virtual('age').get(function() {
  if (this.dateOfBirth) {
    return Math.floor((Date.now() - this.dateOfBirth) / (365.25 * 24 * 60 * 60 * 1000));
  }
  return null;
});

// Pre-save middleware to hash password
userSchema.pre('save', async function(next) {
  if (!this.isModified('password')) return next();

  try {
    const salt = await bcrypt.genSalt(12);
    this.password = await bcrypt.hash(this.password, salt);
    next();
  } catch (error) {
    next(error);
  }
});

// Instance method to check password
userSchema.methods.comparePassword = async function(candidatePassword) {
  if (!this.password) {
    return false;
  }
  return await bcrypt.compare(candidatePassword, this.password);
};

// Instance method to calculate BMI
userSchema.methods.calculateBMI = function() {
  if (this.height && this.weight) {
    const heightInMeters = this.height / 100;
    this.bmi = this.weight / (heightInMeters * heightInMeters);

    if (this.bmi < 18.5) {
      this.bmiCategory = 'Underweight';
    } else if (this.bmi < 25) {
      this.bmiCategory = 'Normal';
    } else if (this.bmi < 30) {
      this.bmiCategory = 'Overweight';
    } else {
      this.bmiCategory = 'Obese';
    }

    return this.bmi;
  }
  return null;
};

// Static method to find users with similar health conditions
userSchema.statics.findSimilarUsers = function(userId, conditions, maxDistance = 5000) {
  return this.find({
    _id: { $ne: userId },
    healthConditions: { $in: conditions },
    'location.coordinates': {
      $near: {
        $geometry: {
          type: 'Point',
          coordinates: this.location.coordinates
        },
        $maxDistance: maxDistance
      }
    }
  }).select('name avatar healthConditions location points');
};

module.exports = mongoose.model('User', userSchema);