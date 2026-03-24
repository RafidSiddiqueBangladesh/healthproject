const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const dotenv = require('dotenv');
const path = require('path');
const cookieParser = require('cookie-parser');

// Load environment variables
dotenv.config();

// Import routes (Supabase-only mode)
// Only auth and profile routes are available without MongoDB
const authRoutes = require('./routes/auth');
const profileRoutes = require('./routes/profile');

// TODO: Migrate these routes to use Supabase APIs
// const userRoutes = require('./routes/users');
// const nutritionRoutes = require('./routes/nutrition');
// const exerciseRoutes = require('./routes/exercises');
// const healthRoutes = require('./routes/health');
// const ocrRoutes = require('./routes/ocr');
// const aiRoutes = require('./routes/ai');
// const wearableRoutes = require('./routes/wearable');
// const communityRoutes = require('./routes/community');
// const cookingRoutes = require('./routes/cooking');

// Initialize Express app
const app = express();

const configuredOrigins = (process.env.FRONTEND_URLS || process.env.FRONTEND_URL || '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

const defaultOrigins = [
  'http://localhost:64616',
  'http://localhost:3000',
  'http://127.0.0.1:64616',
  'http://127.0.0.1:3000',
];

const allowedOrigins = new Set([
  ...(configuredOrigins.length > 0 ? configuredOrigins : defaultOrigins),
]);

// Security middleware
app.use(helmet());
app.use(cors({
  origin: (origin, callback) => {
    // Allow non-browser clients (no Origin header).
    if (!origin) {
      callback(null, true);
      return;
    }

    // Allow explicit configured origins.
    if (allowedOrigins.has(origin)) {
      callback(null, true);
      return;
    }

    // Allow localhost origins for dev convenience.
    if (/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin)) {
      callback(null, true);
      return;
    }

    callback(new Error(`CORS blocked for origin: ${origin}`));
  },
  credentials: true
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});
app.use(limiter);

// Body parsing middleware
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));
app.use(cookieParser());

// Static files
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Supabase-only mode
console.log('✅ Running in Supabase-only mode (MongoDB disabled).');

// Routes (Supabase-only mode)
app.use('/api/auth', authRoutes);
app.use('/api/profile', profileRoutes);

// TODO: Enable these routes after migrating to Supabase
// app.use('/api/users', userRoutes);
// app.use('/api/nutrition', nutritionRoutes);
// app.use('/api/exercises', exerciseRoutes);
// app.use('/api/health', healthRoutes);
// app.use('/api/ocr', ocrRoutes);
// app.use('/api/ai', aiRoutes);
// app.use('/api/wearable', wearableRoutes);
// app.use('/api/community', communityRoutes);
// app.use('/api/cooking', cookingRoutes);

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    database: 'supabase-only'
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    success: false,
    message: 'Something went wrong!',
    error: process.env.NODE_ENV === 'development' ? err.message : {}
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    message: 'API endpoint not found'
  });
});

const PORT = process.env.PORT || 5000;

app.listen(PORT, () => {
  console.log(`NutriCare backend server running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
});

module.exports = app;