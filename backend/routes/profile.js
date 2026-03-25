const express = require('express');
const { protect } = require('../middleware/auth');
const { getSupabaseAdmin } = require('../services/supabase_auth');

const router = express.Router();

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

function mapProfile(row) {
  return {
    _id: row.id,
    id: row.id,
    name: row.name || 'User',
    email: row.email || '',
    avatar: row.avatar_url || '',
    points: row.points || 0,
    bmi: row.bmi ?? null,
    heightCm: row.height_cm ?? null,
    weightKg: row.weight_kg ?? null
  };
}

async function ensureOwnProfile(supabase, authUser) {
  const upsertPayload = {
    id: authUser.id,
    email: authUser.email,
    name: authUser.name,
    avatar_url: authUser.avatar,
    updated_at: new Date().toISOString()
  };

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
      .select('id, name, email, avatar_url, points, bmi, height_cm, weight_kg')
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
    const { name, avatar, points, bmi, heightCm, weightKg } = req.body || {};

    const upsertPayload = {
      id: authUser.id,
      email: authUser.email,
      name: name || authUser.name,
      avatar_url: avatar || authUser.avatar,
      points: Number.isFinite(points) ? Number(points) : 0,
      bmi: bmi ?? null,
      height_cm: heightCm ?? null,
      weight_kg: weightKg ?? null,
      updated_at: new Date().toISOString()
    };

    const { data, error } = await supabase
      .from('profiles')
      .upsert(upsertPayload, { onConflict: 'id' })
      .select('id, name, email, avatar_url, points, bmi, height_cm, weight_kg')
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

module.exports = router;
