import type { SupabaseClient } from '@supabase/supabase-js';

export type MaintenanceLogEntry = {
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

const DEFAULT_ACTOR = 'admin:webapp';
const CHALLENGE_KEYS = ['challenges_processed', 'challengesProcessed'];
const INACTIVITY_KEYS = ['inactivity_processed', 'inactivityProcessed'];

function ensureArray<T>(value: T | T[] | null | undefined): T[] {
  if (Array.isArray(value)) return value;
  if (value == null) return [];
  return [value];
}

function extractCount(entry: MaintenanceLogEntry, keys: string[]): number {
  for (const key of keys) {
    const value = entry[key];
    if (typeof value === 'number' && Number.isFinite(value)) {
      return value;
    }
    if (typeof value === 'string') {
      const parsed = Number.parseInt(value, 10);
      if (Number.isFinite(parsed)) {
        return parsed;
      }
    }
  }
  return 0;
}

export async function runOverdueSweep(
  supabase: SupabaseClient
): Promise<MaintenanceLogEntry[]> {
  const { data, error } = await supabase.rpc(
    'sweep_overdue_challenges_from_settings_mvp2'
  );
  if (error) throw new Error(error.message);
  return ensureArray<MaintenanceLogEntry>(data);
}

export async function runDeadlines(
  supabase: SupabaseClient,
  actorEmail?: string | null
): Promise<RunDeadlinesResult> {
  const actor = actorEmail ? `admin:${actorEmail}` : DEFAULT_ACTOR;
  const { data, error } = await supabase.rpc('admin_run_maintenance_and_log', {
    p_actor: actor
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
