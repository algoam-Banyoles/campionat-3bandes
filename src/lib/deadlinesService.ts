import type { SupabaseClient } from '@supabase/supabase-js';

export type MaintenanceLogEntry = {
  kind?: string | null;
  payload?: Record<string, unknown> | null;
  challenges_processed?: number | null;
  challengesProcessed?: number | null;
  inactivity_processed?: number | null;
  inactivityProcessed?: number | null;
  [key: string]: unknown;
};

export type RunDeadlinesResult = {
  challengesProcessed: number;
  inactivityProcessed: number;
  raw: MaintenanceLogEntry[];
};

const DEFAULT_TRIGGERED_BY = 'admin:webapp';
const CHALLENGE_KEYS = ['challenges_processed', 'challengesProcessed'];
const INACTIVITY_KEYS = ['inactivity_processed', 'inactivityProcessed'];

function ensureArray<T>(value: T | T[] | null | undefined): T[] {
  if (Array.isArray(value)) return value;
  if (value == null) return [];
  return [value];
}

function parseNumericValue(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === 'string') {
    const parsed = Number.parseInt(value, 10);
    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }
  return null;
}

function extractCount(entry: MaintenanceLogEntry, keys: string[]): number {
  const payload =
    entry.payload && typeof entry.payload === 'object'
      ? (entry.payload as Record<string, unknown>)
      : null;
  for (const key of keys) {
    const direct = parseNumericValue(entry[key]);
    if (direct != null) {
      return direct;
    }
    if (payload) {
      const nested = parseNumericValue(payload[key]);
      if (nested != null) {
        return nested;
      }
    }
  }
  return 0;
}



export async function runDeadlines(
  supabase: SupabaseClient,
  actorEmail?: string | null
): Promise<RunDeadlinesResult> {
  const triggeredBy = actorEmail ? `admin:${actorEmail}` : DEFAULT_TRIGGERED_BY;
  const { data, error } = await supabase.rpc('admin_run_maintenance_and_log', {
    p_triggered_by: triggeredBy
  });
  if (error) throw new Error(error.message);
  const raw = ensureArray<MaintenanceLogEntry>(data);
  const challengesProcessed = raw.reduce(
    (acc, entry) => acc + extractCount(entry, CHALLENGE_KEYS),
    0
  );
  const inactivityProcessed = raw.reduce(
    (acc, entry) => acc + extractCount(entry, INACTIVITY_KEYS),
    0
  );
  return {
    challengesProcessed,
    inactivityProcessed,
    raw
  };
}
