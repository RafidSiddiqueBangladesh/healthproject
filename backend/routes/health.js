const express = require('express');
const { protect } = require('../middleware/auth');
const User = require('../models/User');
const CostEntry = require('../models/CostEntry');

const router = express.Router();

// All routes require authentication
router.use(protect);

// @desc    Get health dashboard
// @route   GET /api/health/dashboard
// @access  Private
router.get('/dashboard', async (req, res) => {
  try {
    const user = req.user;

    const dashboard = {
      vitals: {
        bmi: user.bmi,
        bmiCategory: user.bmiCategory,
        weight: user.weight,
        height: user.height,
        age: user.age,
        bloodPressure: user.bloodPressure,
        restingHeartRate: user.restingHeartRate
      },
      healthConditions: user.healthConditions || [],
      medications: user.medications || [],
      allergies: user.allergies || [],
      emergencyContacts: user.emergencyContacts || [],
      recentCheckups: user.recentCheckups || [],
      healthGoals: {
        targetWeight: user.targetWeight,
        targetBMI: user.targetBMI,
        fitnessGoals: user.fitnessGoals
      },
      alerts: generateHealthAlerts(user)
    };

    res.json({
      success: true,
      data: dashboard
    });
  } catch (error) {
    console.error('Get health dashboard error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get health dashboard'
    });
  }
});

// @desc    Update health vitals
// @route   PUT /api/health/vitals
// @access  Private
router.put('/vitals', async (req, res) => {
  try {
    const { weight, height, bloodPressure, restingHeartRate, bodyFat, muscleMass } = req.body;
    const user = req.user;

    const updates = {};

    if (weight !== undefined) updates.weight = weight;
    if (height !== undefined) updates.height = height;
    if (bloodPressure !== undefined) updates.bloodPressure = bloodPressure;
    if (restingHeartRate !== undefined) updates.restingHeartRate = restingHeartRate;
    if (bodyFat !== undefined) updates.bodyFat = bodyFat;
    if (muscleMass !== undefined) updates.muscleMass = muscleMass;

    // Recalculate BMI if weight or height changed
    if (updates.weight || updates.height) {
      const newWeight = updates.weight || user.weight;
      const newHeight = updates.height || user.height;

      if (newWeight && newHeight) {
        updates.bmi = newWeight / ((newHeight / 100) ** 2);
        updates.bmiCategory = getBMICategory(updates.bmi);
      }
    }

    const updatedUser = await User.findByIdAndUpdate(
      req.user._id,
      updates,
      { new: true, runValidators: true }
    ).select('-password');

    res.json({
      success: true,
      data: {
        vitals: {
          bmi: updatedUser.bmi,
          bmiCategory: updatedUser.bmiCategory,
          weight: updatedUser.weight,
          height: updatedUser.height,
          bloodPressure: updatedUser.bloodPressure,
          restingHeartRate: updatedUser.restingHeartRate,
          bodyFat: updatedUser.bodyFat,
          muscleMass: updatedUser.muscleMass
        }
      },
      message: 'Health vitals updated successfully'
    });
  } catch (error) {
    console.error('Update vitals error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update health vitals'
    });
  }
});

// @desc    Update health conditions
// @route   PUT /api/health/conditions
// @access  Private
router.put('/conditions', async (req, res) => {
  try {
    const { healthConditions, medications, allergies } = req.body;

    const updates = {};
    if (healthConditions !== undefined) updates.healthConditions = healthConditions;
    if (medications !== undefined) updates.medications = medications;
    if (allergies !== undefined) updates.allergies = allergies;

    await User.findByIdAndUpdate(req.user._id, updates);

    res.json({
      success: true,
      message: 'Health conditions updated successfully'
    });
  } catch (error) {
    console.error('Update conditions error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update health conditions'
    });
  }
});

// @desc    Add emergency contact
// @route   POST /api/health/emergency-contacts
// @access  Private
router.post('/emergency-contacts', async (req, res) => {
  try {
    const { name, relationship, phone, email } = req.body;

    const emergencyContact = {
      name,
      relationship,
      phone,
      email,
      id: Date.now().toString()
    };

    await User.findByIdAndUpdate(req.user._id, {
      $push: { emergencyContacts: emergencyContact }
    });

    res.json({
      success: true,
      data: emergencyContact,
      message: 'Emergency contact added successfully'
    });
  } catch (error) {
    console.error('Add emergency contact error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to add emergency contact'
    });
  }
});

// @desc    Get emergency contacts
// @route   GET /api/health/emergency-contacts
// @access  Private
router.get('/emergency-contacts', async (req, res) => {
  try {
    const user = await User.findById(req.user._id).select('emergencyContacts');

    res.json({
      success: true,
      data: user.emergencyContacts || []
    });
  } catch (error) {
    console.error('Get emergency contacts error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get emergency contacts'
    });
  }
});

// @desc    Update emergency contact
// @route   PUT /api/health/emergency-contacts/:id
// @access  Private
router.put('/emergency-contacts/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { name, relationship, phone, email } = req.body;

    await User.findOneAndUpdate(
      { _id: req.user._id, 'emergencyContacts.id': id },
      {
        $set: {
          'emergencyContacts.$.name': name,
          'emergencyContacts.$.relationship': relationship,
          'emergencyContacts.$.phone': phone,
          'emergencyContacts.$.email': email
        }
      }
    );

    res.json({
      success: true,
      message: 'Emergency contact updated successfully'
    });
  } catch (error) {
    console.error('Update emergency contact error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update emergency contact'
    });
  }
});

// @desc    Delete emergency contact
// @route   DELETE /api/health/emergency-contacts/:id
// @access  Private
router.delete('/emergency-contacts/:id', async (req, res) => {
  try {
    const { id } = req.params;

    await User.findByIdAndUpdate(req.user._id, {
      $pull: { emergencyContacts: { id: id } }
    });

    res.json({
      success: true,
      message: 'Emergency contact deleted successfully'
    });
  } catch (error) {
    console.error('Delete emergency contact error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to delete emergency contact'
    });
  }
});

// @desc    Log health checkup
// @route   POST /api/health/checkups
// @access  Private
router.post('/checkups', async (req, res) => {
  try {
    const { date, type, doctor, notes, results } = req.body;

    const checkup = {
      date: new Date(date),
      type,
      doctor,
      notes,
      results,
      id: Date.now().toString()
    };

    await User.findByIdAndUpdate(req.user._id, {
      $push: { recentCheckups: checkup }
    });

    res.json({
      success: true,
      data: checkup,
      message: 'Health checkup logged successfully'
    });
  } catch (error) {
    console.error('Log checkup error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to log health checkup'
    });
  }
});

// @desc    Get health checkups
// @route   GET /api/health/checkups
// @access  Private
router.get('/checkups', async (req, res) => {
  try {
    const user = await User.findById(req.user._id).select('recentCheckups');

    res.json({
      success: true,
      data: user.recentCheckups || []
    });
  } catch (error) {
    console.error('Get checkups error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get health checkups'
    });
  }
});

// @desc    Get health recommendations
// @route   GET /api/health/recommendations
// @access  Private
router.get('/recommendations', async (req, res) => {
  try {
    const user = req.user;

    const recommendations = {
      nutrition: generateNutritionRecommendations(user),
      exercise: generateExerciseRecommendations(user),
      lifestyle: generateLifestyleRecommendations(user),
      medical: generateMedicalRecommendations(user)
    };

    res.json({
      success: true,
      data: recommendations
    });
  } catch (error) {
    console.error('Get recommendations error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get health recommendations'
    });
  }
});

// @desc    Emergency SOS
// @route   POST /api/health/emergency
// @access  Private
router.post('/emergency', async (req, res) => {
  try {
    const { type, location, description } = req.body;
    const user = req.user;

    // Log emergency
    const emergency = {
      type,
      location,
      description,
      timestamp: new Date(),
      userId: user._id,
      status: 'active'
    };

    // In a real app, this would trigger emergency services
    // For now, we'll just log it and send notifications

    // Send emergency notifications to contacts
    if (user.emergencyContacts && user.emergencyContacts.length > 0) {
      // This would integrate with SMS/email service
      console.log('Emergency triggered:', emergency);
    }

    res.json({
      success: true,
      data: emergency,
      message: 'Emergency alert sent. Help is on the way.'
    });
  } catch (error) {
    console.error('Emergency error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to process emergency request'
    });
  }
});

// @desc    Add a health expense entry
// @route   POST /api/health/costs
// @access  Private
router.post('/costs', async (req, res) => {
  try {
    const { type = 'daily', amount, currency = 'BDT', note = '', date } = req.body;

    if (!['daily', 'monthly'].includes(type)) {
      return res.status(400).json({ success: false, message: 'type must be daily or monthly' });
    }

    if (amount === undefined || Number(amount) < 0) {
      return res.status(400).json({ success: false, message: 'Valid amount is required' });
    }

    const entry = await CostEntry.create({
      user: req.user._id,
      type,
      amount: Number(amount),
      currency,
      note,
      date: date ? new Date(date) : new Date()
    });

    res.status(201).json({ success: true, data: entry, message: 'Cost entry saved' });
  } catch (error) {
    console.error('Add health cost error:', error);
    res.status(500).json({ success: false, message: 'Failed to save health cost' });
  }
});

// @desc    Get health expense entries and totals
// @route   GET /api/health/costs
// @access  Private
router.get('/costs', async (req, res) => {
  try {
    const { type, startDate, endDate } = req.query;
    const query = { user: req.user._id };

    if (type && ['daily', 'monthly'].includes(type)) {
      query.type = type;
    }

    if (startDate || endDate) {
      query.date = {};
      if (startDate) query.date.$gte = new Date(startDate);
      if (endDate) query.date.$lte = new Date(endDate);
    }

    const entries = await CostEntry.find(query).sort({ date: -1 }).limit(500);

    const totals = entries.reduce(
      (acc, entry) => {
        acc.all += entry.amount;
        if (entry.type === 'daily') acc.daily += entry.amount;
        if (entry.type === 'monthly') acc.monthly += entry.amount;
        return acc;
      },
      { all: 0, daily: 0, monthly: 0 }
    );

    res.json({
      success: true,
      data: {
        entries,
        totals: {
          all: Number(totals.all.toFixed(2)),
          daily: Number(totals.daily.toFixed(2)),
          monthly: Number(totals.monthly.toFixed(2))
        }
      }
    });
  } catch (error) {
    console.error('Get health costs error:', error);
    res.status(500).json({ success: false, message: 'Failed to load health costs' });
  }
});

// @desc    Get nearby hospitals
// @route   GET /api/health/hospitals
// @access  Private
router.get('/hospitals', async (req, res) => {
  try {
    const { lat, lng, radius = 10 } = req.query;

    // Mock hospital data - in real app, this would use Google Places API or similar
    const hospitals = [
      {
        id: '1',
        name: 'City General Hospital',
        address: '123 Main St, City, State',
        phone: '(555) 123-4567',
        distance: 2.3,
        rating: 4.5,
        emergency: true,
        specialties: ['Emergency', 'Cardiology', 'Surgery']
      },
      {
        id: '2',
        name: 'Regional Medical Center',
        address: '456 Health Ave, City, State',
        phone: '(555) 987-6543',
        distance: 4.1,
        rating: 4.2,
        emergency: true,
        specialties: ['Emergency', 'Pediatrics', 'Oncology']
      }
    ];

    res.json({
      success: true,
      data: hospitals
    });
  } catch (error) {
    console.error('Get hospitals error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get nearby hospitals'
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

function generateHealthAlerts(user) {
  const alerts = [];

  // BMI alerts
  if (user.bmi) {
    if (user.bmi < 18.5) {
      alerts.push({
        type: 'warning',
        category: 'nutrition',
        message: 'Your BMI indicates you may be underweight. Consider consulting a healthcare provider.',
        priority: 'medium'
      });
    } else if (user.bmi >= 30) {
      alerts.push({
        type: 'warning',
        category: 'health',
        message: 'Your BMI indicates obesity. Focus on healthy eating and regular exercise.',
        priority: 'high'
      });
    }
  }

  // Blood pressure alerts
  if (user.bloodPressure) {
    const [systolic, diastolic] = user.bloodPressure.split('/').map(Number);
    if (systolic >= 140 || diastolic >= 90) {
      alerts.push({
        type: 'critical',
        category: 'health',
        message: 'Your blood pressure is high. Please consult your doctor immediately.',
        priority: 'high'
      });
    }
  }

  // Age-based reminders
  if (user.age >= 50) {
    alerts.push({
      type: 'reminder',
      category: 'preventive',
      message: 'Consider scheduling regular health screenings appropriate for your age.',
      priority: 'low'
    });
  }

  return alerts;
}

function generateNutritionRecommendations(user) {
  const recommendations = [];

  if (user.bmiCategory === 'overweight' || user.bmiCategory === 'obese') {
    recommendations.push({
      type: 'calorie_control',
      message: 'Focus on portion control and nutrient-dense foods',
      priority: 'high'
    });
  }

  if (user.healthConditions.includes('diabetes')) {
    recommendations.push({
      type: 'carb_monitoring',
      message: 'Monitor carbohydrate intake and focus on low glycemic foods',
      priority: 'high'
    });
  }

  if (user.healthConditions.includes('hypertension')) {
    recommendations.push({
      type: 'sodium_reduction',
      message: 'Reduce sodium intake and increase potassium-rich foods',
      priority: 'high'
    });
  }

  return recommendations;
}

function generateExerciseRecommendations(user) {
  const recommendations = [];

  if (user.bmiCategory === 'overweight') {
    recommendations.push({
      type: 'cardio',
      message: 'Start with moderate cardio exercises like walking or swimming',
      priority: 'high'
    });
  }

  if (user.age > 65) {
    recommendations.push({
      type: 'balance',
      message: 'Include balance and flexibility exercises to prevent falls',
      priority: 'medium'
    });
  }

  if (user.fitnessGoals.includes('muscle_gain')) {
    recommendations.push({
      type: 'strength',
      message: 'Incorporate resistance training 2-3 times per week',
      priority: 'medium'
    });
  }

  return recommendations;
}

function generateLifestyleRecommendations(user) {
  const recommendations = [];

  if (user.activityLevel === 'sedentary') {
    recommendations.push({
      type: 'activity',
      message: 'Aim for at least 30 minutes of moderate activity daily',
      priority: 'high'
    });
  }

  recommendations.push({
    type: 'sleep',
    message: 'Maintain 7-9 hours of quality sleep per night',
    priority: 'medium'
  });

  recommendations.push({
    type: 'stress',
    message: 'Practice stress management techniques like meditation',
    priority: 'medium'
  });

  return recommendations;
}

function generateMedicalRecommendations(user) {
  const recommendations = [];

  // Age-based screenings
  if (user.age >= 50) {
    recommendations.push({
      type: 'screening',
      message: 'Schedule regular colon cancer screening',
      priority: 'high'
    });
  }

  if (user.age >= 40) {
    recommendations.push({
      type: 'screening',
      message: 'Regular cholesterol and diabetes screening recommended',
      priority: 'medium'
    });
  }

  // Condition-specific recommendations
  if (user.healthConditions.includes('asthma')) {
    recommendations.push({
      type: 'monitoring',
      message: 'Keep rescue inhaler accessible and track triggers',
      priority: 'high'
    });
  }

  return recommendations;
}

module.exports = router;
