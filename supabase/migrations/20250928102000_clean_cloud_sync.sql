-- Migration: Clean sync from Supabase cloud schema
-- Generated at: 2025-09-28T10:20:00.000Z
-- This migration replaces the entire local schema with the current cloud schema

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Drop existing tables (in reverse dependency order)
DROP TABLE IF EXISTS notification_history CASCADE;
DROP TABLE IF EXISTS scheduled_notifications CASCADE;
DROP TABLE IF EXISTS push_subscriptions CASCADE;
DROP TABLE IF EXISTS history_position_changes CASCADE;
DROP TABLE IF EXISTS penalties CASCADE;
DROP TABLE IF EXISTS mitjanes_historiques CASCADE;
DROP TABLE IF EXISTS maintenance_run_items CASCADE;
DROP TABLE IF EXISTS maintenance_runs CASCADE;
DROP TABLE IF EXISTS configuracio_calendari CASCADE;
DROP TABLE IF EXISTS calendari_partides CASCADE;
DROP TABLE IF EXISTS esdeveniments_club CASCADE;
DROP TABLE IF EXISTS initial_ranking CASCADE;
DROP TABLE IF EXISTS matches CASCADE;
DROP TABLE IF EXISTS inscripcions CASCADE;
DROP TABLE IF EXISTS player_weekly_positions CASCADE;
DROP TABLE IF EXISTS waiting_list CASCADE;
DROP TABLE IF EXISTS notes CASCADE;
DROP TABLE IF EXISTS classificacions CASCADE;
DROP TABLE IF EXISTS challenges CASCADE;
DROP TABLE IF EXISTS ranking_positions CASCADE;
DROP TABLE IF EXISTS players CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS events CASCADE;
DROP TABLE IF EXISTS socis CASCADE;
DROP TABLE IF EXISTS admins CASCADE;
DROP TABLE IF EXISTS app_settings CASCADE;
DROP TABLE IF EXISTS notification_preferences CASCADE;

-- Drop custom types
DROP TYPE IF EXISTS penalty_type CASCADE;
DROP TYPE IF EXISTS match_result CASCADE;
DROP TYPE IF EXISTS player_state CASCADE;
DROP TYPE IF EXISTS challenge_type CASCADE;
DROP TYPE IF EXISTS challenge_state CASCADE;

-- Create custom types
CREATE TYPE penalty_type AS ENUM ('incompareixenca', 'desacord_dates', 'pre_inactivitat', 'inactivitat', 'baixa_voluntaria');
CREATE TYPE match_result AS ENUM ('guanya_reptador', 'guanya_reptat', 'empat_tiebreak_reptador', 'empat_tiebreak_reptat', 'walkover_reptador', 'walkover_reptat');
CREATE TYPE player_state AS ENUM ('actiu', 'pre_inactiu', 'inactiu', 'baixa');
CREATE TYPE challenge_type AS ENUM ('normal', 'access');
CREATE TYPE challenge_state AS ENUM ('proposat', 'acceptat', 'refusat', 'caducat', 'jugat', 'anullat', 'programat');

-- Create tables in dependency order

-- Base tables (no foreign keys)
CREATE TABLE admins (
  email text PRIMARY KEY
);

CREATE TABLE app_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  caramboles_objectiu smallint NOT NULL DEFAULT 2,
  max_entrades smallint NOT NULL DEFAULT 50,
  allow_tiebreak boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now(),
  cooldown_min_dies smallint NOT NULL DEFAULT 3,
  cooldown_max_dies smallint NOT NULL DEFAULT 7,
  dies_acceptar_repte smallint NOT NULL DEFAULT 7,
  dies_jugar_despres_acceptar smallint NOT NULL DEFAULT 7,
  ranking_max_jugadors smallint NOT NULL DEFAULT 20,
  max_rank_gap smallint NOT NULL DEFAULT 2,
  pre_inactiu_setmanes smallint NOT NULL DEFAULT 3,
  inactiu_setmanes smallint NOT NULL DEFAULT 6
);

CREATE TABLE socis (
  numero_soci integer PRIMARY KEY,
  cognoms text NOT NULL,
  nom text NOT NULL,
  email text,
  de_baixa boolean DEFAULT false,
  data_baixa date
);

CREATE TABLE events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nom text NOT NULL,
  temporada text NOT NULL,
  creat_el timestamptz DEFAULT now(),
  actiu boolean DEFAULT true,
  modalitat text,
  tipus_competicio text,
  format_joc text,
  data_inici date,
  data_fi date,
  estat_competicio text DEFAULT 'planificacio',
  max_participants integer,
  quota_inscripcio numeric
);

CREATE TABLE players (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nom text NOT NULL,
  email text,
  mitjana numeric,
  estat player_state DEFAULT 'actiu',
  club text,
  avatar_url text,
  data_ultim_repte date,
  creat_el timestamptz DEFAULT now(),
  numero_soci integer REFERENCES socis(numero_soci)
);

CREATE TABLE categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES events(id),
  nom text NOT NULL,
  distancia_caramboles integer NOT NULL,
  max_entrades integer DEFAULT 50,
  ordre_categoria smallint NOT NULL,
  min_jugadors integer DEFAULT 8,
  max_jugadors integer DEFAULT 12,
  created_at timestamptz DEFAULT now(),
  promig_minim numeric
);

CREATE TABLE challenges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES events(id),
  tipus challenge_type DEFAULT 'normal',
  reptador_id uuid NOT NULL REFERENCES players(id),
  reptat_id uuid NOT NULL REFERENCES players(id),
  estat challenge_state DEFAULT 'proposat',
  dates_proposades timestamptz[],
  data_proposta timestamptz DEFAULT now(),
  data_acceptacio timestamptz,
  observacions text,
  pos_reptador smallint,
  pos_reptat smallint,
  reprogram_count smallint DEFAULT 0,
  data_programada timestamptz,
  reprogramacions integer DEFAULT 0
);

CREATE TABLE matches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id uuid NOT NULL REFERENCES challenges(id),
  data_joc timestamptz DEFAULT now(),
  caramboles_reptador smallint,
  caramboles_reptat smallint,
  entrades smallint,
  serie_max_reptador smallint DEFAULT 0,
  serie_max_reptat smallint DEFAULT 0,
  resultat match_result NOT NULL,
  signat_reptador boolean DEFAULT false,
  signat_reptat boolean DEFAULT false,
  creat_el timestamptz DEFAULT now(),
  tiebreak boolean DEFAULT false,
  tiebreak_reptador smallint,
  tiebreak_reptat smallint,
  jornada integer,
  categoria_id uuid REFERENCES categories(id),
  tipus_partida text DEFAULT 'challenge'
);

CREATE TABLE ranking_positions (
  event_id uuid REFERENCES events(id),
  posicio smallint,
  player_id uuid REFERENCES players(id),
  assignat_el timestamptz DEFAULT now(),
  PRIMARY KEY (event_id, posicio)
);

CREATE TABLE initial_ranking (
  event_id uuid REFERENCES events(id),
  posicio smallint,
  player_id uuid REFERENCES players(id),
  PRIMARY KEY (event_id, posicio)
);

CREATE TABLE classificacions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES events(id),
  categoria_id uuid NOT NULL REFERENCES categories(id),
  player_id uuid NOT NULL REFERENCES players(id),
  posicio integer NOT NULL,
  partides_jugades integer DEFAULT 0,
  partides_guanyades integer DEFAULT 0,
  partides_perdudes integer DEFAULT 0,
  partides_empat integer DEFAULT 0,
  punts integer DEFAULT 0,
  caramboles_favor integer DEFAULT 0,
  caramboles_contra integer DEFAULT 0,
  mitjana_particular numeric,
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE inscripcions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES events(id),
  soci_numero integer NOT NULL REFERENCES socis(numero_soci),
  categoria_assignada_id uuid REFERENCES categories(id),
  data_inscripcio timestamptz DEFAULT now(),
  preferencies_dies text[],
  preferencies_hores text[],
  restriccions_especials text,
  observacions text,
  pagat boolean DEFAULT false,
  confirmat boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE waiting_list (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL REFERENCES players(id),
  ordre integer NOT NULL,
  data_inscripcio timestamptz DEFAULT now(),
  event_id uuid NOT NULL REFERENCES events(id)
);

CREATE TABLE notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid,
  content text NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE player_weekly_positions (
  event_id uuid REFERENCES events(id),
  player_id uuid REFERENCES players(id),
  setmana integer,
  posicio integer NOT NULL,
  PRIMARY KEY (event_id, player_id, setmana)
);

CREATE TABLE penalties (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES events(id),
  player_id uuid NOT NULL REFERENCES players(id),
  tipus penalty_type NOT NULL,
  detalls text,
  creat_el timestamptz DEFAULT now(),
  challenge_id uuid REFERENCES challenges(id)
);

CREATE TABLE history_position_changes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES events(id),
  player_id uuid NOT NULL REFERENCES players(id),
  posicio_anterior smallint NOT NULL,
  posicio_nova smallint NOT NULL,
  motiu text NOT NULL,
  ref_challenge uuid REFERENCES challenges(id),
  creat_el timestamptz DEFAULT now()
);

CREATE TABLE mitjanes_historiques (
  id serial PRIMARY KEY,
  soci_id integer NOT NULL REFERENCES socis(numero_soci),
  year integer NOT NULL,
  modalitat varchar(20) NOT NULL,
  mitjana numeric NOT NULL,
  created_at timestamp DEFAULT now()
);

CREATE TABLE maintenance_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  started_at timestamptz DEFAULT now(),
  finished_at timestamptz,
  triggered_by text DEFAULT 'auto',
  ok boolean,
  notes text
);

CREATE TABLE maintenance_run_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  run_id uuid NOT NULL REFERENCES maintenance_runs(id),
  kind text NOT NULL,
  payload jsonb NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE configuracio_calendari (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES events(id),
  dies_setmana text[],
  hores_disponibles text[],
  taules_per_slot integer DEFAULT 3,
  max_partides_per_setmana integer DEFAULT 3,
  max_partides_per_dia integer DEFAULT 1,
  dies_festius date[],
  created_at timestamptz DEFAULT now()
);

CREATE TABLE calendari_partides (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES events(id),
  categoria_id uuid NOT NULL REFERENCES categories(id),
  jugador1_id uuid NOT NULL REFERENCES players(id),
  jugador2_id uuid NOT NULL REFERENCES players(id),
  data_programada timestamptz,
  hora_inici time,
  taula_assignada integer,
  estat text DEFAULT 'generat',
  validat_per uuid,
  data_validacio timestamptz,
  observacions_junta text,
  data_canvi_solicitada timestamptz,
  motiu_canvi text,
  aprovat_canvi_per uuid,
  data_aprovacio_canvi timestamptz,
  match_id uuid REFERENCES matches(id),
  created_at timestamptz DEFAULT now()
);

CREATE TABLE esdeveniments_club (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  titol text NOT NULL,
  descripcio text,
  data_inici timestamptz NOT NULL,
  data_fi timestamptz,
  tipus text DEFAULT 'general',
  visible_per_tots boolean DEFAULT true,
  creat_per uuid,
  event_id uuid REFERENCES events(id),
  creat_el timestamptz DEFAULT now(),
  actualitzat_el timestamptz DEFAULT now()
);

CREATE TABLE notification_preferences (
  user_id uuid PRIMARY KEY,
  reptes_nous boolean DEFAULT true,
  caducitat_terminis boolean DEFAULT true,
  recordatoris_partides boolean DEFAULT true,
  hores_abans_recordatori integer DEFAULT 24,
  minuts_abans_caducitat integer DEFAULT 1440,
  silenci_nocturn boolean DEFAULT true,
  hora_inici_silenci time DEFAULT '22:00:00',
  hora_fi_silenci time DEFAULT '08:00:00',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE push_subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  endpoint text NOT NULL,
  p256dh_key text NOT NULL,
  auth_key text NOT NULL,
  user_agent text,
  activa boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE scheduled_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  tipus text NOT NULL,
  scheduled_for timestamptz NOT NULL,
  payload jsonb NOT NULL,
  processed boolean DEFAULT false,
  processed_at timestamptz,
  challenge_id uuid REFERENCES challenges(id),
  event_id uuid,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE notification_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  tipus text NOT NULL,
  titol text NOT NULL,
  missatge text NOT NULL,
  enviada_el timestamptz DEFAULT now(),
  llegida_el timestamptz,
  challenge_id uuid REFERENCES challenges(id),
  event_id uuid,
  payload jsonb,
  success boolean DEFAULT true,
  error_message text
);

-- Create indexes for performance
CREATE INDEX idx_players_numero_soci ON players(numero_soci);
CREATE INDEX idx_challenges_estat ON challenges(estat);
CREATE INDEX idx_challenges_event_id ON challenges(event_id);
CREATE INDEX idx_matches_challenge_id ON matches(challenge_id);
CREATE INDEX idx_ranking_positions_event_id ON ranking_positions(event_id);
CREATE INDEX idx_notification_history_user_id ON notification_history(user_id);
CREATE INDEX idx_scheduled_notifications_scheduled_for ON scheduled_notifications(scheduled_for);
CREATE INDEX idx_push_subscriptions_user_id ON push_subscriptions(user_id);

-- Insert default app settings if not exists
INSERT INTO app_settings (id) VALUES (gen_random_uuid()) 
ON CONFLICT DO NOTHING;