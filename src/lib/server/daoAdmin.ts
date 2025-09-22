import type { SupabaseClient } from '@supabase/supabase-js';
import type { VPlayerBadges } from '$lib/playerBadges';
import { serverSupabase } from './supabaseAdmin';

export type VChallengePending = {
  /** Identificador del repte */
  challenge_id: string;
  /** Identificador de l'esdeveniment associat */
  event_id: string;
  /** Estat actual del repte (proposat, acceptat, programat, ...). */
  estat: string;
  /** Identificador del jugador reptador. */
  reptador_id: string;
  /** Nom del jugador reptador. */
  reptador_nom: string;
  /** Posició al rànquing del reptador (pot ser nul·la si no existeix). */
  reptador_posicio: number | null;
  /** Identificador del jugador reptat. */
  reptat_id: string;
  /** Nom del jugador reptat. */
  reptat_nom: string;
  /** Posició al rànquing del reptat (pot ser nul·la si no existeix). */
  reptat_posicio: number | null;
  /** Data de creació del repte. */
  creat_el: string;
  /** Data límit per acceptar el repte. */
  limit_acceptar_el: string | null;
  /** Data límit per disputar el repte. */
  limit_jugar_el: string | null;
  /** Dies transcorreguts des de la creació del repte. */
  dies_transcorreguts: number;
  /** Dies restants per acceptar el repte, si aplica. */
  dies_restants_acceptar: number | null;
  /** Dies restants per jugar el repte, si aplica. */
  dies_restants_jugar: number | null;
  /** Data programada del repte (pot ser nul·la si no s'ha programat). */
  data_programada: string | null;
  /** Missatge d'avís per l'acceptació, si n'hi ha. */
  warning_acceptar: string | null;
  /** Missatge d'avís per jugar, si n'hi ha. */
  warning_jugar: string | null;
};

export type VPlayerTimeline = {
  /** Identificador del registre al timeline. */
  id: string;
  /** Identificador del jugador al qual pertany el registre. */
  player_id: string;
  /** Data de creació del registre. */
  creat_el: string;
  /** Tipus d'entrada (repte, manteniment, penalització, ...). */
  tipus: string;
  /** Títol o missatge breu de l'entrada. */
  titol: string | null;
  /** Descripció detallada o missatge addicional. */
  descripcio: string | null;
  /** Identificador del repte relacionat, si aplica. */
  challenge_id: string | null;
  /** Identificador de l'execució de manteniment relacionada, si aplica. */
  maintenance_run_id: string | null;
  /** Informació addicional serialitzada en format JSON. */
  metadata: Record<string, unknown> | null;
};

export type VMaintenanceRun = {
  /** Identificador de l'execució de manteniment. */
  id: string;
  /** Data d'inici de l'execució. */
  creat_el: string;
  /** Data de finalització de l'execució. */
  finalitzat_el: string | null;
  /** Usuari o procés que va iniciar el manteniment. */
  triggered_by: string;
  /** Indica si l'execució ha finalitzat correctament. */
  ok: boolean;
  /** Nombre total de passos executats. */
  total_passos: number | null;
  /** Nombre de passos amb errors. */
  errors: number | null;
  /** Missatge resum de l'execució. */
  resum: string | null;
};

export type VMaintenanceRunDetail = {
  /** Identificador del detall. */
  id: string;
  /** Identificador de l'execució de manteniment. */
  run_id: string;
  /** Nom del pas executat. */
  pas: string;
  /** Indica si el pas ha acabat correctament. */
  ok: boolean;
  /** Missatge informatiu o d'error del pas. */
  missatge: string | null;
  /** Data d'execució del pas. */
  creat_el: string;
  /** Informació addicional del pas. */
  metadata: Record<string, unknown> | null;
};

export async function getPlayerBadges(): Promise<VPlayerBadges[]> {
  const supabase = serverSupabase();
  const { data, error } = await supabase
    .from('v_player_badges')
    .select('event_id, player_id, posicio, last_play_date, days_since_last, has_active_challenge, in_cooldown, can_be_challenged, cooldown_days_left');
  if (error) throw new Error(error.message);
  return (data ?? []) as VPlayerBadges[];
}

export type UpdateSettingsInput = {
  diesAcceptar: number;
  diesJugar: number;
  preInact: number;
  inact: number;
};

export async function runMaintenance(
  supabase: SupabaseClient,
  triggeredBy: string
): Promise<VMaintenanceRun> {
  const { data, error } = await supabase.rpc('admin_run_maintenance_and_log', {
    p_triggered_by: triggeredBy
  });
  if (error) throw new Error(error.message);
  const result = Array.isArray(data) ? data[0] : data;
  if (!result) throw new Error('No result');
  return result as VMaintenanceRun;
}

export async function updateSettings(
  supabase: SupabaseClient,
  { diesAcceptar, diesJugar, preInact, inact }: UpdateSettingsInput
): Promise<void> {
  const { error } = await supabase.rpc('admin_update_settings', {
    p_dies_acceptar: diesAcceptar,
    p_dies_jugar: diesJugar,
    p_pre_inact: preInact,
    p_inact: inact
  });
  if (error) throw new Error(error.message);
}

export async function getChallengesPending(
  supabase: SupabaseClient
): Promise<VChallengePending[]> {
  const { data, error } = await supabase
    .from('v_challenges_pending')
    .select('*')
    .order('dies_transcorreguts', { ascending: false });
  if (error) throw new Error(error.message);
  return (data ?? []) as VChallengePending[];
}

export async function getPlayerTimeline(
  supabase: SupabaseClient,
  playerId: string
): Promise<VPlayerTimeline[]> {
  const { data, error } = await supabase
    .from('v_player_timeline')
    .select('*')
    .eq('player_id', playerId)
    .order('creat_el', { ascending: false });
  if (error) throw new Error(error.message);
  return (data ?? []) as VPlayerTimeline[];
}

export async function getMaintenanceRuns(
  supabase: SupabaseClient
): Promise<VMaintenanceRun[]> {
  const { data, error } = await supabase
    .from('v_maintenance_runs')
    .select('*')
    .order('creat_el', { ascending: false });
  if (error) throw new Error(error.message);
  return (data ?? []) as VMaintenanceRun[];
}

export async function getMaintenanceRunDetails(
  supabase: SupabaseClient,
  runId: string
): Promise<VMaintenanceRunDetail[]> {
  const { data, error } = await supabase
    .from('v_maintenance_run_details')
    .select('*')
    .eq('run_id', runId)
    .order('creat_el', { ascending: false });
  if (error) throw new Error(error.message);
  return (data ?? []) as VMaintenanceRunDetail[];
}
