const express = require('express');
const jwt = require('jsonwebtoken');
const { protect } = require('../middleware/auth');
const { verifySupabaseAccessToken } = require('../services/supabase_auth');
const { getSupabaseAdmin } = require('../services/supabase_auth');

const router = express.Router();

/**
 * Supabase login endpoint
 * Accepts Supabase access token and verifies it
 * @route   POST /api/auth/supabase-login
 * @access  Public
 */
router.post('/supabase-login', async (req, res) => {
  try {
    const { accessToken, name, avatar } = req.body;

    if (!accessToken) {
      return res.status(400).json({
        success: false,
        message: 'accessToken is required'
      });
    }

    // Verify Supabase token
    const supabaseUser = await verifySupabaseAccessToken(accessToken);
    const email = (supabaseUser.email || '').toLowerCase();

    if (!email) {
      return res.status(400).json({
        success: false,
        message: 'Supabase user has no email'
      });
    }

    const provider = supabaseUser.app_metadata?.provider || 'supabase_oauth';
    const userName =
      name ||
      supabaseUser.user_metadata?.full_name ||
      supabaseUser.user_metadata?.name ||
      email.split('@')[0];

    // Ensure profile row exists for social features/discovery.
    const supabase = getSupabaseAdmin();
    if (supabase) {
      await supabase.from('profiles').upsert(
        {
          id: supabaseUser.id,
          email,
          name: userName,
          avatar_url: avatar || supabaseUser.user_metadata?.avatar_url || '',
          updated_at: new Date().toISOString()
        },
        { onConflict: 'id' }
      );
    }

    // Supabase-only mode: return user data directly without MongoDB
    return res.json({
      success: true,
      message: 'Supabase login successful',
      token: accessToken,
      user: {
        id: supabaseUser.id,
        name: userName,
        email,
        avatar: avatar || supabaseUser.user_metadata?.avatar_url || '',
        points: 0,
        authProvider: provider
      }
    });
  } catch (error) {
    console.error('Supabase login error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error during Supabase login'
    });
  }
});

/**
 * Get current logged in user
 * @route   GET /api/auth/me
 * @access  Private
 */
router.get('/me', protect, async (req, res) => {
  try {
    // User object is populated by auth middleware (Supabase-only)
    res.json({
      success: true,
      user: {
        id: req.user.id || req.user._id,
        name: req.user.name,
        email: req.user.email,
        avatar: req.user.avatar || '',
        points: req.user.points || 0,
        authProvider: req.user.authProvider || 'supabase_oauth'
      }
    });
  } catch (error) {
    console.error('Get user error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

/**
 * Logout user
 * @route   GET /api/auth/logout
 * @access  Private
 */
router.get('/logout', protect, (req, res) => {
  res.json({
    success: true,
    message: 'Logged out successfully. Frontend should clear Supabase session.'
  });
});

// Note: Registration, login, password changes are handled by Supabase client
// All authentication is done via Supabase client and this backend only verifies tokens

module.exports = router;

