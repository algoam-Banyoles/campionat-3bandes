// src/lib/supabaseClient.ts
import { createClient } from '@supabase/supabase-js';
import { wrapRpc } from './errors';

const url = import.meta.env.VITE_SUPABASE_URL;
const anon = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!url) throw new Error('VITE_SUPABASE_URL no definit');
if (!anon) throw new Error('VITE_SUPABASE_ANON_KEY no definit');

export const supabase = wrapRpc(
  createClient(url, anon, {
    auth: {
      persistSession: true,
      autoRefreshToken: true
    }
  })
);
