import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { getSupabaseEnv } from './server/env';

// Client de service-role per a operacions d'admin al servidor.
//
// Inicialització MANDROSA (lazy): la clau de service-role només es llegeix al
// primer ús real, NO a l'import del mòdul. Així el build de SvelteKit (incloent
// els desplegaments de _preview_ de Vercel, on SUPABASE_SERVICE_ROLE_KEY no
// està definida) no peta en analitzar els endpoints que importen aquest client.
let _client: SupabaseClient | null = null;

export function getSupabaseAdmin(): SupabaseClient {
  if (!_client) {
    const { url, key } = getSupabaseEnv(true);
    _client = createClient(url, key, {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    });
  }
  return _client;
}
