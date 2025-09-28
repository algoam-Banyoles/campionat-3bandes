-- Migration generated from Supabase cloud schema
-- Generated at: 2025-09-28T10:15:41.156Z

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Custom types
CREATE TYPE penalty_type AS ENUM ('incompareixenca', 'desacord_dates', 'pre_inactivitat', 'inactivitat', 'baixa_voluntaria');
CREATE TYPE match_result AS ENUM ('guanya_reptador', 'guanya_reptat', 'empat_tiebreak_reptador', 'empat_tiebreak_reptat', 'walkover_reptador', 'walkover_reptat');
CREATE TYPE player_state AS ENUM ('actiu', 'pre_inactiu', 'inactiu', 'baixa');
CREATE TYPE challenge_type AS ENUM ('normal', 'access');
CREATE TYPE challenge_state AS ENUM ('proposat', 'acceptat', 'refusat', 'caducat', 'jugat', 'anullat', 'programat');

-- Tables

-- Table: admins
CREATE TABLE admins (
  email text PRIMARY KEY NOT NULL
);

-- Table: app_settings
CREATE TABLE app_settings (
  id uuid PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
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

-- Table: calendari_partides
CREATE TABLE calendari_partides (
  id uuid PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL DEFAULT gen_random_uuid(),
  categoria_id uuid NOT NULL DEFAULT gen_random_uuid(),
  jugador1_id uuid NOT NULL DEFAULT gen_random_uuid(),
  jugador2_id uuid NOT NULL DEFAULT gen_random_uuid(),
  data_programada timestamptz NOT NULL,
  hora_inici time NOT NULL,
  taula_assignada integer NOT NULL,
  estat text NOT NULL DEFAULT 'generat',
  validat_per uuid NOT NULL,
  data_validacio timestamptz NOT NULL,
  observacions_junta text NOT NULL,
  data_canvi_solicitada timestamptz NOT NULL,
  motiu_canvi text NOT NULL,
  aprovat_canvi_per uuid NOT NULL,
  data_aprovacio_canvi timestamptz NOT NULL,
  match_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Table: categories
CREATE TABLE categories (
  id uuid PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL DEFAULT gen_random_uuid(),
  nom text NOT NULL,
  distancia_caramboles integer NOT NULL DEFAULT 0,
  max_entrades integer NOT NULL DEFAULT 50,
  ordre_categoria smallint NOT NULL DEFAULT 0,
  min_jugadors integer NOT NULL DEFAULT 8,
  max_jugadors integer NOT NULL DEFAULT 12,
  created_at timestamptz NOT NULL DEFAULT now(),
  promig_minim numeric NOT NULL
);

-- Table: challenges
CREATE TABLE challenges (
  id uuid PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tipus public.challenge_type NOT NULL DEFAULT 'normal',
  reptador_id uuid NOT NULL DEFAULT gen_random_uuid(),
  reptat_id uuid NOT NULL DEFAULT gen_random_uuid(),
  estat public.challenge_state NOT NULL DEFAULT 'proposat',
  dates_proposades text[] NOT NULL,
  data_proposta timestamptz NOT NULL DEFAULT now(),
  data_acceptacio timestamptz NOT NULL,
  observacions text NOT NULL,
  pos_reptador smallint NOT NULL,
  pos_reptat smallint NOT NULL,
  reprogram_count smallint NOT NULL DEFAULT 0,
  data_programada timestamptz NOT NULL,
  reprogramacions integer NOT NULL DEFAULT 0
);

-- Table: classificacions
CREATE TABLE classificacions (
  id uuid PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL DEFAULT gen_random_uuid(),
  categoria_id uuid NOT NULL DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL DEFAULT gen_random_uuid(),
  posicio integer NOT NULL DEFAULT 0,
  partides_jugades integer NOT NULL DEFAULT 0,
  partides_guanyades integer NOT NULL DEFAULT 0,
  partides_perdudes integer NOT NULL DEFAULT 0,
  partides_empat integer NOT NULL DEFAULT 0,
  punts integer NOT NULL DEFAULT 0,
  caramboles_favor integer NOT NULL DEFAULT 0,
  caramboles_contra integer NOT NULL DEFAULT 0,
  mitjana_particular numeric NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Table: configuracio_calendari
CREATE TABLE configuracio_calendari (
  id uuid PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL DEFAULT gen_random_uuid(),
  dies_setmana text[] NOT NULL,
  hores_disponibles text[] NOT NULL,
  taules_per_slot integer NOT NULL DEFAULT 3,
  max_partides_per_setmana integer NOT NULL DEFAULT 3,
  max_partides_per_dia integer NOT NULL DEFAULT 1,
  dies_festius text[] NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Table: esdeveniments_club
CREATE TABLE esdeveniments_club (
  id uuid PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
  titol text NOT NULL,
  descripcio text NOT NULL,
  data_inici timestamptz NOT NULL,
  data_fi timestamptz NOT NULL,
  tipus text NOT NULL DEFAULT 'general',
  visible_per_tots boolean NOT NULL DEFAULT true,
  creat_per uuid NOT NULL,
  event_id uuid NOT NULL,
  creat_el timestamptz NOT NULL DEFAULT now(),
  actualitzat_el timestamptz NOT NULL DEFAULT now()
);

-- Table: events
CREATE TABLE events (
  id uuid PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
  nom text NOT NULL,
  temporada text NOT NULL,
  creat_el timestamptz NOT NULL DEFAULT now(),
  actiu boolean NOT NULL DEFAULT true,
  modalitat text NOT NULL,
  tipus_competicio text NOT NULL,
  format_joc text NOT NULL,
  data_inici date NOT NULL,
  data_fi date NOT NULL,
  estat_competicio text NOT NULL DEFAULT 'planificacio',
  max_participants integer NOT NULL,
  quota_inscripcio numeric NOT NULL
);

-- Table: history_position_changes
CREATE TABLE history_position_changes (
  id uuid PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL DEFAULT gen_random_uuid(),
  posicio_anterior smallint NOT NULL DEFAULT 0,
  posicio_nova smallint NOT NULL DEFAULT 0,
  motiu text NOT NULL,
  ref_challenge uuid NOT NULL,
  creat_el timestamptz NOT NULL DEFAULT now()
);

-- Table: initial_ranking
CREATE TABLE initial_ranking (
  event_id uuid PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
  posicio smallint PRIMARY KEY NOT NULL DEFAULT 0,
  player_id uuid NOT NULL DEFAULT gen_random_uuid()
);

-- Table: inscripcions
CREATE TABLE inscripcions (
  id uuid PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL DEFAULT gen_random_uuid(),
  soci_numero integer NOT NULL DEFAULT 0,
  categoria_assignada_id uuid NOT NULL,
  data_inscripcio timestamptz NOT NULL DEFAULT now(),
  preferencies_dies text[] NOT NULL,
  preferencies_hores text[] NOT NULL,
  restriccions_especials text NOT NULL,
  observacions text NOT NULL,
  pagat boolean NOT NULL DEFAULT false,
  confirmat boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Table: maintenance_run_items
CREATE TABLE maintenance_run_items (
  id uuid PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
  run_id uuid NOT NULL DEFAULT gen_random_uuid(),
  kind text NOT NULL,
  payload jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Table: maintenance_runs
CREATE TABLE maintenance_runs (
  id uuid PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
  started_at timestamptz NOT NULL DEFAULT now(),
  finished_at timestamptz NOT NULL,
  triggered_by text NOT NULL DEFAULT 'auto',
  ok boolean NOT NULL,
  notes text NOT NULL
);

-- Table: matches
CREATE TABLE matches (
  id uuid PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
  challenge_id uuid NOT NULL DEFAULT gen_random_uuid(),
  data_joc timestamptz NOT NULL DEFAULT now(),
  caramboles_reptador smallint NOT NULL,
  caramboles_reptat smallint NOT NULL,
  entrades smallint NOT NULL,
  serie_max_reptador smallint NOT NULL DEFAULT 0,
  serie_max_reptat smallint NOT NULL DEFAULT 0,
  resultat public.match_result NOT NULL,
  signat_reptador boolean NOT NULL DEFAULT false,
  signat_reptat boolean NOT NULL DEFAULT false,
  creat_el timestamptz NOT NULL DEFAULT now(),
  tiebreak boolean NOT NULL DEFAULT false,
  tiebreak_reptador smallint NOT NULL,
  tiebreak_reptat smallint NOT NULL,
  jornada integer NOT NULL,
  categoria_id uuid NOT NULL,
  tipus_partida text NOT NULL DEFAULT 'challenge'
);

-- Table: mitjanes_historiques
CREATE TABLE mitjanes_historiques (
  id integer PRIMARY KEY NOT NULL DEFAULT 0,
  soci_id integer NOT NULL DEFAULT 0,
  year integer NOT NULL DEFAULT 0,
  modalitat varchar(20) NOT NULL,
  mitjana numeric NOT NULL,
  created_at timestamp NOT NULL DEFAULT now()
);

-- Table: notes
CREATE TABLE notes (
  id uuid PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  content text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Table: notification_history
CREATE TABLE notification_history (
  id uuid PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tipus text NOT NULL,
  titol text NOT NULL,
  missatge text NOT NULL,
  enviada_el timestamptz NOT NULL DEFAULT now(),
  llegida_el timestamptz NOT NULL,
  challenge_id uuid NOT NULL,
  event_id uuid NOT NULL,
  payload jsonb NOT NULL,
  success boolean NOT NULL DEFAULT true,
  error_message text NOT NULL
);

-- Table: notification_preferences
CREATE TABLE notification_preferences (
  user_id uuid PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
  reptes_nous boolean NOT NULL DEFAULT true,
  caducitat_terminis boolean NOT NULL DEFAULT true,
  recordatoris_partides boolean NOT NULL DEFAULT true,
  hores_abans_recordatori integer NOT NULL DEFAULT 24,
  minuts_abans_caducitat integer NOT NULL DEFAULT 1440,
  silenci_nocturn boolean NOT NULL DEFAULT true,
  hora_inici_silenci time NOT NULL DEFAULT '22:00:00',
  hora_fi_silenci time NOT NULL DEFAULT '08:00:00',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Table: penalties
CREATE TABLE penalties (
  id uuid PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tipus public.penalty_type NOT NULL,
  detalls text NOT NULL,
  creat_el timestamptz NOT NULL DEFAULT now(),
  challenge_id uuid NOT NULL
);

-- Table: player_weekly_positions
CREATE TABLE player_weekly_positions (
  event_id uuid PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
  player_id uuid PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
  setmana integer PRIMARY KEY NOT NULL DEFAULT 0,
  posicio integer NOT NULL DEFAULT 0
);

-- Table: players
CREATE TABLE players (
  id uuid PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
  nom text NOT NULL,
  email text NOT NULL,
  mitjana numeric NOT NULL,
  estat public.player_state NOT NULL DEFAULT 'actiu',
  club text NOT NULL,
  avatar_url text NOT NULL,
  data_ultim_repte date NOT NULL,
  creat_el timestamptz NOT NULL DEFAULT now(),
  numero_soci integer NOT NULL
);

-- Table: push_subscriptions
CREATE TABLE push_subscriptions (
  id uuid PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL DEFAULT gen_random_uuid(),
  endpoint text NOT NULL,
  p256dh_key text NOT NULL,
  auth_key text NOT NULL,
  user_agent text NOT NULL,
  activa boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Table: ranking_positions
CREATE TABLE ranking_positions (
  event_id uuid PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
  posicio smallint PRIMARY KEY NOT NULL DEFAULT 0,
  player_id uuid NOT NULL DEFAULT gen_random_uuid(),
  assignat_el timestamptz NOT NULL DEFAULT now()
);

-- Table: scheduled_notifications
CREATE TABLE scheduled_notifications (
  id uuid PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tipus text NOT NULL,
  scheduled_for timestamptz NOT NULL,
  payload jsonb NOT NULL,
  processed boolean NOT NULL DEFAULT false,
  processed_at timestamptz NOT NULL,
  challenge_id uuid NOT NULL,
  event_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Table: socis
CREATE TABLE socis (
  numero_soci integer PRIMARY KEY NOT NULL DEFAULT 0,
  cognoms text NOT NULL,
  nom text NOT NULL,
  email text NOT NULL,
  de_baixa boolean NOT NULL DEFAULT false,
  data_baixa date NOT NULL
);

-- Table: waiting_list
CREATE TABLE waiting_list (
  id uuid PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL DEFAULT gen_random_uuid(),
  ordre integer NOT NULL DEFAULT 0,
  data_inscripcio timestamptz NOT NULL DEFAULT now(),
  event_id uuid NOT NULL DEFAULT gen_random_uuid()
);

-- Foreign keys
ALTER TABLE calendari_partides ADD CONSTRAINT fk_calendari_partides_event_id FOREIGN KEY (event_id) REFERENCES events(id);
ALTER TABLE calendari_partides ADD CONSTRAINT fk_calendari_partides_categoria_id FOREIGN KEY (categoria_id) REFERENCES categories(id);
ALTER TABLE calendari_partides ADD CONSTRAINT fk_calendari_partides_jugador1_id FOREIGN KEY (jugador1_id) REFERENCES players(id);
ALTER TABLE calendari_partides ADD CONSTRAINT fk_calendari_partides_jugador2_id FOREIGN KEY (jugador2_id) REFERENCES players(id);
ALTER TABLE calendari_partides ADD CONSTRAINT fk_calendari_partides_match_id FOREIGN KEY (match_id) REFERENCES matches(id);
ALTER TABLE categories ADD CONSTRAINT fk_categories_event_id FOREIGN KEY (event_id) REFERENCES events(id);
ALTER TABLE challenges ADD CONSTRAINT fk_challenges_event_id FOREIGN KEY (event_id) REFERENCES events(id);
ALTER TABLE challenges ADD CONSTRAINT fk_challenges_reptador_id FOREIGN KEY (reptador_id) REFERENCES players(id);
ALTER TABLE challenges ADD CONSTRAINT fk_challenges_reptat_id FOREIGN KEY (reptat_id) REFERENCES players(id);
ALTER TABLE classificacions ADD CONSTRAINT fk_classificacions_event_id FOREIGN KEY (event_id) REFERENCES events(id);
ALTER TABLE classificacions ADD CONSTRAINT fk_classificacions_categoria_id FOREIGN KEY (categoria_id) REFERENCES categories(id);
ALTER TABLE classificacions ADD CONSTRAINT fk_classificacions_player_id FOREIGN KEY (player_id) REFERENCES players(id);
ALTER TABLE configuracio_calendari ADD CONSTRAINT fk_configuracio_calendari_event_id FOREIGN KEY (event_id) REFERENCES events(id);
ALTER TABLE esdeveniments_club ADD CONSTRAINT fk_esdeveniments_club_event_id FOREIGN KEY (event_id) REFERENCES events(id);
ALTER TABLE history_position_changes ADD CONSTRAINT fk_history_position_changes_event_id FOREIGN KEY (event_id) REFERENCES events(id);
ALTER TABLE history_position_changes ADD CONSTRAINT fk_history_position_changes_player_id FOREIGN KEY (player_id) REFERENCES players(id);
ALTER TABLE history_position_changes ADD CONSTRAINT fk_history_position_changes_ref_challenge FOREIGN KEY (ref_challenge) REFERENCES challenges(id);
ALTER TABLE initial_ranking ADD CONSTRAINT fk_initial_ranking_event_id FOREIGN KEY (event_id) REFERENCES events(id);
ALTER TABLE initial_ranking ADD CONSTRAINT fk_initial_ranking_player_id FOREIGN KEY (player_id) REFERENCES players(id);
ALTER TABLE inscripcions ADD CONSTRAINT fk_inscripcions_event_id FOREIGN KEY (event_id) REFERENCES events(id);
ALTER TABLE inscripcions ADD CONSTRAINT fk_inscripcions_soci_numero FOREIGN KEY (soci_numero) REFERENCES socis(numero_soci);
ALTER TABLE inscripcions ADD CONSTRAINT fk_inscripcions_categoria_assignada_id FOREIGN KEY (categoria_assignada_id) REFERENCES categories(id);
ALTER TABLE maintenance_run_items ADD CONSTRAINT fk_maintenance_run_items_run_id FOREIGN KEY (run_id) REFERENCES maintenance_runs(id);
ALTER TABLE matches ADD CONSTRAINT fk_matches_challenge_id FOREIGN KEY (challenge_id) REFERENCES challenges(id);
ALTER TABLE matches ADD CONSTRAINT fk_matches_categoria_id FOREIGN KEY (categoria_id) REFERENCES categories(id);
ALTER TABLE mitjanes_historiques ADD CONSTRAINT fk_mitjanes_historiques_soci_id FOREIGN KEY (soci_id) REFERENCES socis(numero_soci);
ALTER TABLE notification_history ADD CONSTRAINT fk_notification_history_challenge_id FOREIGN KEY (challenge_id) REFERENCES challenges(id);
ALTER TABLE penalties ADD CONSTRAINT fk_penalties_event_id FOREIGN KEY (event_id) REFERENCES events(id);
ALTER TABLE penalties ADD CONSTRAINT fk_penalties_player_id FOREIGN KEY (player_id) REFERENCES players(id);
ALTER TABLE penalties ADD CONSTRAINT fk_penalties_challenge_id FOREIGN KEY (challenge_id) REFERENCES challenges(id);
ALTER TABLE player_weekly_positions ADD CONSTRAINT fk_player_weekly_positions_event_id FOREIGN KEY (event_id) REFERENCES events(id);
ALTER TABLE player_weekly_positions ADD CONSTRAINT fk_player_weekly_positions_player_id FOREIGN KEY (player_id) REFERENCES players(id);
ALTER TABLE players ADD CONSTRAINT fk_players_numero_soci FOREIGN KEY (numero_soci) REFERENCES socis(numero_soci);
ALTER TABLE ranking_positions ADD CONSTRAINT fk_ranking_positions_event_id FOREIGN KEY (event_id) REFERENCES events(id);
ALTER TABLE ranking_positions ADD CONSTRAINT fk_ranking_positions_player_id FOREIGN KEY (player_id) REFERENCES players(id);
ALTER TABLE scheduled_notifications ADD CONSTRAINT fk_scheduled_notifications_challenge_id FOREIGN KEY (challenge_id) REFERENCES challenges(id);
ALTER TABLE waiting_list ADD CONSTRAINT fk_waiting_list_player_id FOREIGN KEY (player_id) REFERENCES players(id);
ALTER TABLE waiting_list ADD CONSTRAINT fk_waiting_list_event_id FOREIGN KEY (event_id) REFERENCES events(id);

-- Views (to be implemented):
-- v_maintenance_run_details
-- v_player_timeline
-- v_promocions_candidates
-- v_maintenance_runs
-- v_challenges_pending
-- v_player_badges
-- v_analisi_calendari
