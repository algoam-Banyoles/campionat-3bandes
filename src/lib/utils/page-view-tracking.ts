import { afterNavigate } from '$app/navigation';
import { browser, dev } from '$app/environment';

/**
 * Registre anònim de visites de pàgina per a estadístiques d'ús (admin).
 *
 * - Només desa la secció/path i flags agregats (no cap identitat d'usuari).
 * - Genera un `visitor_id` aleatori per navegador (localStorage) per estimar
 *   visitants únics sense identificar ningú.
 * - És "fire and forget": mai bloqueja la navegació ni propaga errors.
 * - No registra res en desenvolupament (per no contaminar les dades de prod).
 */

const VISITOR_KEY = 'c3b_visitor_id';

function getVisitorId(): string | null {
  if (!browser) return null;
  try {
    let id = localStorage.getItem(VISITOR_KEY);
    if (!id) {
      id =
        typeof crypto !== 'undefined' && 'randomUUID' in crypto
          ? crypto.randomUUID()
          : `${Date.now()}-${Math.random().toString(36).slice(2)}`;
      localStorage.setItem(VISITOR_KEY, id);
    }
    return id;
  } catch {
    // localStorage pot no estar disponible (mode privat, etc.)
    return null;
  }
}

let lastPath: string | null = null;

// Si el registre falla repetidament (p. ex. la migració encara no s'ha aplicat
// a producció), deshabilitem el tracking per a la resta de la sessió i així no
// generem peticions fallides a cada navegació.
let failures = 0;
let disabled = false;
const MAX_FAILURES = 3;

async function track(path: string): Promise<void> {
  if (disabled) return;
  try {
    const { supabase } = await import('$lib/supabaseClient');
    const { error } = await supabase.rpc('log_page_view', {
      p_path: path,
      p_visitor_id: getVisitorId()
    });
    if (error) {
      if (++failures >= MAX_FAILURES) disabled = true;
    } else {
      failures = 0;
    }
  } catch {
    // Analytics no ha de trencar mai l'app: empassem qualsevol error.
    if (++failures >= MAX_FAILURES) disabled = true;
  }
}

export function setupPageViewTracking(): void {
  if (!browser) return;

  afterNavigate(({ to }) => {
    const path = to?.url?.pathname;
    if (!path) return;
    if (path === lastPath) return; // evita duplicats en re-render
    lastPath = path;
    if (dev) return; // no registrar en desenvolupament
    void track(path);
  });
}
