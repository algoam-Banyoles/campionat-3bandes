// Fitxer unificat de tipus per al sistema de campionats del Foment Martinenc
// Estandarditza totes les interfaces i tipus utilitzats al projecte

// ========================================
// TIPUS BASE
// ========================================

export type UUID = string;
export type Modalitat = 'tres_bandes' | 'lliure' | 'banda';
export type TipusCompeticio = 'ranking_continu' | 'lliga_social' | 'handicap' | 'eliminatories' | 'festes_primavera';
export type FormatJoc = 'lliga' | 'eliminatoria_simple' | 'eliminatoria_doble';
export type EstatCompeticio = 'planificacio' | 'inscripcions' | 'pendent_validacio' | 'validat' | 'en_curs' | 'finalitzat';
export type EstatJugador = 'actiu' | 'inactiu' | 'pre_inactiu' | 'baixa';
export type EstatPartida = 'generat' | 'validat' | 'reprogramada' | 'jugada' | 'cancel·lada' | 'cancel·lada_per_retirada' | 'pendent_programar';

// ========================================
// SOCIS I JUGADORS
// ========================================

export interface Soci {
  id: UUID;
  numero_soci: number;
  nom: string;
  cognoms: string | null;
  email: string | null;
  telefon: string | null;
  actiu: boolean;
  created_at: string;
}

export interface Player {
  id: UUID;
  numero_soci: number;
  nom: string;
  cognoms: string | null;
  mitjana: number | null;
  estat: EstatJugador;
  data_ultim_repte: string | null;
  historicalAverage?: number | null;
}

// ========================================
// EVENTS I COMPETICIONS
// ========================================

export interface Event {
  id: UUID;
  nom: string;
  temporada: string;
  modalitat: Modalitat;
  tipus_competicio: TipusCompeticio;
  format_joc: FormatJoc;
  estat_competicio: EstatCompeticio;
  data_inici: string | null;
  data_fi: string | null;
  max_participants: number | null;
  quota_inscripcio: number | null;
  actiu: boolean;
  created_at: string;
}

export interface SocialLeagueEvent extends Event {
  tipus_competicio: 'lliga_social';
  categories: SocialLeagueCategory[];
}

export interface HandicapEvent extends Event {
  tipus_competicio: 'handicap';
  format_joc: 'eliminatoria_doble';
}

export interface FestesPrimaveraEvent extends Event {
  tipus_competicio: 'festes_primavera';
  quota_inscripcio: 0; // Sempre gratuït
}

// ========================================
// CATEGORIES I CLASSIFICACIONS
// ========================================

export interface Category {
  id: UUID;
  event_id: UUID;
  nom: string;
  distancia_caramboles: number;
  max_entrades: number;
  ordre_categoria: number;
  min_jugadors: number;
  max_jugadors: number;
  promig_minim: number | null;
  created_at: string;
}

export interface SocialLeagueCategory extends Category {
  classificacions: Classification[];
}

export interface Classification {
  id: UUID;
  event_id: UUID;
  categoria_id: UUID;
  soci_id: UUID;
  posicio: number;
  partides_jugades: number;
  partides_guanyades: number;
  partides_perdudes: number;
  partides_empat: number;
  punts: number;
  caramboles_favor: number;
  caramboles_contra: number;
  mitjana_particular: number | null;

  // Camps calculats/joins
  player_nom: string;
  player_cognom: string | null;
  player_id?: UUID;
}

// ========================================
// INSCRIPCIONS I LLISTES D'ESPERA
// ========================================

export interface Inscripcio {
  id: UUID;
  event_id: UUID;
  soci_id: UUID;
  categoria_assignada_id: UUID | null;
  data_inscripcio: string;
  preferencies_dies: string[];
  preferencies_hores: string[];
  restriccions_especials: string | null;
  observacions: string | null;
  pagat: boolean;
  confirmat: boolean;
  created_at: string;

  // Withdrawal fields
  estat_jugador: 'actiu' | 'retirat' | null;
  data_retirada: string | null;
  motiu_retirada: string | null;

  // Camps calculats/joins
  soci: Soci;
  categoria_assignada?: Category;
}

export interface LlistaEspera {
  id: UUID;
  event_id: UUID;
  soci_id: UUID;
  posicio_llista: number;
  data_inscripcio_llista: string;
  observacions: string | null;
  created_at: string;

  // Camps calculats/joins
  soci: Soci;
}

// ========================================
// CALENDARI I PARTIDES
// ========================================

export interface ConfiguracioCalendari {
  id: UUID;
  event_id: UUID;
  dies_setmana: string[];
  hores_disponibles: string[];
  taules_per_slot: number;
  max_partides_per_setmana: number;
  max_partides_per_dia: number;
  dies_festius: string[];
  created_at: string;
}

export interface CalendariPartida {
  id: UUID;
  event_id: UUID;
  categoria_id: UUID;
  jugador1_id: UUID;
  jugador2_id: UUID;
  data_programada: string;
  hora_inici: string;
  taula_assignada: number;
  estat: EstatPartida;

  // Validació junta
  validat_per: UUID | null;
  data_validacio: string | null;
  observacions_junta: string | null;

  // Reprogramacions
  data_canvi_solicitada: string | null;
  motiu_canvi: string | null;
  aprovat_canvi_per: UUID | null;
  data_aprovacio_canvi: string | null;

  // Resultat
  resultat_jugador1: number | null;
  resultat_jugador2: number | null;
  guanyador_id: UUID | null;
  match_id: UUID | null;
  observacions: string | null;

  created_at: string;

  // Camps calculats/joins
  jugador1: Soci;
  jugador2: Soci;
  categoria: Category;
  guanyador?: Soci;
}

// ========================================
// RANKING CONTINU
// ========================================

export interface RankingPosition {
  id: UUID;
  event_id: UUID;
  player_id: UUID;
  posicio: number;
  created_at: string;

  // Camps calculats/joins via players
  nom: string | null;
  cognoms: string | null;
  mitjana: number | null;
  estat: EstatJugador;
  data_ultim_repte: string | null;
  numero_soci: number;
}

export interface Challenge {
  id: UUID;
  event_id: UUID;
  reptador_id: UUID;
  reptat_id: UUID;
  tipus: 'normal' | 'acces';
  posicio_reptador: number;
  posicio_reptat: number;
  estat: 'pendent' | 'acceptat' | 'refusat' | 'jugat' | 'expirat';
  data_repte: string;
  data_resposta: string | null;
  data_partida_acordada: string | null;
  data_limit: string;
  observacions: string | null;
  match_id: UUID | null;
  created_at: string;

  // Camps calculats/joins
  reptador: Player;
  reptat: Player;
}

// ========================================
// MATCHES I RESULTATS
// ========================================

export interface Match {
  id: UUID;
  event_id: UUID;
  player1_id: UUID;
  player2_id: UUID;
  player1_score: number;
  player2_score: number;
  player1_innings: number;
  player2_innings: number;
  winner_id: UUID;
  match_date: string;
  observacions: string | null;
  validated: boolean;
  created_at: string;

  // Camps calculats/joins
  player1: Player;
  player2: Player;
  winner: Player;
}

// ========================================
// SISTEMA HÀNDICAP
// ========================================

export interface HandicapBracket {
  id: UUID;
  event_id: UUID;
  tipus: 'winners' | 'losers';
  ronda: number;
  posicio_bracket: number;
  jugador_id: UUID | null;
  estat: 'pendent' | 'actiu' | 'eliminat' | 'classificat';
  created_at: string;

  // Camps calculats/joins
  jugador?: Soci;
}

export interface HandicapMatch extends Match {
  bracket_id: UUID;
  ronda: number;
  distancia_jugador1: number;
  distancia_jugador2: number;

  // Camps calculats/joins
  bracket: HandicapBracket;
}

// ========================================
// ADMINISTRACIÓ I PERMISOS
// ========================================

export interface Admin {
  id: UUID;
  email: string;
  nom: string | null;
  actiu: boolean;
  created_at: string;
}

export interface UserRole {
  id: UUID;
  email: string;
  role: 'admin' | 'user';
  active: boolean;
  created_at: string;
}

// ========================================
// HISTÒRIA I ESTADÍSTIQUES
// ========================================

export interface MitjanaHistorica {
  id: UUID;
  player_id: UUID;
  temporada: string;
  modalitat: Modalitat;
  mitjana: number;
  partides_jugades: number;
  created_at: string;
}

export interface HistoryPositionChange {
  id: UUID;
  event_id: UUID;
  player_id: UUID;
  posicio_anterior: number;
  posicio_nova: number;
  motiu: string;
  data_canvi: string;
  created_at: string;
}

// ========================================
// API RESPONSES
// ========================================

export interface ApiResponse<T> {
  data: T | null;
  error: string | null;
  status: number;
}

export interface PaginatedResponse<T> {
  data: T[];
  total: number;
  page: number;
  limit: number;
  hasNextPage: boolean;
  hasPrevPage: boolean;
}

// ========================================
// FORMULARIS I UI
// ========================================

export interface SearchResult {
  player: Player;
  classifications: Array<{
    modalitat: Modalitat;
    temporada: string;
    categoria: string;
    posicio: number;
    punts: number;
    partides_jugades: number;
  }>;
}

export interface CalendarEvent {
  id: string;
  title: string;
  start: string;
  end?: string;
  allDay?: boolean;
  backgroundColor?: string;
  borderColor?: string;
  textColor?: string;
  extendedProps?: {
    type: 'partida' | 'event';
    partida?: CalendariPartida;
    jugadors?: string[];
    categoria?: string;
    taula?: number;
  };
}

// ========================================
// NOTIFICACIONS
// ========================================

export interface Notification {
  id: UUID;
  user_id: UUID;
  title: string;
  message: string;
  type: 'info' | 'success' | 'warning' | 'error';
  read: boolean;
  action_url: string | null;
  created_at: string;
}

// ========================================
// CONFIGURACIÓ
// ========================================

export interface AppConfig {
  site_name: string;
  max_challenge_days: number;
  max_inactive_weeks: number;
  pre_inactive_weeks: number;
  default_calendar_hours: string[];
  default_calendar_days: string[];
  ranking_size: number;
}

// ========================================
// TIPUS D'EXPORTACIÓ
// ========================================

// Database types will be auto-generated by Supabase CLI when needed
// export type { Database } from '$lib/database.types';