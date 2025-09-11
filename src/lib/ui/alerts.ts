export function formatSupabaseError(e: unknown): string {
  const message =
    typeof e === 'string'
      ? e
      : typeof e === 'object' && e && 'message' in e
      ? String((e as any).message)
      : '';
  const lower = message.toLowerCase();
  if (
    lower.includes('policy') ||
    lower.includes('row level security') ||
    lower.includes('row-level security') ||
    lower.includes('permission')
  ) {
    return 'No tens permisos per fer aquesta acció.';
  }
  if (
    lower.includes('violates') ||
    lower.includes('invalid') ||
    lower.includes('not-null') ||
    lower.includes('duplicate key') ||
    lower.includes('check constraint')
  ) {
    return 'Dades invàlides.';
  }
  return message || 'Error desconegut';
}

export const ok = (msg: string) => msg;
export const err = (msg: string) => msg;
