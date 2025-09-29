import { createClient } from '@supabase/supabase-js';

const url = import.meta.env.PUBLIC_SUPABASE_URL;
const serviceRoleKey = import.meta.env.PUBLIC_SUPABASE_SERVICE_ROLE_KEY;

if (!url) throw new Error('PUBLIC_SUPABASE_URL no definit');
if (!serviceRoleKey) throw new Error('PUBLIC_SUPABASE_SERVICE_ROLE_KEY no definit');

// Service role client for admin operations
export const supabase = createClient(
  url,
  serviceRoleKey,
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  }
);