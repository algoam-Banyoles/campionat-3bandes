/**
 * API per a llegir el registre d'auditoria (`audit_log_socials`).
 *
 * Només admins poden accedir-hi (RLS). La pàgina admin/historial
 * permet filtrar per tipus d'entitat, event, actor i període.
 */

import { supabase } from '$lib/supabaseClient';

export interface AuditLogEntry {
  id: string;
  created_at: string;
  actor_user_id: string | null;
  actor_email: string | null;
  action: string;
  entity_type: 'inscripcio' | 'event';
  entity_id: string;
  event_id: string | null;
  before_data: any;
  after_data: any;
  notes: string | null;
}

export interface AuditLogFilters {
  eventId?: string;
  actorEmail?: string;
  entityType?: 'inscripcio' | 'event';
  action?: string;
  /** ISO date string. Inclou registres a partir d'aquesta data. */
  fromDate?: string;
  /** ISO date string. Inclou registres fins a aquesta data. */
  toDate?: string;
  limit?: number;
}

/**
 * Llegeix entrades del registre d'auditoria amb filtres opcionals.
 * Ordenades per data descendent. Limit per defecte: 200.
 */
export async function getAuditLog(filters: AuditLogFilters = {}): Promise<AuditLogEntry[]> {
  let query = supabase
    .from('audit_log_socials')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(filters.limit ?? 200);

  if (filters.eventId) query = query.eq('event_id', filters.eventId);
  if (filters.actorEmail) query = query.eq('actor_email', filters.actorEmail);
  if (filters.entityType) query = query.eq('entity_type', filters.entityType);
  if (filters.action) query = query.eq('action', filters.action);
  if (filters.fromDate) query = query.gte('created_at', filters.fromDate);
  if (filters.toDate) query = query.lte('created_at', filters.toDate);

  const { data, error } = await query;
  if (error) {
    console.error('Error reading audit log:', error);
    throw error;
  }
  return (data as AuditLogEntry[]) || [];
}

/**
 * Llistat únic d'actors (emails) que han generat entrades. Útil per
 * popular un selector al filtre.
 */
export async function getAuditLogActors(): Promise<string[]> {
  const { data, error } = await supabase
    .from('audit_log_socials')
    .select('actor_email')
    .not('actor_email', 'is', null);

  if (error) throw error;
  const set = new Set<string>();
  for (const row of (data || []) as any[]) {
    if (row.actor_email) set.add(row.actor_email);
  }
  return Array.from(set).sort();
}

/**
 * Mapatge user-friendly de codis d'acció a etiquetes en català.
 */
export function actionLabel(action: string): string {
  const map: Record<string, string> = {
    'inscripcio.created': 'Inscripció creada',
    'inscripcio.deleted': 'Inscripció eliminada',
    'inscripcio.updated': 'Inscripció modificada',
    'inscripcio.category_changed': 'Canvi de categoria',
    'inscripcio.withdrawn': 'Jugador retirat',
    'inscripcio.reinstated': 'Jugador reincorporat',
    'inscripcio.disqualified': 'Jugador desqualificat',
    'inscripcio.status_changed': 'Estat de pagament/confirmació',
    'event.estat_changed': 'Canvi d\'estat del campionat',
    'event.calendari_published': 'Calendari publicat',
    'event.activated': 'Campionat activat',
    'event.deactivated': 'Campionat desactivat'
  };
  return map[action] ?? action;
}

/**
 * Codi de severitat per a l'acció (per acolorir la UI).
 */
export function actionSeverity(action: string): 'info' | 'success' | 'warning' | 'danger' {
  if (action.endsWith('.deleted') || action.endsWith('.disqualified') || action.endsWith('.withdrawn'))
    return 'danger';
  if (action.endsWith('.created') || action.endsWith('.published') || action.endsWith('.activated'))
    return 'success';
  if (action.endsWith('.deactivated') || action.endsWith('.reinstated')) return 'warning';
  return 'info';
}
