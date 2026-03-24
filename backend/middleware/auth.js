const jwt = require('jsonwebtoken');
const { verifySupabaseAccessToken } = require('../services/supabase_auth');

// Protect routes - require authentication (Supabase-only mode)
exports.protect = async (req, res, next) => {
  try {
    let token;

    // Check for token in header
    if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
      token = req.headers.authorization.split(' ')[1];
    }

    // Check for token in cookies
    if (!token && req.cookies && req.cookies.token) {
      token = req.cookies.token;
    }

    // Make sure token exists
    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'Not authorized to access this route'
      });
    }

    try {
      // Supabase-only mode: verify Supabase access token
      const supabaseUser = await verifySupabaseAccessToken(token);
      
      // Attach lightweight user object with Supabase data
      req.user = {
        _id: supabaseUser.id,
        id: supabaseUser.id,
        name: supabaseUser.user_metadata?.full_name || supabaseUser.user_metadata?.name || (supabaseUser.email || '').split('@')[0] || 'User',
        email: supabaseUser.email,
        role: 'user',
        authProvider: supabaseUser.app_metadata?.provider || 'supabase_oauth',
        lastLogin: new Date(),
        save: async () => {} // No-op for Supabase-only mode
      };


      next();
    } catch (err) {
      return res.status(401).json({
        success: false,
        message: 'Not authorized to access this route'
      });
    }
  } catch (err) {
    return res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
};

// Grant access to specific roles
exports.authorize = (...roles) => {
  return (req, res, next) => {
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: `User role ${req.user.role} is not authorized to access this route`
      });
    }
    next();
  };
};