import { createClient } from '@supabase/supabase-js';
import { getSupabaseEnv } from './server/env';

const { url, key } = getSupabaseEnv(true);

// Service role client for server-side admin operations only
export const supabaseAdmin = createClient(
  url,
  key,
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  }
);
