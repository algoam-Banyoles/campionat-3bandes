/**
 * Store derivat amb el `numero_soci` de l'usuari loggat (resolt via socis.email).
 *
 * S'omple automàticament quan canvia `$user.email` i es manté en cache fins que
 * la sessió canviï. Útil per a:
 *   - Construir enllaços al perfil propi (`/jugador/{numero_soci}`)
 *   - Marcar files "is-mine" a classificacions, calendari, etc.
 *   - Filtrar reptes/partides per "només meves" sense haver de fer la query a `socis`
 *     a cada component.
 */

import { writable, derived, get } from 'svelte/store';
import { user } from './auth';
import { supabase } from '$lib/supabaseClient';

export const mySociNumero = writable<number | null>(null);

let lastEmail: string | null = null;

// Subscriu-se als canvis d'usuari per refrescar el store
user.subscribe(async (u) => {
  const email = u?.email ?? null;
  if (email === lastEmail) return;
  lastEmail = email;

  if (!email) {
    mySociNumero.set(null);
    return;
  }

  try {
    const { data, error } = await supabase
      .from('socis')
      .select('numero_soci')
      .eq('email', email)
      .maybeSingle();
    if (error) {
      console.warn('mySociNumero: error fetching soci by email:', error);
      mySociNumero.set(null);
      return;
    }
    mySociNumero.set(data?.numero_soci ?? null);
  } catch (e) {
    console.warn('mySociNumero: unexpected error:', e);
    mySociNumero.set(null);
  }
});

/** Helper síncron per llegir el valor actual sense subscriure's al store. */
export function getMySociNumero(): number | null {
  return get(mySociNumero);
}
