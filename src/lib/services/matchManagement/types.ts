/**
 * Tipus compartits de la capa d'adaptadors de gestió unificada de partides.
 *
 * Cada competició (social, continu, hàndicap) té el seu propi write path;
 * aquesta capa normalitza la LECTURA a un view-model comú (`UnifiedMatch`) i
 * despatxa les escriptures als adaptadors específics.
 */

import type { SupabaseClient } from '@supabase/supabase-js';

// ── Identificació d'origen ─────────────────────────────────────────────────

export type MatchSource = 'social' | 'continu' | 'handicap';

// ── Estat normalitzat ──────────────────────────────────────────────────────

/** Estat normalitzat per a filtres i ordenació al modal unificat. */
export type UnifiedStatus = 'pendent' | 'programada' | 'jugada' | 'altres';

// ── Jugador en una partida ─────────────────────────────────────────────────

export interface UnifiedPlayer {
  /** Nom formatat: "J. Cognom" via formatarNomJugador / formatarNomJugadorParts */
  displayName: string;
  /** Nom complet sense abreujar, per a cerca de text */
  rawName: string;
  /** numero_soci del soci (null si el jugador no és determinat, ex: hàndicap R2+) */
  sociNumero: number | null;
}

// ── Slot (data + hora + billar) ────────────────────────────────────────────

export interface UnifiedSlot {
  /** Data en format ISO 'YYYY-MM-DD' */
  dataIso: string;
  /** Hora en format 'HH:MM' */
  hora: string;
  /** Número de billar (1-3); null per al continu (sense billar) */
  billar: number | null;
}

// ── Capabilities ───────────────────────────────────────────────────────────

export interface UnifiedCapabilities {
  canEnterResult: boolean;
  canSchedule: boolean;
  canUnschedule: boolean;
}

// ── Meta discriminada per origen ───────────────────────────────────────────

export interface SocialMeta {
  source: 'social';
  eventId: string;
  eventNom: string;
  categoriaId: string;
  categoriaNom: string;
  distanciaCaramboles: number | null;
}

export interface ContinuMeta {
  source: 'continu';
  eventId: string;
  /** Número de vegades que s'ha reprogramat el repte */
  reprogramCount: number;
  /** Posició del reptador al rànquing */
  posReptador: number | null;
  /** Posició del reptat al rànquing */
  posReptat: number | null;
  /** Límits de validació (d'app_settings; el servidor revalida) */
  carambolesObjectiu: number;
  maxEntrades: number;
  allowTiebreak: boolean;
}

export interface HandicapMeta {
  source: 'handicap';
  eventId: string;
  eventNom: string;
  bracketType: 'winners' | 'losers' | 'grand_final';
  ronda: number;
  matchPos: number;
  matchCode: string;
  /** FK a calendari_partides (null si no programada) */
  calendariPartidaId: string | null;
  player1ParticipantId: string | null;
  player2ParticipantId: string | null;
  player1Distancia: number | null;
  player2Distancia: number | null;
  sistemaPuntuacio: string;
  limitEntrades: number | null;
  /** Preferències de disponibilitat del jugador 1 (null = no determinat) */
  player1Preferencies: { dies: string[]; hores: string[] } | null;
  /** Preferències de disponibilitat del jugador 2 (null = no determinat) */
  player2Preferencies: { dies: string[]; hores: string[] } | null;
}

export type UnifiedMeta = SocialMeta | ContinuMeta | HandicapMeta;

// ── View-model unificat ────────────────────────────────────────────────────

export interface UnifiedMatch {
  /** Font de la partida */
  source: MatchSource;
  /**
   * ID de la partida dins la seva font:
   * - social: calendari_partides.id
   * - continu: challenges.id
   * - handicap: handicap_matches.id
   */
  id: string;
  player1: UnifiedPlayer;
  player2: UnifiedPlayer;
  /** Null si la partida no té slot assignat */
  slot: UnifiedSlot | null;
  status: UnifiedStatus;
  /** Valor original de l'estat a la BD */
  rawEstat: string;
  capabilities: UnifiedCapabilities;
  meta: UnifiedMeta;
}

// ── ResultInput discriminat ────────────────────────────────────────────────

export interface SocialResultInput {
  kind: 'social';
  caramboles_jugador1: number;
  caramboles_jugador2: number;
  entrades: number;
  observacions: string;
}

export interface SocialNoShowInput {
  kind: 'social-noshow';
  absentPlayer: 1 | 2;
}

export interface ContinuResultInput {
  kind: 'continu';
  data_iso: string;
  tipusResultat: 'normal' | 'walkover_reptador' | 'walkover_reptat';
  carR: number;
  carT: number;
  entrades: number;
  serieR: number;
  serieT: number;
  tbR: number | null;
  tbT: number | null;
}

export interface HandicapResultInput {
  kind: 'handicap';
  isWalkover: boolean;
  caramboles1: number | null;
  caramboles2: number | null;
  entrades: number | null;
  winnerParticipantId: string;
  loserParticipantId: string | null;
}

export type ResultInput =
  | SocialResultInput
  | SocialNoShowInput
  | ContinuResultInput
  | HandicapResultInput;

// ── Resposta d'enterResult ─────────────────────────────────────────────────

export interface EnterResultResponse {
  /** Missatge descriptiu en català per mostrar a l'usuari */
  message: string;
}

// ── Interfície de l'adaptador ──────────────────────────────────────────────

export interface MatchAdapter {
  /**
   * Retorna la llista de partides normalitzades.
   * @param includeJugades Si true, inclou les partides ja jugades.
   */
  listMatches(supabase: SupabaseClient, includeJugades?: boolean): Promise<UnifiedMatch[]>;

  /**
   * Registra el resultat d'una partida. Llança Error o retorna la
   * descripció del resultat per mostrar a l'usuari.
   */
  enterResult(
    supabase: SupabaseClient,
    match: UnifiedMatch,
    input: ResultInput
  ): Promise<EnterResultResponse>;

  /**
   * Programa (o reprograma) una partida.
   * - Per al continu: sense billar (UnifiedSlot.billar = null).
   * - Llança Error amb missatge en català si hi ha conflicte o error.
   */
  schedule?(
    supabase: SupabaseClient,
    match: UnifiedMatch,
    slot: UnifiedSlot
  ): Promise<void>;

  /**
   * Elimina la programació d'una partida (si és possible).
   * Llança Error amb missatge en català si falla.
   */
  unschedule?(supabase: SupabaseClient, match: UnifiedMatch): Promise<void>;
}

// ── Error de l'adaptador ───────────────────────────────────────────────────

export interface AdapterError {
  source: MatchSource;
  message: string;
}
