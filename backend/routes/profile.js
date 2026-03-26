const express = require('express');
const { protect } = require('../middleware/auth');
const { getSupabaseAdmin } = require('../services/supabase_auth');

const router = express.Router();

const VALID_MOODS = ['Happy', 'Sad', 'Neutral', 'Astonished'];
const VALID_USER_ROLES = ['patient', 'doctor'];
const DEFAULT_MOOD_PALETTE = {
  Happy: 0xFFFFD166,
  Sad: 0xFF7EA8FF,
  Neutral: 0xFF9BE7C4,
  Astonished: 0xFFFF9E7A
};
const DEFAULT_THEME_PREFERENCES = {
  isLight: false,
  primaryHue: 220,
  accentHue: 281,
  orbHues: [263, 239, 276, 162, 24]
};
const DEFAULT_MOOD_THEMES = {
  Happy: {
    isLight: false,
    primaryHue: 44,
    accentHue: 18,
    orbHues: [44, 20, 355, 72, 108]
  },
  Sad: {
    isLight: false,
    primaryHue: 220,
    accentHue: 258,
    orbHues: [220, 244, 266, 196, 176]
  },
  Neutral: {
    isLight: false,
    primaryHue: 158,
    accentHue: 205,
    orbHues: [158, 184, 205, 228, 140]
  },
  Astonished: {
    isLight: false,
    primaryHue: 16,
    accentHue: 332,
    orbHues: [16, 342, 294, 52, 24]
  }
};

// All profile routes require authentication
router.use(protect);

function getAuthUser(req) {
  const id = req.user?.id || req.user?._id;
  if (!id) {
    throw new Error('Authenticated user id not found');
  }

  return {
    id,
    email: req.user?.email || '',
    name: req.user?.name || 'User',
    avatar: req.user?.avatar || ''
  };
}

function tableMissing(error) {
  return !!(
    error &&
    (
      error.code === '42P01' || // Postgres: relation does not exist
      error.code === 'PGRST205' || // PostgREST: table not found in schema cache
      /relation .* does not exist/i.test(error.message || '') ||
      /could not find the table/i.test(error.message || '')
    )
  );
}

function normalizePalette(input) {
  const source = input && typeof input === 'object' ? input : {};
  const normalized = { ...DEFAULT_MOOD_PALETTE };
  for (const mood of VALID_MOODS) {
    const raw = source[mood];
    if (typeof raw === 'number' && Number.isFinite(raw)) {
      normalized[mood] = Math.trunc(raw);
    }
  }
  return normalized;
}

function normalizeTheme(input) {
  const source = input && typeof input === 'object' ? input : {};
  const orbInput = Array.isArray(source.orbHues) ? source.orbHues : DEFAULT_THEME_PREFERENCES.orbHues;
  const orbHues = orbInput
    .map((v) => Number(v))
    .filter((v) => Number.isFinite(v))
    .slice(0, 8);

  return {
    isLight: source.isLight === true,
    primaryHue: Number.isFinite(Number(source.primaryHue)) ? Number(source.primaryHue) : DEFAULT_THEME_PREFERENCES.primaryHue,
    accentHue: Number.isFinite(Number(source.accentHue)) ? Number(source.accentHue) : DEFAULT_THEME_PREFERENCES.accentHue,
    orbHues: orbHues.length > 0 ? orbHues : [...DEFAULT_THEME_PREFERENCES.orbHues]
  };
}

function normalizeMoodThemes(input) {
  const source = input && typeof input === 'object' ? input : {};
  const result = {};
  for (const mood of VALID_MOODS) {
    result[mood] = normalizeTheme(source[mood] || DEFAULT_MOOD_THEMES[mood]);
  }
  return result;
}

function normalizeUserRole(input) {
  const raw = String(input || '').trim().toLowerCase();
  if (raw === 'parent') return 'patient';
  return VALID_USER_ROLES.includes(raw) ? raw : 'patient';
}

function mapThemePreferences(row) {
  const selectedMood = VALID_MOODS.includes(row?.selected_mood) ? row.selected_mood : 'Neutral';
  const moodThemes = normalizeMoodThemes(row?.mood_themes);

  // Backward compatibility for rows saved before mood_themes existed.
  if (!row?.mood_themes) {
    moodThemes[selectedMood] = normalizeTheme({
      isLight: row?.is_light,
      primaryHue: row?.primary_hue,
      accentHue: row?.accent_hue,
      orbHues: row?.orb_hues
    });
  }

  return {
    moodPalette: normalizePalette(row?.mood_palette),
    selectedMood,
    moodThemes,
    theme: moodThemes[selectedMood]
  };
}

function mapProfile(row) {
  return {
    _id: row.id,
    id: row.id,
    name: row.name || 'User',
    email: row.email || '',
    avatar: row.avatar_url || '',
    role: normalizeUserRole(row.role),
    points: row.points || 0,
    bmi: row.bmi ?? null,
    heightCm: row.height_cm ?? null,
    weightKg: row.weight_kg ?? null
  };
}

async function ensureOwnProfile(supabase, authUser) {
  const { data: existingProfile, error: existingProfileError } = await supabase
    .from('profiles')
    .select('avatar_url')
    .eq('id', authUser.id)
    .maybeSingle();

  if (existingProfileError && !tableMissing(existingProfileError)) {
    throw existingProfileError;
  }

  const existingAvatar = (existingProfile?.avatar_url || '').trim();
  const upsertPayload = {
    id: authUser.id,
    email: authUser.email,
    name: authUser.name,
    updated_at: new Date().toISOString()
  };

  // Only seed avatar_url from auth metadata when profile has no stored avatar.
  // This avoids reverting uploaded profile images to stale provider avatars.
  if (!existingAvatar && authUser.avatar && String(authUser.avatar).trim().length > 0) {
    upsertPayload.avatar_url = String(authUser.avatar).trim();
  }

  const { error } = await supabase
    .from('profiles')
    .upsert(upsertPayload, { onConflict: 'id' });

  if (error && !tableMissing(error)) {
    throw error;
  }
}

// @desc    Get current user profile
// @route   GET /api/profile/me
// @access  Private
router.get('/me', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    if (!supabase) {
      return res.status(500).json({ success: false, message: 'Supabase is not configured' });
    }

    const authUser = getAuthUser(req);
    await ensureOwnProfile(supabase, authUser);

    const { data, error } = await supabase
      .from('profiles')
      .select('id, name, email, avatar_url, role, points, bmi, height_cm, weight_kg')
      .eq('id', authUser.id)
      .maybeSingle();

    if (error && !tableMissing(error)) {
      throw error;
    }

    const profile = data
      ? mapProfile(data)
      : {
          _id: authUser.id,
          id: authUser.id,
          name: authUser.name,
          email: authUser.email,
          avatar: authUser.avatar,
          role: 'patient',
          points: 0,
          bmi: null,
          heightCm: null,
          weightKg: null
        };

    return res.json({ success: true, data: profile });
  } catch (error) {
    console.error('Get profile error:', error);
    return res.status(500).json({ success: false, message: 'Failed to get profile' });
  }
});

// @desc    Upsert current user profile details (BMI and others)
// @route   PUT /api/profile/me
// @access  Private
router.put('/me', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    if (!supabase) {
      return res.status(500).json({ success: false, message: 'Supabase is not configured' });
    }

    const authUser = getAuthUser(req);
    const { name, avatar, role, points, bmi, heightCm, weightKg } = req.body || {};

    const upsertPayload = {
      id: authUser.id,
      email: authUser.email,
      name: name || authUser.name,
      points: Number.isFinite(points) ? Number(points) : 0,
      bmi: bmi ?? null,
      height_cm: heightCm ?? null,
      weight_kg: weightKg ?? null,
      updated_at: new Date().toISOString()
    };

    if (role != null) {
      upsertPayload.role = normalizeUserRole(role);
    }

    // Do not overwrite avatar_url unless the client explicitly sends a non-empty avatar.
    if (typeof avatar === 'string' && avatar.trim().length > 0) {
      upsertPayload.avatar_url = avatar.trim();
    }

    const { data, error } = await supabase
      .from('profiles')
      .upsert(upsertPayload, { onConflict: 'id' })
      .select('id, name, email, avatar_url, role, points, bmi, height_cm, weight_kg')
      .single();

    if (error) {
      if (tableMissing(error)) {
        return res.status(503).json({
          success: false,
          message: 'Supabase tables are not initialized yet. Please run the SQL setup script (profiles, friendships, messages, nutrition_logs, cooking_items).'
        });
      }
      throw error;
    }

    return res.json({ success: true, data: mapProfile(data) });
  } catch (error) {
    console.error('Update profile error:', error);
    return res.status(500).json({ success: false, message: 'Failed to update profile' });
  }
});

// @desc    Upload profile image and update avatar_url
// @route   POST /api/profile/upload-profile-image
// @access  Private
router.post('/upload-profile-image', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    if (!supabase) {
      return res.status(500).json({ success: false, message: 'Supabase is not configured' });
    }

    const authUser = getAuthUser(req);
    const { base64Image, mimeType } = req.body || {};

    if (!base64Image || typeof base64Image !== 'string') {
      return res.status(400).json({ success: false, message: 'base64Image is required' });
    }

    let payloadBase64 = base64Image.trim();
    let resolvedMime = typeof mimeType === 'string' && mimeType.trim() ? mimeType.trim() : 'image/jpeg';

    const dataUrlMatch = payloadBase64.match(/^data:([^;]+);base64,(.+)$/);
    if (dataUrlMatch) {
      resolvedMime = dataUrlMatch[1] || resolvedMime;
      payloadBase64 = dataUrlMatch[2] || '';
    }

    if (!payloadBase64) {
      return res.status(400).json({ success: false, message: 'Invalid image payload' });
    }

    const buffer = Buffer.from(payloadBase64, 'base64');
    if (!buffer || buffer.length === 0) {
      return res.status(400).json({ success: false, message: 'Invalid image data' });
    }

    const extByMime = {
      'image/jpeg': 'jpg',
      'image/jpg': 'jpg',
      'image/png': 'png',
      'image/webp': 'webp',
      'image/gif': 'gif'
    };
    const ext = extByMime[resolvedMime.toLowerCase()] || 'jpg';
    const filePath = `${authUser.id}/profiles/${Date.now()}.${ext}`;

    const { error: uploadError } = await supabase.storage
      .from('profile-images')
      .upload(filePath, buffer, {
        contentType: resolvedMime,
        upsert: true
      });

    if (uploadError) {
      throw uploadError;
    }

    const { data: publicData } = supabase.storage.from('profile-images').getPublicUrl(filePath);
    const avatarUrl = publicData?.publicUrl || '';

    // Keep auth metadata aligned so fresh sessions also carry the latest avatar URL.
    try {
      await supabase.auth.admin.updateUserById(authUser.id, {
        user_metadata: { avatar_url: avatarUrl }
      });
    } catch (metadataError) {
      console.warn('Failed to update auth user metadata avatar_url:', metadataError?.message || metadataError);
    }

    const { data, error } = await supabase
      .from('profiles')
      .upsert(
        {
          id: authUser.id,
          email: authUser.email,
          name: authUser.name,
          avatar_url: avatarUrl,
          updated_at: new Date().toISOString()
        },
        { onConflict: 'id' }
      )
      .select('id, name, email, avatar_url, role, points, bmi, height_cm, weight_kg')
      .single();

    if (error) {
      if (tableMissing(error)) {
        return res.status(503).json({ success: false, message: 'Supabase tables are not initialized yet.' });
      }
      throw error;
    }

    return res.status(201).json({
      success: true,
      message: 'Profile image uploaded',
      data: mapProfile(data)
    });
  } catch (error) {
    console.error('Upload profile image error:', error);
    return res.status(500).json({ success: false, message: 'Failed to upload profile image' });
  }
});

// @desc    Get current user's app role
// @route   GET /api/profile/role
// @access  Private
router.get('/role', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    const authUser = getAuthUser(req);

    await ensureOwnProfile(supabase, authUser);

    const { data, error } = await supabase
      .from('profiles')
      .select('id, role')
      .eq('id', authUser.id)
      .maybeSingle();

    if (error) {
      if (tableMissing(error)) {
        return res.status(503).json({ success: false, message: 'Supabase table profiles is missing.' });
      }
      throw error;
    }

    return res.json({
      success: true,
      data: {
        role: normalizeUserRole(data?.role)
      }
    });
  } catch (error) {
    console.error('Get profile role error:', error);
    return res.status(500).json({ success: false, message: 'Failed to get profile role' });
  }
});

// @desc    Save current user's app role
// @route   PUT /api/profile/role
// @access  Private
router.put('/role', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    const authUser = getAuthUser(req);
    const nextRole = normalizeUserRole(req.body?.role);

    const { data: existing, error: existingError } = await supabase
      .from('profiles')
      .select('id, role')
      .eq('id', authUser.id)
      .maybeSingle();

    if (existingError) {
      if (tableMissing(existingError)) {
        return res.status(503).json({ success: false, message: 'Supabase table profiles is missing.' });
      }
      throw existingError;
    }

    const currentRole = normalizeUserRole(existing?.role);
    if (currentRole === 'patient' && nextRole === 'doctor') {
      return res.status(403).json({
        success: false,
        message: 'Patient role is locked and cannot be changed to doctor.'
      });
    }

    const { data, error } = await supabase
      .from('profiles')
      .upsert(
        {
          id: authUser.id,
          email: authUser.email,
          name: authUser.name,
          role: nextRole,
          updated_at: new Date().toISOString()
        },
        { onConflict: 'id' }
      )
      .select('id, role')
      .single();

    if (error) {
      if (tableMissing(error)) {
        return res.status(503).json({ success: false, message: 'Supabase table profiles is missing.' });
      }
      throw error;
    }

    return res.json({ success: true, data: { role: normalizeUserRole(data?.role) } });
  } catch (error) {
    console.error('Save profile role error:', error);
    return res.status(500).json({ success: false, message: 'Failed to save profile role' });
  }
});

// @desc    Get user's friends list
// @route   GET /api/profile/friends
// @access  Private
router.get('/friends', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    const authUser = getAuthUser(req);

    const { data: friendships, error: friendshipError } = await supabase
      .from('friendships')
      .select('id, requester_id, recipient_id, status, created_at')
      .or(`and(requester_id.eq.${authUser.id},status.eq.accepted),and(recipient_id.eq.${authUser.id},status.eq.accepted)`)
      .order('created_at', { ascending: false });

    if (friendshipError) {
      if (tableMissing(friendshipError)) {
        return res.json({ success: true, data: [] });
      }
      throw friendshipError;
    }

    const friendIds = [...new Set((friendships || []).map((row) => (row.requester_id === authUser.id ? row.recipient_id : row.requester_id)))];
    if (friendIds.length === 0) {
      return res.json({ success: true, data: [] });
    }

    const { data: profileRows, error: profileError } = await supabase
      .from('profiles')
      .select('id, name, email, avatar_url, points, bmi, height_cm, weight_kg')
      .in('id', friendIds);

    if (profileError) {
      throw profileError;
    }

    const friendById = new Map((profileRows || []).map((row) => [row.id, mapProfile(row)]));
    const friends = friendIds
      .map((id) => friendById.get(id))
      .filter(Boolean);

    return res.json({ success: true, data: friends });
  } catch (error) {
    console.error('Get friends error:', error);
    return res.status(500).json({ success: false, message: 'Failed to get friends' });
  }
});

// @desc    Get pending friend requests (incoming)
// @route   GET /api/profile/friend-requests
// @access  Private
router.get('/friend-requests', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    const authUser = getAuthUser(req);

    const { data: requests, error: requestError } = await supabase
      .from('friendships')
      .select('id, requester_id, recipient_id, status, created_at')
      .eq('recipient_id', authUser.id)
      .eq('status', 'pending')
      .order('created_at', { ascending: false });

    if (requestError) {
      if (tableMissing(requestError)) {
        return res.json({ success: true, data: [] });
      }
      throw requestError;
    }

    const requesterIds = [...new Set((requests || []).map((row) => row.requester_id))];
    let requesterProfiles = [];

    if (requesterIds.length > 0) {
      const { data: requesterData, error: requesterError } = await supabase
        .from('profiles')
        .select('id, name, email, avatar_url, points, bmi, height_cm, weight_kg')
        .in('id', requesterIds);

      if (requesterError) {
        throw requesterError;
      }
      requesterProfiles = requesterData || [];
    }

    const requesterById = new Map(requesterProfiles.map((row) => [row.id, mapProfile(row)]));

    const payload = (requests || []).map((row) => ({
      _id: row.id,
      id: row.id,
      status: row.status,
      createdAt: row.created_at,
      requester: requesterById.get(row.requester_id) || { _id: row.requester_id, id: row.requester_id, name: 'Unknown', email: '', avatar: '' }
    }));

    return res.json({ success: true, data: payload });
  } catch (error) {
    console.error('Get friend requests error:', error);
    return res.status(500).json({ success: false, message: 'Failed to get friend requests' });
  }
});

// @desc    Discover users to add as friends
// @route   GET /api/profile/discover-users
// @access  Private
router.get('/discover-users', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    const authUser = getAuthUser(req);
    const limit = Math.max(1, Math.min(parseInt(req.query.limit, 10) || 20, 50));

    const { data: users, error: usersError } = await supabase
      .from('profiles')
      .select('id, name, email, avatar_url, points, bmi, height_cm, weight_kg')
      .neq('id', authUser.id)
      .order('updated_at', { ascending: false })
      .limit(limit);

    if (usersError) {
      if (tableMissing(usersError)) {
        return res.json({ success: true, data: [] });
      }
      throw usersError;
    }

    const userIds = (users || []).map((u) => u.id);
    if (userIds.length === 0) {
      return res.json({ success: true, data: [] });
    }

    const { data: relationships, error: relationshipError } = await supabase
      .from('friendships')
      .select('requester_id, recipient_id, status')
      .or(`and(requester_id.eq.${authUser.id},recipient_id.in.(${userIds.join(',')})),and(recipient_id.eq.${authUser.id},requester_id.in.(${userIds.join(',')}))`);

    if (relationshipError && !tableMissing(relationshipError)) {
      throw relationshipError;
    }

    const relationMap = new Map();
    for (const row of relationships || []) {
      const otherId = row.requester_id === authUser.id ? row.recipient_id : row.requester_id;
      relationMap.set(otherId, row.status);
    }

    const payload = (users || []).map((u) => ({
      ...mapProfile(u),
      friendshipStatus: relationMap.get(u.id) || 'none'
    }));

    return res.json({ success: true, data: payload });
  } catch (error) {
    console.error('Discover users error:', error);
    return res.status(500).json({ success: false, message: 'Failed to discover users' });
  }
});

// @desc    Send friend request
// @route   POST /api/profile/friend-request
// @access  Private
router.post('/friend-request', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    const authUser = getAuthUser(req);
    const { recipientId } = req.body || {};

    if (!recipientId) {
      return res.status(400).json({ success: false, message: 'Recipient ID is required' });
    }
    if (recipientId === authUser.id) {
      return res.status(400).json({ success: false, message: 'You cannot send a friend request to yourself' });
    }

    const { data: existing, error: existingError } = await supabase
      .from('friendships')
      .select('id, status')
      .or(`and(requester_id.eq.${authUser.id},recipient_id.eq.${recipientId}),and(requester_id.eq.${recipientId},recipient_id.eq.${authUser.id})`)
      .limit(1);

    if (existingError && !tableMissing(existingError)) {
      throw existingError;
    }

    if ((existing || []).length > 0) {
      return res.status(409).json({ success: false, message: `Friendship already exists with status: ${existing[0].status}` });
    }

    const payload = {
      requester_id: authUser.id,
      recipient_id: recipientId,
      status: 'pending',
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    };

    const { data, error } = await supabase
      .from('friendships')
      .insert(payload)
      .select('id, requester_id, recipient_id, status, created_at')
      .single();

    if (error) {
      throw error;
    }

    return res.status(201).json({
      success: true,
      message: 'Friend request sent',
      data: {
        _id: data.id,
        id: data.id,
        requesterId: data.requester_id,
        recipientId: data.recipient_id,
        status: data.status,
        createdAt: data.created_at
      }
    });
  } catch (error) {
    console.error('Send friend request error:', error);
    return res.status(500).json({ success: false, message: 'Failed to send friend request' });
  }
});

// @desc    Accept friend request
// @route   PUT /api/profile/friend-request/:id/accept
// @access  Private
router.put('/friend-request/:id/accept', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    const authUser = getAuthUser(req);
    const requestId = req.params.id;

    const { data, error } = await supabase
      .from('friendships')
      .update({ status: 'accepted', updated_at: new Date().toISOString() })
      .eq('id', requestId)
      .eq('recipient_id', authUser.id)
      .eq('status', 'pending')
      .select('id, requester_id, recipient_id, status, created_at')
      .maybeSingle();

    if (error) {
      throw error;
    }

    if (!data) {
      return res.status(404).json({ success: false, message: 'Friend request not found' });
    }

    return res.json({
      success: true,
      message: 'Friend request accepted',
      data: {
        _id: data.id,
        id: data.id,
        requesterId: data.requester_id,
        recipientId: data.recipient_id,
        status: data.status,
        createdAt: data.created_at
      }
    });
  } catch (error) {
    console.error('Accept friend request error:', error);
    return res.status(500).json({ success: false, message: 'Failed to accept friend request' });
  }
});

// @desc    Reject friend request
// @route   DELETE /api/profile/friend-request/:id
// @access  Private
router.delete('/friend-request/:id', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    const authUser = getAuthUser(req);
    const requestId = req.params.id;

    const { data, error } = await supabase
      .from('friendships')
      .delete()
      .eq('id', requestId)
      .eq('recipient_id', authUser.id)
      .eq('status', 'pending')
      .select('id')
      .maybeSingle();

    if (error) {
      throw error;
    }

    if (!data) {
      return res.status(404).json({ success: false, message: 'Friend request not found' });
    }

    return res.json({ success: true, message: 'Friend request rejected' });
  } catch (error) {
    console.error('Reject friend request error:', error);
    return res.status(500).json({ success: false, message: 'Failed to reject friend request' });
  }
});

// @desc    Get messages with a friend
// @route   GET /api/profile/messages/:friendId
// @access  Private
router.get('/messages/:friendId', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    const authUser = getAuthUser(req);
    const friendId = req.params.friendId;
    const limit = Math.max(1, Math.min(parseInt(req.query.limit, 10) || 20, 100));

    const { data: rows, error } = await supabase
      .from('messages')
      .select('id, sender_id, recipient_id, text, created_at, is_read, read_at')
      .or(`and(sender_id.eq.${authUser.id},recipient_id.eq.${friendId}),and(sender_id.eq.${friendId},recipient_id.eq.${authUser.id})`)
      .order('created_at', { ascending: false })
      .limit(limit);

    if (error) {
      if (tableMissing(error)) {
        return res.json({ success: true, data: [] });
      }
      throw error;
    }

    const participantIds = [...new Set([authUser.id, friendId, ...(rows || []).map((r) => r.sender_id), ...(rows || []).map((r) => r.recipient_id)])];
    const { data: profiles, error: profileError } = await supabase
      .from('profiles')
      .select('id, name, email, avatar_url, points, bmi, height_cm, weight_kg')
      .in('id', participantIds);

    if (profileError) {
      throw profileError;
    }

    const byId = new Map((profiles || []).map((p) => [p.id, mapProfile(p)]));

    const payload = (rows || [])
      .slice()
      .reverse()
      .map((row) => ({
        _id: row.id,
        id: row.id,
        text: row.text,
        createdAt: row.created_at,
        isRead: !!row.is_read,
        readAt: row.read_at,
        sender: byId.get(row.sender_id) || { _id: row.sender_id, id: row.sender_id, name: 'Unknown', email: '' },
        recipient: byId.get(row.recipient_id) || { _id: row.recipient_id, id: row.recipient_id, name: 'Unknown', email: '' }
      }));

    return res.json({ success: true, data: payload });
  } catch (error) {
    console.error('Get messages error:', error);
    return res.status(500).json({ success: false, message: 'Failed to get messages' });
  }
});

// @desc    Send message
// @route   POST /api/profile/messages
// @access  Private
router.post('/messages', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    const authUser = getAuthUser(req);
    const { recipientId, text } = req.body || {};

    const normalizedText = typeof text === 'string' ? text.trim() : '';
    if (!recipientId || !normalizedText) {
      return res.status(400).json({ success: false, message: 'Recipient ID and message text are required' });
    }

    const { data, error } = await supabase
      .from('messages')
      .insert({
        sender_id: authUser.id,
        recipient_id: recipientId,
        text: normalizedText,
        is_read: false,
        created_at: new Date().toISOString()
      })
      .select('id, sender_id, recipient_id, text, created_at, is_read, read_at')
      .single();

    if (error) {
      throw error;
    }

    return res.status(201).json({
      success: true,
      message: 'Message sent',
      data: {
        _id: data.id,
        id: data.id,
        text: data.text,
        createdAt: data.created_at,
        isRead: !!data.is_read,
        readAt: data.read_at,
        sender: { _id: authUser.id, id: authUser.id, name: authUser.name, email: authUser.email },
        recipient: { _id: recipientId, id: recipientId }
      }
    });
  } catch (error) {
    console.error('Send message error:', error);
    return res.status(500).json({ success: false, message: 'Failed to send message' });
  }
});

// @desc    Mark message as read
// @route   PUT /api/profile/messages/:id/read
// @access  Private
router.put('/messages/:id/read', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    const authUser = getAuthUser(req);

    const { data, error } = await supabase
      .from('messages')
      .update({ is_read: true, read_at: new Date().toISOString() })
      .eq('id', req.params.id)
      .eq('recipient_id', authUser.id)
      .select('id')
      .maybeSingle();

    if (error) {
      throw error;
    }

    if (!data) {
      return res.status(404).json({ success: false, message: 'Message not found' });
    }

    return res.json({ success: true, message: 'Message marked as read' });
  } catch (error) {
    console.error('Mark message read error:', error);
    return res.status(500).json({ success: false, message: 'Failed to mark message as read' });
  }
});

// @desc    Get nutrition logs for current user
// @route   GET /api/profile/nutrition-logs
// @access  Private
router.get('/nutrition-logs', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    const authUser = getAuthUser(req);

    const { data, error } = await supabase
      .from('nutrition_logs')
      .select('id, user_id, name, calories, amount_label, grams, matched_reference, created_at')
      .eq('user_id', authUser.id)
      .order('created_at', { ascending: false });

    if (error) {
      if (tableMissing(error)) return res.json({ success: true, data: [] });
      throw error;
    }

    return res.json({
      success: true,
      data: (data || []).map((row) => ({
        _id: row.id,
        id: row.id,
        name: row.name,
        calories: row.calories,
        amountLabel: row.amount_label,
        grams: row.grams,
        matchedReference: row.matched_reference,
        createdAt: row.created_at
      }))
    });
  } catch (error) {
    console.error('Get nutrition logs error:', error);
    return res.status(500).json({ success: false, message: 'Failed to get nutrition logs' });
  }
});

// @desc    Add nutrition log for current user
// @route   POST /api/profile/nutrition-logs
// @access  Private
router.post('/nutrition-logs', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    const authUser = getAuthUser(req);
    const { name, calories, amountLabel, grams, matchedReference } = req.body || {};

    if (!name || calories == null) {
      return res.status(400).json({ success: false, message: 'name and calories are required' });
    }

    const { data, error } = await supabase
      .from('nutrition_logs')
      .insert({
        user_id: authUser.id,
        name: String(name),
        calories: Number(calories) || 0,
        amount_label: amountLabel || 'Default',
        grams: Number(grams) || 0,
        matched_reference: matchedReference || null,
        created_at: new Date().toISOString()
      })
      .select('id, name, calories, amount_label, grams, matched_reference, created_at')
      .single();

    if (error) throw error;

    return res.status(201).json({
      success: true,
      data: {
        _id: data.id,
        id: data.id,
        name: data.name,
        calories: data.calories,
        amountLabel: data.amount_label,
        grams: data.grams,
        matchedReference: data.matched_reference,
        createdAt: data.created_at
      }
    });
  } catch (error) {
    console.error('Add nutrition log error:', error);
    return res.status(500).json({ success: false, message: 'Failed to add nutrition log' });
  }
});

// @desc    Delete nutrition log for current user
// @route   DELETE /api/profile/nutrition-logs/:id
// @access  Private
router.delete('/nutrition-logs/:id', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    const authUser = getAuthUser(req);

    const { data, error } = await supabase
      .from('nutrition_logs')
      .delete()
      .eq('id', req.params.id)
      .eq('user_id', authUser.id)
      .select('id')
      .maybeSingle();

    if (error) throw error;
    if (!data) return res.status(404).json({ success: false, message: 'Nutrition log not found' });

    return res.json({ success: true, message: 'Nutrition log deleted' });
  } catch (error) {
    console.error('Delete nutrition log error:', error);
    return res.status(500).json({ success: false, message: 'Failed to delete nutrition log' });
  }
});

// @desc    Get cooking inventory for current user
// @route   GET /api/profile/cooking-items
// @access  Private
router.get('/cooking-items', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    const authUser = getAuthUser(req);

    const { data, error } = await supabase
      .from('cooking_items')
      .select('id, user_id, name, amount_label, price, entry_date, expiry_date, used_default_expiry, created_at')
      .eq('user_id', authUser.id)
      .order('created_at', { ascending: false });

    if (error) {
      if (tableMissing(error)) return res.json({ success: true, data: [] });
      throw error;
    }

    return res.json({
      success: true,
      data: (data || []).map((row) => ({
        _id: row.id,
        id: row.id,
        name: row.name,
        amountLabel: row.amount_label,
        price: row.price,
        entryDate: row.entry_date,
        expiryDate: row.expiry_date,
        usedDefaultExpiry: row.used_default_expiry,
        createdAt: row.created_at
      }))
    });
  } catch (error) {
    console.error('Get cooking items error:', error);
    return res.status(500).json({ success: false, message: 'Failed to get cooking items' });
  }
});

// @desc    Add cooking inventory item for current user
// @route   POST /api/profile/cooking-items
// @access  Private
router.post('/cooking-items', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    const authUser = getAuthUser(req);
    const { name, amountLabel, price, entryDate, expiryDate, usedDefaultExpiry } = req.body || {};

    if (!name) {
      return res.status(400).json({ success: false, message: 'name is required' });
    }

    const { data, error } = await supabase
      .from('cooking_items')
      .insert({
        user_id: authUser.id,
        name: String(name),
        amount_label: amountLabel || 'Default',
        price: Number(price) || 0,
        entry_date: entryDate || new Date().toISOString(),
        expiry_date: expiryDate || new Date().toISOString(),
        used_default_expiry: !!usedDefaultExpiry,
        created_at: new Date().toISOString()
      })
      .select('id, name, amount_label, price, entry_date, expiry_date, used_default_expiry, created_at')
      .single();

    if (error) throw error;

    return res.status(201).json({
      success: true,
      data: {
        _id: data.id,
        id: data.id,
        name: data.name,
        amountLabel: data.amount_label,
        price: data.price,
        entryDate: data.entry_date,
        expiryDate: data.expiry_date,
        usedDefaultExpiry: data.used_default_expiry,
        createdAt: data.created_at
      }
    });
  } catch (error) {
    console.error('Add cooking item error:', error);
    return res.status(500).json({ success: false, message: 'Failed to add cooking item' });
  }
});

// @desc    Delete cooking inventory item for current user
// @route   DELETE /api/profile/cooking-items/:id
// @access  Private
router.delete('/cooking-items/:id', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    const authUser = getAuthUser(req);

    const { data, error } = await supabase
      .from('cooking_items')
      .delete()
      .eq('id', req.params.id)
      .eq('user_id', authUser.id)
      .select('id')
      .maybeSingle();

    if (error) throw error;
    if (!data) return res.status(404).json({ success: false, message: 'Cooking item not found' });

    return res.json({ success: true, message: 'Cooking item deleted' });
  } catch (error) {
    console.error('Delete cooking item error:', error);
    return res.status(500).json({ success: false, message: 'Failed to delete cooking item' });
  }
});

// @desc    Get manual cost entries for current user
// @route   GET /api/profile/manual-costs
// @access  Private
router.get('/manual-costs', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    const authUser = getAuthUser(req);

    const { data, error } = await supabase
      .from('manual_cost_entries')
      .select('id, user_id, title, category, amount, cost_date, created_at')
      .eq('user_id', authUser.id)
      .order('cost_date', { ascending: false });

    if (error) {
      if (tableMissing(error)) return res.json({ success: true, data: [] });
      throw error;
    }

    return res.json({
      success: true,
      data: (data || []).map((row) => ({
        _id: row.id,
        id: row.id,
        title: row.title,
        category: row.category,
        amount: row.amount,
        date: row.cost_date,
        createdAt: row.created_at
      }))
    });
  } catch (error) {
    console.error('Get manual cost entries error:', error);
    return res.status(500).json({ success: false, message: 'Failed to get manual cost entries' });
  }
});

// @desc    Add manual cost entry for current user
// @route   POST /api/profile/manual-costs
// @access  Private
router.post('/manual-costs', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    const authUser = getAuthUser(req);
    const { title, category, amount, date } = req.body || {};

    if (!title || amount == null) {
      return res.status(400).json({ success: false, message: 'title and amount are required' });
    }

    const { data, error } = await supabase
      .from('manual_cost_entries')
      .insert({
        user_id: authUser.id,
        title: String(title),
        category: category || 'Food',
        amount: Number(amount) || 0,
        cost_date: date || new Date().toISOString(),
        created_at: new Date().toISOString()
      })
      .select('id, user_id, title, category, amount, cost_date, created_at')
      .single();

    if (error) {
      if (tableMissing(error)) {
        return res.status(503).json({
          success: false,
          message: 'Supabase table manual_cost_entries is missing. Please create it first.'
        });
      }
      throw error;
    }

    return res.status(201).json({
      success: true,
      data: {
        _id: data.id,
        id: data.id,
        title: data.title,
        category: data.category,
        amount: data.amount,
        date: data.cost_date,
        createdAt: data.created_at
      }
    });
  } catch (error) {
    console.error('Add manual cost entry error:', error);
    return res.status(500).json({ success: false, message: 'Failed to add manual cost entry' });
  }
});

// @desc    Delete manual cost entry for current user
// @route   DELETE /api/profile/manual-costs/:id
// @access  Private
router.delete('/manual-costs/:id', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    const authUser = getAuthUser(req);

    const { data, error } = await supabase
      .from('manual_cost_entries')
      .delete()
      .eq('id', req.params.id)
      .eq('user_id', authUser.id)
      .select('id')
      .maybeSingle();

    if (error) throw error;
    if (!data) return res.status(404).json({ success: false, message: 'Manual cost entry not found' });

    return res.json({ success: true, message: 'Manual cost entry deleted' });
  } catch (error) {
    console.error('Delete manual cost entry error:', error);
    return res.status(500).json({ success: false, message: 'Failed to delete manual cost entry' });
  }
});

// @desc    Save health tracking log for current user
// @route   POST /api/profile/health-tracking-logs
// @access  Private
router.post('/health-tracking-logs', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    const authUser = getAuthUser(req);
    const { type, label, score, details } = req.body || {};

    if (!type || !label) {
      return res.status(400).json({ success: false, message: 'type and label are required' });
    }

    const { data, error } = await supabase
      .from('health_tracking_logs')
      .insert({
        user_id: authUser.id,
        type: String(type),
        label: String(label),
        score: score == null ? null : Number(score),
        details: details || {},
        created_at: new Date().toISOString()
      })
      .select('id, user_id, type, label, score, details, created_at')
      .single();

    if (error) {
      if (tableMissing(error)) {
        return res.status(503).json({
          success: false,
          message: 'Supabase table health_tracking_logs is missing. Please create it first.'
        });
      }
      throw error;
    }

    return res.status(201).json({
      success: true,
      data: {
        _id: data.id,
        id: data.id,
        userId: data.user_id,
        type: data.type,
        label: data.label,
        score: data.score,
        details: data.details || {},
        createdAt: data.created_at
      }
    });
  } catch (error) {
    console.error('Add health tracking log error:', error);
    return res.status(500).json({ success: false, message: 'Failed to save health tracking log' });
  }
});

// @desc    Save BMI log for current user
// @route   POST /api/profile/bmi-logs
// @access  Private
router.post('/bmi-logs', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    const authUser = getAuthUser(req);
    const { bmi, heightCm, weightKg, category, suggestion } = req.body || {};

    if (bmi == null || heightCm == null || weightKg == null) {
      return res.status(400).json({ success: false, message: 'bmi, heightCm and weightKg are required' });
    }

    const { data, error } = await supabase
      .from('bmi_logs')
      .insert({
        user_id: authUser.id,
        bmi: Number(bmi),
        height_cm: Number(heightCm),
        weight_kg: Number(weightKg),
        category: category || null,
        suggestion: suggestion || null,
        created_at: new Date().toISOString()
      })
      .select('id, user_id, bmi, height_cm, weight_kg, category, suggestion, created_at')
      .single();

    if (error) {
      if (tableMissing(error)) {
        return res.status(503).json({
          success: false,
          message: 'Supabase table bmi_logs is missing. Please create it first.'
        });
      }
      throw error;
    }

    return res.status(201).json({
      success: true,
      data: {
        _id: data.id,
        id: data.id,
        userId: data.user_id,
        bmi: data.bmi,
        heightCm: data.height_cm,
        weightKg: data.weight_kg,
        category: data.category,
        suggestion: data.suggestion,
        createdAt: data.created_at
      }
    });
  } catch (error) {
    console.error('Add BMI log error:', error);
    return res.status(500).json({ success: false, message: 'Failed to save BMI log' });
  }
});

// @desc    Get health result summary for current user
// @route   GET /api/profile/health-results
// @access  Private
router.get('/health-results', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    const authUser = getAuthUser(req);
    const limit = Math.max(1, Math.min(parseInt(req.query.limit, 10) || 3, 20));

    const { data: trackingRows, error: trackingError } = await supabase
      .from('health_tracking_logs')
      .select('id, user_id, type, label, score, details, created_at')
      .eq('user_id', authUser.id)
      .order('created_at', { ascending: false })
      .limit(200);

    if (trackingError && !tableMissing(trackingError)) {
      throw trackingError;
    }

    const { data: bmiRows, error: bmiError } = await supabase
      .from('bmi_logs')
      .select('id, user_id, bmi, height_cm, weight_kg, category, suggestion, created_at')
      .eq('user_id', authUser.id)
      .order('created_at', { ascending: false })
      .limit(limit);

    if (bmiError && !tableMissing(bmiError)) {
      throw bmiError;
    }

    const grouped = {};
    for (const row of trackingRows || []) {
      const key = row.type || 'unknown';
      if (!grouped[key]) {
        grouped[key] = [];
      }
      if (grouped[key].length < limit) {
        grouped[key].push({
          _id: row.id,
          id: row.id,
          type: row.type,
          label: row.label,
          score: row.score,
          details: row.details || {},
          createdAt: row.created_at
        });
      }
    }

    return res.json({
      success: true,
      data: {
        tracking: grouped,
        bmi: (bmiRows || []).map((row) => ({
          _id: row.id,
          id: row.id,
          bmi: row.bmi,
          heightCm: row.height_cm,
          weightKg: row.weight_kg,
          category: row.category,
          suggestion: row.suggestion,
          createdAt: row.created_at
        }))
      }
    });
  } catch (error) {
    console.error('Get health results error:', error);
    return res.status(500).json({ success: false, message: 'Failed to get health results' });
  }
});

// @desc    Get mood palette + theme preferences for current user
// @route   GET /api/profile/theme-preferences
// @access  Private
router.get('/theme-preferences', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    if (!supabase) {
      return res.status(500).json({ success: false, message: 'Supabase is not configured' });
    }

    const authUser = getAuthUser(req);
    const { data, error } = await supabase
      .from('user_theme_preferences')
      .select('user_id, mood_palette, selected_mood, mood_themes, is_light, primary_hue, accent_hue, orb_hues, updated_at')
      .eq('user_id', authUser.id)
      .maybeSingle();

    if (error) {
      if (tableMissing(error)) {
        return res.status(503).json({
          success: false,
          message: 'Supabase table user_theme_preferences is missing. Please run mood_theme_preferences.sql first.'
        });
      }
      throw error;
    }

    return res.json({
      success: true,
      data: data ? mapThemePreferences(data) : {
        moodPalette: { ...DEFAULT_MOOD_PALETTE },
        selectedMood: 'Neutral',
        moodThemes: normalizeMoodThemes(DEFAULT_MOOD_THEMES),
        theme: { ...DEFAULT_MOOD_THEMES.Neutral }
      }
    });
  } catch (error) {
    console.error('Get theme preferences error:', error);
    return res.status(500).json({ success: false, message: 'Failed to get theme preferences' });
  }
});

// @desc    Upsert mood palette + theme preferences for current user
// @route   PUT /api/profile/theme-preferences
// @access  Private
router.put('/theme-preferences', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    if (!supabase) {
      return res.status(500).json({ success: false, message: 'Supabase is not configured' });
    }

    const authUser = getAuthUser(req);
    const body = req.body || {};

    const { data: existing, error: existingError } = await supabase
      .from('user_theme_preferences')
      .select('user_id, mood_palette, selected_mood, mood_themes, is_light, primary_hue, accent_hue, orb_hues')
      .eq('user_id', authUser.id)
      .maybeSingle();

    if (existingError) {
      if (tableMissing(existingError)) {
        return res.status(503).json({
          success: false,
          message: 'Supabase table user_theme_preferences is missing. Please run mood_theme_preferences.sql first.'
        });
      }
      throw existingError;
    }

    const current = existing ? mapThemePreferences(existing) : {
      moodPalette: { ...DEFAULT_MOOD_PALETTE },
      selectedMood: 'Neutral',
      moodThemes: normalizeMoodThemes(DEFAULT_MOOD_THEMES),
      theme: { ...DEFAULT_MOOD_THEMES.Neutral }
    };

    const nextPalette = body.moodPalette ? normalizePalette(body.moodPalette) : current.moodPalette;
    const nextMood = VALID_MOODS.includes(body.selectedMood) ? body.selectedMood : current.selectedMood;
    const nextTheme = body.theme ? normalizeTheme(body.theme) : current.theme;
    const nextMoodThemes = body.moodThemes
      ? normalizeMoodThemes(body.moodThemes)
      : normalizeMoodThemes(current.moodThemes);
    nextMoodThemes[nextMood] = nextTheme;

    const { data, error } = await supabase
      .from('user_theme_preferences')
      .upsert({
        user_id: authUser.id,
        mood_palette: nextPalette,
        selected_mood: nextMood,
        mood_themes: nextMoodThemes,
        is_light: nextTheme.isLight,
        primary_hue: nextTheme.primaryHue,
        accent_hue: nextTheme.accentHue,
        orb_hues: nextTheme.orbHues,
        updated_at: new Date().toISOString()
      }, { onConflict: 'user_id' })
      .select('user_id, mood_palette, selected_mood, mood_themes, is_light, primary_hue, accent_hue, orb_hues, updated_at')
      .single();

    if (error) throw error;

    return res.json({ success: true, data: mapThemePreferences(data) });
  } catch (error) {
    console.error('Save theme preferences error:', error);
    return res.status(500).json({ success: false, message: 'Failed to save theme preferences' });
  }
});

// @desc    Save doctor report for current user
// @route   POST /api/profile/doctor-reports
// @access  Private
router.post('/doctor-reports', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    const authUser = getAuthUser(req);
    const { doctorId, doctorName, doctorSpecialty, reportTitle, reportText, reportPayload } = req.body || {};

    if (!doctorId || !doctorName || !reportText) {
      return res.status(400).json({ success: false, message: 'doctorId, doctorName and reportText are required' });
    }

    const { data, error } = await supabase
      .from('doctor_reports')
      .insert({
        user_id: authUser.id,
        doctor_id: String(doctorId),
        doctor_name: String(doctorName),
        doctor_specialty: doctorSpecialty || null,
        report_title: reportTitle || 'Health Report',
        report_text: String(reportText),
        report_payload: reportPayload || {},
        created_at: new Date().toISOString()
      })
      .select('id, user_id, doctor_id, doctor_name, doctor_specialty, report_title, report_text, report_payload, created_at')
      .single();

    if (error) {
      if (tableMissing(error)) {
        return res.status(503).json({
          success: false,
          message: 'Supabase table doctor_reports is missing. Please run doctor_reports.sql first.'
        });
      }
      throw error;
    }

    return res.status(201).json({
      success: true,
      data: {
        _id: data.id,
        id: data.id,
        userId: data.user_id,
        doctorId: data.doctor_id,
        doctorName: data.doctor_name,
        doctorSpecialty: data.doctor_specialty,
        reportTitle: data.report_title,
        reportText: data.report_text,
        reportPayload: data.report_payload || {},
        createdAt: data.created_at
      }
    });
  } catch (error) {
    console.error('Save doctor report error:', error);
    return res.status(500).json({ success: false, message: 'Failed to save doctor report' });
  }
});

// @desc    Get doctor reports by doctor id
// @route   GET /api/profile/doctor-reports?doctorId=d1&limit=30
// @access  Private
router.get('/doctor-reports', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    getAuthUser(req);

    const doctorId = String(req.query.doctorId || '').trim();
    const limit = Math.max(1, Math.min(parseInt(req.query.limit, 10) || 30, 200));

    if (!doctorId) {
      return res.status(400).json({ success: false, message: 'doctorId query parameter is required' });
    }

    const { data, error } = await supabase
      .from('doctor_reports')
      .select('id, user_id, doctor_id, doctor_name, doctor_specialty, report_title, report_text, report_payload, created_at')
      .eq('doctor_id', doctorId)
      .order('created_at', { ascending: false })
      .limit(limit);

    if (error) {
      if (tableMissing(error)) {
        return res.json({ success: true, data: [] });
      }
      throw error;
    }

    return res.json({
      success: true,
      data: (data || []).map((row) => ({
        _id: row.id,
        id: row.id,
        userId: row.user_id,
        doctorId: row.doctor_id,
        doctorName: row.doctor_name,
        doctorSpecialty: row.doctor_specialty,
        reportTitle: row.report_title,
        reportText: row.report_text,
        reportPayload: row.report_payload || {},
        createdAt: row.created_at,
      }))
    });
  } catch (error) {
    console.error('Get doctor reports error:', error);
    return res.status(500).json({ success: false, message: 'Failed to get doctor reports' });
  }
});

// @desc    Save doctor booking log
// @route   POST /api/profile/doctor-bookings
// @access  Private
router.post('/doctor-bookings', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    const authUser = getAuthUser(req);
    const { doctorId, doctorName, doctorSpecialty, bookingStatus, notes } = req.body || {};

    if (!doctorId || !doctorName) {
      return res.status(400).json({ success: false, message: 'doctorId and doctorName are required' });
    }

    const status = String(bookingStatus || 'booked').trim().toLowerCase();
    const normalizedStatus = ['booked', 'cancelled', 'completed'].includes(status) ? status : 'booked';

    const { data, error } = await supabase
      .from('doctor_bookings')
      .insert({
        patient_user_id: authUser.id,
        doctor_id: String(doctorId),
        doctor_name: String(doctorName),
        doctor_specialty: doctorSpecialty || null,
        booking_status: normalizedStatus,
        notes: notes || null,
        created_at: new Date().toISOString()
      })
      .select('id, patient_user_id, doctor_id, doctor_name, doctor_specialty, booking_status, notes, created_at')
      .single();

    if (error) {
      if (tableMissing(error)) {
        return res.status(503).json({ success: false, message: 'Supabase table doctor_bookings is missing. Run setup SQL.' });
      }
      throw error;
    }

    return res.status(201).json({
      success: true,
      data: {
        _id: data.id,
        id: data.id,
        patientUserId: data.patient_user_id,
        doctorId: data.doctor_id,
        doctorName: data.doctor_name,
        doctorSpecialty: data.doctor_specialty,
        bookingStatus: data.booking_status,
        notes: data.notes,
        createdAt: data.created_at
      }
    });
  } catch (error) {
    console.error('Save doctor booking error:', error);
    return res.status(500).json({ success: false, message: 'Failed to save doctor booking' });
  }
});

// @desc    Get doctor booking logs
// @route   GET /api/profile/doctor-bookings
// @access  Private
router.get('/doctor-bookings', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    const authUser = getAuthUser(req);
    const doctorId = String(req.query.doctorId || '').trim();
    const limit = Math.max(1, Math.min(parseInt(req.query.limit, 10) || 30, 200));

    let query = supabase
      .from('doctor_bookings')
      .select('id, patient_user_id, doctor_id, doctor_name, doctor_specialty, booking_status, notes, created_at')
      .order('created_at', { ascending: false })
      .limit(limit);

    if (doctorId) {
      query = query.eq('doctor_id', doctorId);
    } else {
      query = query.eq('patient_user_id', authUser.id);
    }

    const { data, error } = await query;

    if (error) {
      if (tableMissing(error)) {
        return res.json({ success: true, data: [] });
      }
      throw error;
    }

    return res.json({
      success: true,
      data: (data || []).map((row) => ({
        _id: row.id,
        id: row.id,
        patientUserId: row.patient_user_id,
        doctorId: row.doctor_id,
        doctorName: row.doctor_name,
        doctorSpecialty: row.doctor_specialty,
        bookingStatus: row.booking_status,
        notes: row.notes,
        createdAt: row.created_at
      }))
    });
  } catch (error) {
    console.error('Get doctor bookings error:', error);
    return res.status(500).json({ success: false, message: 'Failed to get doctor bookings' });
  }
});

// @desc    Start a doctor-patient video call room
// @route   POST /api/profile/video-calls
// @access  Private
router.post('/video-calls', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    const authUser = getAuthUser(req);
    const { doctorId, doctorName, doctorSpecialty, callContext } = req.body || {};

    if (!doctorId || !doctorName) {
      return res.status(400).json({ success: false, message: 'doctorId and doctorName are required' });
    }

    const rawRoom = `nutricare_${doctorId}_${authUser.id}_${Date.now()}`;
    const roomName = rawRoom.replace(/[^a-zA-Z0-9_]/g, '_');
    const joinUrl = `https://meet.jit.si/${roomName}`;

    const { data, error } = await supabase
      .from('video_call_logs')
      .insert({
        patient_user_id: authUser.id,
        doctor_id: String(doctorId),
        doctor_name: String(doctorName),
        doctor_specialty: doctorSpecialty || null,
        room_name: roomName,
        join_url: joinUrl,
        call_status: 'requested',
        initiated_by_user_id: authUser.id,
        call_context: callContext || null,
        started_at: new Date().toISOString()
      })
      .select('id, patient_user_id, doctor_id, doctor_name, doctor_specialty, room_name, join_url, call_status, initiated_by_user_id, call_context, started_at, joined_at, ended_at, created_at')
      .single();

    if (error) {
      if (tableMissing(error)) {
        return res.status(503).json({ success: false, message: 'Supabase table video_call_logs is missing. Run setup SQL.' });
      }
      throw error;
    }

    return res.status(201).json({
      success: true,
      data: {
        _id: data.id,
        id: data.id,
        patientUserId: data.patient_user_id,
        doctorId: data.doctor_id,
        doctorName: data.doctor_name,
        doctorSpecialty: data.doctor_specialty,
        roomName: data.room_name,
        joinUrl: data.join_url,
        callStatus: data.call_status,
        initiatedByUserId: data.initiated_by_user_id,
        callContext: data.call_context,
        startedAt: data.started_at,
        joinedAt: data.joined_at,
        endedAt: data.ended_at,
        createdAt: data.created_at
      }
    });
  } catch (error) {
    console.error('Start video call error:', error);
    return res.status(500).json({ success: false, message: 'Failed to start video call' });
  }
});

// @desc    Get video call logs
// @route   GET /api/profile/video-calls
// @access  Private
router.get('/video-calls', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    const authUser = getAuthUser(req);
    const doctorId = String(req.query.doctorId || '').trim();
    const limit = Math.max(1, Math.min(parseInt(req.query.limit, 10) || 40, 200));

    let query = supabase
      .from('video_call_logs')
      .select('id, patient_user_id, doctor_id, doctor_name, doctor_specialty, room_name, join_url, call_status, initiated_by_user_id, call_context, started_at, joined_at, ended_at, created_at')
      .order('created_at', { ascending: false })
      .limit(limit);

    if (doctorId) {
      query = query.eq('doctor_id', doctorId);
    } else {
      query = query.eq('patient_user_id', authUser.id);
    }

    const { data, error } = await query;

    if (error) {
      if (tableMissing(error)) {
        return res.json({ success: true, data: [] });
      }
      throw error;
    }

    return res.json({
      success: true,
      data: (data || []).map((row) => ({
        _id: row.id,
        id: row.id,
        patientUserId: row.patient_user_id,
        doctorId: row.doctor_id,
        doctorName: row.doctor_name,
        doctorSpecialty: row.doctor_specialty,
        roomName: row.room_name,
        joinUrl: row.join_url,
        callStatus: row.call_status,
        initiatedByUserId: row.initiated_by_user_id,
        callContext: row.call_context,
        startedAt: row.started_at,
        joinedAt: row.joined_at,
        endedAt: row.ended_at,
        createdAt: row.created_at
      }))
    });
  } catch (error) {
    console.error('Get video calls error:', error);
    return res.status(500).json({ success: false, message: 'Failed to get video calls' });
  }
});

// @desc    Mark a video call as joined
// @route   PUT /api/profile/video-calls/:id/join
// @access  Private
router.put('/video-calls/:id/join', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    getAuthUser(req);

    const { data, error } = await supabase
      .from('video_call_logs')
      .update({
        call_status: 'ongoing',
        joined_at: new Date().toISOString()
      })
      .eq('id', req.params.id)
      .select('id, call_status, joined_at')
      .maybeSingle();

    if (error) {
      if (tableMissing(error)) {
        return res.status(503).json({ success: false, message: 'Supabase table video_call_logs is missing. Run setup SQL.' });
      }
      throw error;
    }

    if (!data) {
      return res.status(404).json({ success: false, message: 'Video call not found' });
    }

    return res.json({
      success: true,
      data: {
        id: data.id,
        callStatus: data.call_status,
        joinedAt: data.joined_at
      }
    });
  } catch (error) {
    console.error('Join video call error:', error);
    return res.status(500).json({ success: false, message: 'Failed to update video call status' });
  }
});

module.exports = router;
