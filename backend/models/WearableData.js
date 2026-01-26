const mongoose = require('mongoose');

const wearableDataSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  deviceType: {
    type: String,
    required: true,
    enum: ['fitbit', 'garmin', 'apple_watch', 'samsung_health', 'google_fit', 'oura_ring', 'polar', 'whoop', 'other']
  },
  deviceId: {
    type: String,
    required: true
  },
  data: {
    // Common metrics
    steps: Number,
    calories: Number,
    distance: Number, // in meters
    activeMinutes: Number,

    // Heart rate data
    heartRate: Number,
    restingHeartRate: Number,
    maxHeartRate: Number,
    heartRateZones: {
      fatBurn: Number,
      cardio: Number,
      peak: Number
    },

    // Sleep data
    sleepHours: Number,
    sleepQuality: {
      type: String,
      enum: ['poor', 'fair', 'good', 'excellent']
    },
    sleepStages: {
      deep: Number, // minutes
      light: Number, // minutes
      rem: Number, // minutes
      awake: Number // minutes
    },

    // Body metrics
    weight: Number, // in kg
    bodyFat: Number, // percentage
    muscleMass: Number, // in kg
    bmi: Number,
    waterPercentage: Number,

    // Activity data
    workouts: [{
      type: {
        type: String,
        enum: ['running', 'cycling', 'swimming', 'weightlifting', 'yoga', 'other']
      },
      duration: Number, // minutes
      calories: Number,
      distance: Number,
      heartRate: Number
    }],

    // Stress and recovery
    stressLevel: {
      type: String,
      enum: ['low', 'moderate', 'high']
    },
    readiness: Number, // 0-100 scale
    recovery: Number, // 0-100 scale

    // Environmental data
    temperature: Number,
    humidity: Number,
    altitude: Number,

    // Additional custom data
    customMetrics: mongoose.Schema.Types.Mixed
  },
  syncedAt: {
    type: Date,
    default: Date.now
  },
  source: {
    type: String,
    enum: ['api', 'webhook', 'manual', 'bluetooth'],
    default: 'api'
  },
  quality: {
    type: String,
    enum: ['low', 'medium', 'high'],
    default: 'medium'
  }
}, {
  timestamps: true
});

// Indexes for efficient queries
wearableDataSchema.index({ user: 1, syncedAt: -1 });
wearableDataSchema.index({ user: 1, deviceType: 1 });
wearableDataSchema.index({ syncedAt: -1 });

// Virtual for age of data in hours
wearableDataSchema.virtual('ageHours').get(function() {
  return Math.floor((Date.now() - this.syncedAt) / (1000 * 60 * 60));
});

// Method to get daily summary
wearableDataSchema.statics.getDailySummary = async function(userId, date) {
  const startOfDay = new Date(date);
  startOfDay.setHours(0, 0, 0, 0);

  const endOfDay = new Date(date);
  endOfDay.setHours(23, 59, 59, 999);

  const dailyData = await this.find({
    user: userId,
    syncedAt: { $gte: startOfDay, $lte: endOfDay }
  });

  const summary = {
    date: date,
    totalSteps: 0,
    totalCalories: 0,
    totalDistance: 0,
    totalActiveMinutes: 0,
    avgHeartRate: 0,
    totalSleepHours: 0,
    workouts: [],
    dataPoints: dailyData.length
  };

  let heartRateSum = 0;
  let heartRateCount = 0;

  dailyData.forEach(entry => {
    const data = entry.data;

    if (data.steps) summary.totalSteps += data.steps;
    if (data.calories) summary.totalCalories += data.calories;
    if (data.distance) summary.totalDistance += data.distance;
    if (data.activeMinutes) summary.totalActiveMinutes += data.activeMinutes;
    if (data.sleepHours) summary.totalSleepHours += data.sleepHours;

    if (data.heartRate) {
      heartRateSum += data.heartRate;
      heartRateCount++;
    }

    if (data.workouts) {
      summary.workouts.push(...data.workouts);
    }
  });

  if (heartRateCount > 0) {
    summary.avgHeartRate = Math.round(heartRateSum / heartRateCount);
  }

  return summary;
};

// Method to get weekly/monthly trends
wearableDataSchema.statics.getTrends = async function(userId, period = 'week') {
  const days = period === 'week' ? 7 : period === 'month' ? 30 : 7;
  const startDate = new Date(Date.now() - days * 24 * 60 * 60 * 1000);

  const data = await this.find({
    user: userId,
    syncedAt: { $gte: startDate }
  }).sort({ syncedAt: 1 });

  const trends = {
    period,
    metrics: {
      steps: [],
      calories: [],
      heartRate: [],
      sleepHours: [],
      activeMinutes: []
    },
    averages: {},
    trends: {}
  };

  // Group by day
  const dailyData = {};
  data.forEach(entry => {
    const day = entry.syncedAt.toDateString();
    if (!dailyData[day]) {
      dailyData[day] = {
        steps: 0,
        calories: 0,
        heartRate: [],
        sleepHours: 0,
        activeMinutes: 0,
        count: 0
      };
    }

    const dayData = dailyData[day];
    const data = entry.data;

    if (data.steps) dayData.steps += data.steps;
    if (data.calories) dayData.calories += data.calories;
    if (data.heartRate) dayData.heartRate.push(data.heartRate);
    if (data.sleepHours) dayData.sleepHours += data.sleepHours;
    if (data.activeMinutes) dayData.activeMinutes += data.activeMinutes;

    dayData.count++;
  });

  // Calculate daily averages and trends
  Object.keys(dailyData).sort().forEach(day => {
    const dayData = dailyData[day];

    trends.metrics.steps.push({
      date: day,
      value: dayData.steps
    });

    trends.metrics.calories.push({
      date: day,
      value: dayData.calories
    });

    trends.metrics.sleepHours.push({
      date: day,
      value: dayData.sleepHours
    });

    trends.metrics.activeMinutes.push({
      date: day,
      value: dayData.activeMinutes
    });

    if (dayData.heartRate.length > 0) {
      const avgHR = dayData.heartRate.reduce((a, b) => a + b, 0) / dayData.heartRate.length;
      trends.metrics.heartRate.push({
        date: day,
        value: Math.round(avgHR)
      });
    }
  });

  // Calculate overall averages
  trends.averages = {
    steps: Math.round(trends.metrics.steps.reduce((sum, item) => sum + item.value, 0) / trends.metrics.steps.length),
    calories: Math.round(trends.metrics.calories.reduce((sum, item) => sum + item.value, 0) / trends.metrics.calories.length),
    heartRate: Math.round(trends.metrics.heartRate.reduce((sum, item) => sum + item.value, 0) / trends.metrics.heartRate.length),
    sleepHours: Math.round(trends.metrics.sleepHours.reduce((sum, item) => sum + item.value, 0) / trends.metrics.sleepHours.length * 10) / 10,
    activeMinutes: Math.round(trends.metrics.activeMinutes.reduce((sum, item) => sum + item.value, 0) / trends.metrics.activeMinutes.length)
  };

  // Calculate trends (comparing first half vs second half)
  const midPoint = Math.floor(trends.metrics.steps.length / 2);
  if (midPoint > 0) {
    const firstHalf = trends.metrics.steps.slice(0, midPoint);
    const secondHalf = trends.metrics.steps.slice(midPoint);

    const firstAvg = firstHalf.reduce((sum, item) => sum + item.value, 0) / firstHalf.length;
    const secondAvg = secondHalf.reduce((sum, item) => sum + item.value, 0) / secondHalf.length;

    trends.trends.steps = {
      direction: secondAvg > firstAvg ? 'increasing' : secondAvg < firstAvg ? 'decreasing' : 'stable',
      changePercent: Math.round(((secondAvg - firstAvg) / firstAvg) * 100)
    };
  }

  return trends;
};

// Pre-save middleware to validate data
wearableDataSchema.pre('save', function(next) {
  // Ensure at least one metric is present
  const data = this.data;
  const hasData = data.steps || data.calories || data.heartRate || data.sleepHours ||
                  data.weight || data.activeMinutes || data.workouts;

  if (!hasData) {
    return next(new Error('Wearable data must contain at least one health metric'));
  }

  // Validate ranges
  if (data.heartRate && (data.heartRate < 30 || data.heartRate > 250)) {
    return next(new Error('Heart rate must be between 30-250 bpm'));
  }

  if (data.sleepHours && (data.sleepHours < 0 || data.sleepHours > 24)) {
    return next(new Error('Sleep hours must be between 0-24'));
  }

  if (data.weight && (data.weight < 20 || data.weight > 500)) {
    return next(new Error('Weight must be between 20-500 kg'));
  }

  next();
});

module.exports = mongoose.model('WearableData', wearableDataSchema);