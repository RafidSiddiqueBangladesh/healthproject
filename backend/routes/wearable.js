const express = require('express');
const { protect } = require('../middleware/auth');
const User = require('../models/User');
const WearableData = require('../models/WearableData');

const router = express.Router();

// All routes require authentication
router.use(protect);

// @desc    Connect wearable device
// @route   POST /api/wearable/connect
// @access  Private
router.post('/connect', async (req, res) => {
  try {
    const { deviceType, deviceId, authToken } = req.body;
    const user = req.user;

    // Validate device type
    const supportedDevices = ['fitbit', 'garmin', 'apple_watch', 'samsung_health', 'google_fit', 'oura_ring'];
    if (!supportedDevices.includes(deviceType)) {
      return res.status(400).json({
        success: false,
        message: 'Unsupported device type'
      });
    }

    // Update user with device connection
    const wearableConnection = {
      deviceType,
      deviceId,
      authToken: authToken, // In production, encrypt this
      connectedAt: new Date(),
      lastSync: null,
      isActive: true
    };

    await User.findByIdAndUpdate(user._id, {
      $push: { wearableDevices: wearableConnection }
    });

    res.json({
      success: true,
      message: `${deviceType} connected successfully`,
      data: {
        deviceType,
        deviceId,
        connectedAt: wearableConnection.connectedAt
      }
    });

  } catch (error) {
    console.error('Wearable connect error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to connect wearable device'
    });
  }
});

// @desc    Sync wearable data
// @route   POST /api/wearable/sync
// @access  Private
router.post('/sync', async (req, res) => {
  try {
    const { deviceType, deviceId, data } = req.body;
    const user = req.user;

    // Validate data structure
    if (!data || typeof data !== 'object') {
      return res.status(400).json({
        success: false,
        message: 'Invalid data format'
      });
    }

    // Process and store wearable data
    const wearableData = new WearableData({
      user: user._id,
      deviceType,
      deviceId,
      data: data,
      syncedAt: new Date()
    });

    await wearableData.save();

    // Update user's wearable sync timestamp
    await User.findOneAndUpdate(
      { _id: user._id, 'wearableDevices.deviceId': deviceId },
      {
        $set: {
          'wearableDevices.$.lastSync': new Date(),
          'wearableDevices.$.lastData': data
        }
      }
    );

    // Process health metrics from wearable data
    await processWearableMetrics(user._id, data);

    res.json({
      success: true,
      message: 'Wearable data synced successfully',
      syncedAt: wearableData.syncedAt
    });

  } catch (error) {
    console.error('Wearable sync error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to sync wearable data'
    });
  }
});

// @desc    Get wearable data summary
// @route   GET /api/wearable/summary
// @access  Private
router.get('/summary', async (req, res) => {
  try {
    const user = req.user;
    const { period = 'week' } = req.query;

    // Calculate date range
    const days = period === 'week' ? 7 : period === 'month' ? 30 : 1;
    const startDate = new Date(Date.now() - days * 24 * 60 * 60 * 1000);

    // Get wearable data
    const wearableData = await WearableData.find({
      user: user._id,
      syncedAt: { $gte: startDate }
    }).sort({ syncedAt: -1 });

    // Aggregate data by device type
    const summary = {
      period,
      devices: {},
      overall: {
        totalSteps: 0,
        totalCalories: 0,
        avgHeartRate: 0,
        totalSleepHours: 0,
        avgActiveMinutes: 0
      },
      trends: {},
      insights: []
    };

    wearableData.forEach(entry => {
      const device = entry.deviceType;

      if (!summary.devices[device]) {
        summary.devices[device] = {
          dataPoints: 0,
          lastSync: null,
          metrics: {}
        };
      }

      summary.devices[device].dataPoints++;
      summary.devices[device].lastSync = entry.syncedAt;

      // Aggregate metrics
      const data = entry.data;
      if (data.steps) summary.overall.totalSteps += data.steps;
      if (data.calories) summary.overall.totalCalories += data.calories;
      if (data.heartRate) {
        if (!summary.devices[device].metrics.heartRate) {
          summary.devices[device].metrics.heartRate = [];
        }
        summary.devices[device].metrics.heartRate.push(data.heartRate);
      }
      if (data.sleepHours) summary.overall.totalSleepHours += data.sleepHours;
      if (data.activeMinutes) summary.overall.avgActiveMinutes += data.activeMinutes;
    });

    // Calculate averages
    Object.keys(summary.devices).forEach(device => {
      const deviceData = summary.devices[device];
      if (deviceData.metrics.heartRate) {
        const rates = deviceData.metrics.heartRate;
        deviceData.metrics.avgHeartRate = rates.reduce((a, b) => a + b, 0) / rates.length;
      }
    });

    // Generate insights
    summary.insights = generateWearableInsights(summary, user);

    res.json({
      success: true,
      data: summary
    });

  } catch (error) {
    console.error('Wearable summary error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get wearable summary'
    });
  }
});

// @desc    Get real-time wearable data
// @route   GET /api/wearable/realtime
// @access  Private
router.get('/realtime', async (req, res) => {
  try {
    const user = req.user;

    // Get latest wearable data (last 24 hours)
    const latestData = await WearableData.find({
      user: user._id,
      syncedAt: { $gte: new Date(Date.now() - 24 * 60 * 60 * 1000) }
    }).sort({ syncedAt: -1 }).limit(10);

    const realtimeData = {
      heartRate: null,
      steps: null,
      calories: null,
      activeMinutes: null,
      sleepQuality: null,
      stressLevel: null,
      lastUpdate: null
    };

    latestData.forEach(entry => {
      const data = entry.data;

      if (data.heartRate && (!realtimeData.heartRate || entry.syncedAt > realtimeData.lastUpdate)) {
        realtimeData.heartRate = data.heartRate;
        realtimeData.lastUpdate = entry.syncedAt;
      }

      if (data.steps) realtimeData.steps = (realtimeData.steps || 0) + data.steps;
      if (data.calories) realtimeData.calories = (realtimeData.calories || 0) + data.calories;
      if (data.activeMinutes) realtimeData.activeMinutes = (realtimeData.activeMinutes || 0) + data.activeMinutes;
      if (data.sleepQuality) realtimeData.sleepQuality = data.sleepQuality;
      if (data.stressLevel) realtimeData.stressLevel = data.stressLevel;
    });

    res.json({
      success: true,
      data: realtimeData
    });

  } catch (error) {
    console.error('Realtime wearable error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get realtime wearable data'
    });
  }
});

// @desc    Disconnect wearable device
// @route   DELETE /api/wearable/disconnect/:deviceId
// @access  Private
router.delete('/disconnect/:deviceId', async (req, res) => {
  try {
    const { deviceId } = req.params;
    const user = req.user;

    await User.findByIdAndUpdate(user._id, {
      $pull: { wearableDevices: { deviceId: deviceId } }
    });

    res.json({
      success: true,
      message: 'Wearable device disconnected successfully'
    });

  } catch (error) {
    console.error('Wearable disconnect error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to disconnect wearable device'
    });
  }
});

// @desc    Get wearable health alerts
// @route   GET /api/wearable/alerts
// @access  Private
router.get('/alerts', async (req, res) => {
  try {
    const user = req.user;

    // Get recent wearable data for analysis
    const recentData = await WearableData.find({
      user: user._id,
      syncedAt: { $gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) }
    }).sort({ syncedAt: -1 });

    const alerts = [];

    if (recentData.length > 0) {
      // Analyze heart rate trends
      const heartRateAlerts = analyzeHeartRate(recentData, user);
      alerts.push(...heartRateAlerts);

      // Analyze sleep patterns
      const sleepAlerts = analyzeSleepPatterns(recentData, user);
      alerts.push(...sleepAlerts);

      // Analyze activity levels
      const activityAlerts = analyzeActivityLevels(recentData, user);
      alerts.push(...activityAlerts);
    }

    res.json({
      success: true,
      data: alerts
    });

  } catch (error) {
    console.error('Wearable alerts error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get wearable alerts'
    });
  }
});

// @desc    Export wearable data
// @route   GET /api/wearable/export
// @access  Private
router.get('/export', async (req, res) => {
  try {
    const user = req.user;
    const { startDate, endDate, format = 'json' } = req.query;

    const query = { user: user._id };
    if (startDate && endDate) {
      query.syncedAt = {
        $gte: new Date(startDate),
        $lte: new Date(endDate)
      };
    }

    const data = await WearableData.find(query).sort({ syncedAt: 1 });

    if (format === 'csv') {
      // Convert to CSV format
      const csvData = convertToCSV(data);
      res.setHeader('Content-Type', 'text/csv');
      res.setHeader('Content-Disposition', 'attachment; filename="wearable-data.csv"');
      res.send(csvData);
    } else {
      // Return JSON
      res.json({
        success: true,
        data: data,
        count: data.length
      });
    }

  } catch (error) {
    console.error('Wearable export error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to export wearable data'
    });
  }
});

// Helper functions

async function processWearableMetrics(userId, data) {
  try {
    // Update user's health metrics based on wearable data
    const updateData = {};

    if (data.weight) updateData.weight = data.weight;
    if (data.bodyFat) updateData.bodyFat = data.bodyFat;
    if (data.muscleMass) updateData.muscleMass = data.muscleMass;
    if (data.bmi) updateData.bmi = data.bmi;

    // Recalculate BMI if weight and height are available
    if (data.weight && data.height) {
      updateData.bmi = data.weight / ((data.height / 100) ** 2);
      updateData.bmiCategory = getBMICategory(updateData.bmi);
    }

    if (Object.keys(updateData).length > 0) {
      await User.findByIdAndUpdate(userId, updateData);
    }
  } catch (error) {
    console.error('Process wearable metrics error:', error);
  }
}

function getBMICategory(bmi) {
  if (bmi < 18.5) return 'underweight';
  if (bmi < 25) return 'normal';
  if (bmi < 30) return 'overweight';
  return 'obese';
}

function generateWearableInsights(summary, user) {
  const insights = [];

  // Steps insight
  if (summary.overall.totalSteps > 0) {
    const dailyAverage = summary.overall.totalSteps / (summary.period === 'week' ? 7 : 30);
    if (dailyAverage < 5000) {
      insights.push({
        type: 'activity',
        severity: 'medium',
        message: 'Your daily step count is below the recommended 10,000 steps. Try to increase your daily activity.',
        recommendation: 'Aim for at least 8,000 steps per day'
      });
    } else if (dailyAverage >= 10000) {
      insights.push({
        type: 'achievement',
        severity: 'low',
        message: 'Great job! You\'re meeting the daily step goal.',
        recommendation: 'Keep up the excellent work!'
      });
    }
  }

  // Sleep insight
  if (summary.overall.totalSleepHours > 0) {
    const dailyAverage = summary.overall.totalSleepHours / (summary.period === 'week' ? 7 : 30);
    if (dailyAverage < 7) {
      insights.push({
        type: 'sleep',
        severity: 'high',
        message: 'You\'re not getting enough sleep. Aim for 7-9 hours per night.',
        recommendation: 'Establish a consistent sleep schedule and create a relaxing bedtime routine'
      });
    }
  }

  // Calories insight
  if (summary.overall.totalCalories > 0) {
    const dailyAverage = summary.overall.totalCalories / (summary.period === 'week' ? 7 : 30);
    const recommended = calculateRecommendedCalories(user);
    if (dailyAverage > recommended * 1.2) {
      insights.push({
        type: 'nutrition',
        severity: 'medium',
        message: 'Your calorie burn is higher than expected. You may need to increase your calorie intake.',
        recommendation: 'Consider eating more nutrient-dense foods'
      });
    }
  }

  return insights;
}

function analyzeHeartRate(data, user) {
  const alerts = [];
  const recentRates = data
    .filter(entry => entry.data.heartRate)
    .map(entry => entry.data.heartRate)
    .slice(0, 10); // Last 10 readings

  if (recentRates.length > 0) {
    const avgRate = recentRates.reduce((a, b) => a + b, 0) / recentRates.length;
    const maxRate = Math.max(...recentRates);
    const minRate = Math.min(...recentRates);

    // Check for abnormal heart rates
    if (avgRate > 100) {
      alerts.push({
        type: 'heart_rate',
        severity: 'high',
        message: 'Your average heart rate is elevated. Consider consulting a healthcare provider.',
        value: avgRate,
        unit: 'bpm'
      });
    }

    if (maxRate > 150) {
      alerts.push({
        type: 'heart_rate',
        severity: 'high',
        message: 'Detected very high heart rate spikes. Please monitor your activity level.',
        value: maxRate,
        unit: 'bpm'
      });
    }

    if (minRate < 50) {
      alerts.push({
        type: 'heart_rate',
        severity: 'medium',
        message: 'Your resting heart rate is quite low. This could be normal for athletes but consult a doctor if you feel fatigued.',
        value: minRate,
        unit: 'bpm'
      });
    }
  }

  return alerts;
}

function analyzeSleepPatterns(data, user) {
  const alerts = [];
  const sleepData = data
    .filter(entry => entry.data.sleepHours)
    .map(entry => entry.data.sleepHours)
    .slice(0, 7); // Last 7 days

  if (sleepData.length > 0) {
    const avgSleep = sleepData.reduce((a, b) => a + b, 0) / sleepData.length;

    if (avgSleep < 6) {
      alerts.push({
        type: 'sleep',
        severity: 'high',
        message: 'Critical: You\'re getting less than 6 hours of sleep per night. This can severely impact your health.',
        value: avgSleep,
        unit: 'hours'
      });
    } else if (avgSleep < 7) {
      alerts.push({
        type: 'sleep',
        severity: 'medium',
        message: 'You\'re getting less than the recommended 7-9 hours of sleep.',
        value: avgSleep,
        unit: 'hours'
      });
    }
  }

  return alerts;
}

function analyzeActivityLevels(data, user) {
  const alerts = [];
  const activityData = data
    .filter(entry => entry.data.activeMinutes)
    .map(entry => entry.data.activeMinutes)
    .slice(0, 7); // Last 7 days

  if (activityData.length > 0) {
    const avgActivity = activityData.reduce((a, b) => a + b, 0) / activityData.length;

    if (avgActivity < 30) {
      alerts.push({
        type: 'activity',
        severity: 'medium',
        message: 'You\'re not meeting the recommended 150 minutes of moderate activity per week.',
        value: avgActivity,
        unit: 'minutes/day'
      });
    }
  }

  return alerts;
}

function convertToCSV(data) {
  if (data.length === 0) return '';

  const headers = ['Date', 'Device Type', 'Device ID', 'Steps', 'Calories', 'Heart Rate', 'Sleep Hours', 'Active Minutes'];
  const rows = data.map(entry => [
    entry.syncedAt.toISOString(),
    entry.deviceType,
    entry.deviceId,
    entry.data.steps || '',
    entry.data.calories || '',
    entry.data.heartRate || '',
    entry.data.sleepHours || '',
    entry.data.activeMinutes || ''
  ]);

  return [headers, ...rows].map(row => row.join(',')).join('\n');
}

function calculateRecommendedCalories(user) {
  // Basic BMR calculation
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

module.exports = router;
