const { createClient } = require('@supabase/supabase-js');

let supabaseAdmin = null;

function getSupabaseAdmin() {
  if (supabaseAdmin) return supabaseAdmin;

  const url = process.env.SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !serviceRoleKey) {
    return null;
  }

  supabaseAdmin = createClient(url, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false
    }
  });

  return supabaseAdmin;
}

async function verifySupabaseAccessToken(accessToken) {
  const client = getSupabaseAdmin();
  if (!client) {
    throw new Error('Supabase is not configured. Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
  }

  const { data, error } = await client.auth.getUser(accessToken);
  if (error || !data?.user) {
    throw new Error('Invalid Supabase access token');
  }

  return data.user;
}

module.exports = {
  getSupabaseAdmin,
  verifySupabaseAccessToken
};
