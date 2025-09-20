export interface SupabaseError {
  message: string;
  code?: string;
  details?: string;
  hint?: string;
}

export function formatSupabaseError(e: unknown): string {
  const message =
    typeof e === 'string'
      ? e
      : typeof e === 'object' && e && 'message' in e
      ? String((e as any).message)
      : '';
  const lower = message.toLowerCase();
  
  // Errors de connexió
  if (
    lower.includes('connection') ||
    lower.includes('timeout') ||
    lower.includes('network') ||
    lower.includes('fetch')
  ) {
    return 'Error de connexió. Comprova la connexió a internet.';
  }
  
  // Errors d'autenticació i autorització
  if (
    lower.includes('policy') ||
    lower.includes('row level security') ||
    lower.includes('row-level security') ||
    lower.includes('permission') ||
    lower.includes('unauthorized') ||
    lower.includes('jwt')
  ) {
    return 'No tens permisos per fer aquesta acció.';
  }
  
  // Errors de validació de dades
  if (
    lower.includes('violates') ||
    lower.includes('invalid') ||
    lower.includes('not-null') ||
    lower.includes('duplicate key') ||
    lower.includes('check constraint') ||
    lower.includes('foreign key')
  ) {
    return 'Dades invàlides.';
  }
  
  // Errors de configuració
  if (
    lower.includes('public_supabase_url') ||
    lower.includes('public_supabase_anon_key') ||
    lower.includes('vite_supabase')
  ) {
    return 'Error de configuració. Contacta amb l\'administrador.';
  }
  
  return message || 'Error desconegut';
}

export const ok = (msg: string) => msg;
export const err = (msg: string) => msg;
