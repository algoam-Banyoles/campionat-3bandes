-- Cloud Database Schema - Current Production State
-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.admins (
  email text NOT NULL,
  CONSTRAINT admins_pkey PRIMARY KEY (email)
);

CREATE TABLE public.app_settings (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  caramboles_objectiu smallint NOT NULL DEFAULT 2,
  max_entrades smallint NOT NULL DEFAULT 50,
  allow_tiebreak boolean NOT NULL DEFAULT true,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  cooldown_min_dies smallint NOT NULL DEFAULT 3 CHECK (cooldown_min_dies >= 0),
  cooldown_max_dies smallint NOT NULL DEFAULT 7 CHECK (cooldown_max_dies >= 0),
  dies_acceptar_repte smallint NOT NULL DEFAULT 7 CHECK (dies_acceptar_repte > 0),
  dies_jugar_despres_acceptar smallint NOT NULL DEFAULT 7 CHECK (dies_jugar_despres_acceptar > 0),
  ranking_max_jugadors smallint NOT NULL DEFAULT 20 CHECK (ranking_max_jugadors > 0),
  max_rank_gap smallint NOT NULL DEFAULT 2 CHECK (max_rank_gap >= 1),
  pre_inactiu_setmanes smallint NOT NULL DEFAULT 3,
  inactiu_setmanes smallint NOT NULL DEFAULT 6,
  CONSTRAINT app_settings_pkey PRIMARY KEY (id)
);

CREATE TABLE public.challenges (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL,
  tipus USER-DEFINED NOT NULL DEFAULT 'normal'::challenge_type,
  reptador_id uuid NOT NULL,
  reptat_id uuid NOT NULL,
  estat USER-DEFINED NOT NULL DEFAULT 'proposat'::challenge_state,
  dates_proposades ARRAY NOT NULL DEFAULT '{}'::timestamp with time zone[],
  data_proposta timestamp with time zone NOT NULL DEFAULT now(),
  data_acceptacio timestamp with time zone,
  observacions text,
  pos_reptador smallint,
  pos_reptat smallint,
  reprogram_count smallint NOT NULL DEFAULT 0,
  data_programada timestamp with time zone,
  reprogramacions integer NOT NULL DEFAULT 0 CHECK (reprogramacions >= 0),
  CONSTRAINT challenges_pkey PRIMARY KEY (id),
  CONSTRAINT challenges_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id),
  CONSTRAINT challenges_reptador_id_fkey FOREIGN KEY (reptador_id) REFERENCES public.players(id),
  CONSTRAINT challenges_reptat_id_fkey FOREIGN KEY (reptat_id) REFERENCES public.players(id)
);

CREATE TABLE public.esdeveniments_club (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  titol text NOT NULL,
  descripcio text,
  data_inici timestamp with time zone NOT NULL,
  data_fi timestamp with time zone,
  tipus text NOT NULL DEFAULT 'general'::text,
  visible_per_tots boolean NOT NULL DEFAULT true,
  creat_per uuid,
  event_id uuid,
  creat_el timestamp with time zone NOT NULL DEFAULT now(),
  actualitzat_el timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT esdeveniments_club_pkey PRIMARY KEY (id),
  CONSTRAINT esdeveniments_club_creat_per_fkey FOREIGN KEY (creat_per) REFERENCES auth.users(id),
  CONSTRAINT esdeveniments_club_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id)
);

CREATE TABLE public.events (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  nom text NOT NULL,
  temporada text NOT NULL,
  creat_el timestamp with time zone NOT NULL DEFAULT now(),
  actiu boolean NOT NULL DEFAULT true,
  CONSTRAINT events_pkey PRIMARY KEY (id)
);

CREATE TABLE public.history_position_changes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL,
  player_id uuid NOT NULL,
  posicio_anterior smallint NOT NULL,
  posicio_nova smallint NOT NULL,
  motiu text NOT NULL,
  ref_challenge uuid,
  creat_el timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT history_position_changes_pkey PRIMARY KEY (id),
  CONSTRAINT history_position_changes_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id),
  CONSTRAINT history_position_changes_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.players(id),
  CONSTRAINT history_position_changes_ref_challenge_fkey FOREIGN KEY (ref_challenge) REFERENCES public.challenges(id)
);

CREATE TABLE public.initial_ranking (
  event_id uuid NOT NULL,
  posicio smallint NOT NULL CHECK (posicio >= 1 AND posicio <= 20),
  player_id uuid NOT NULL,
  CONSTRAINT initial_ranking_pkey PRIMARY KEY (posicio, event_id),
  CONSTRAINT initial_ranking_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id),
  CONSTRAINT initial_ranking_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.players(id)
);

CREATE TABLE public.maintenance_run_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  run_id uuid NOT NULL,
  kind text NOT NULL,
  payload jsonb NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT maintenance_run_items_pkey PRIMARY KEY (id),
  CONSTRAINT maintenance_run_items_run_id_fkey FOREIGN KEY (run_id) REFERENCES public.maintenance_runs(id)
);

CREATE TABLE public.maintenance_runs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  started_at timestamp with time zone NOT NULL DEFAULT now(),
  finished_at timestamp with time zone,
  triggered_by text NOT NULL DEFAULT 'auto'::text,
  ok boolean,
  notes text,
  CONSTRAINT maintenance_runs_pkey PRIMARY KEY (id)
);

CREATE TABLE public.matches (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  challenge_id uuid NOT NULL,
  data_joc timestamp with time zone NOT NULL DEFAULT now(),
  caramboles_reptador smallint CHECK (caramboles_reptador >= 0),
  caramboles_reptat smallint CHECK (caramboles_reptat >= 0),
  entrades smallint CHECK (entrades >= 0),
  serie_max_reptador smallint DEFAULT 0,
  serie_max_reptat smallint DEFAULT 0,
  resultat USER-DEFINED NOT NULL,
  signat_reptador boolean DEFAULT false,
  signat_reptat boolean DEFAULT false,
  creat_el timestamp with time zone NOT NULL DEFAULT now(),
  tiebreak boolean NOT NULL DEFAULT false,
  tiebreak_reptador smallint,
  tiebreak_reptat smallint,
  CONSTRAINT matches_pkey PRIMARY KEY (id),
  CONSTRAINT matches_challenge_id_fkey FOREIGN KEY (challenge_id) REFERENCES public.challenges(id)
);

CREATE TABLE public.mitjanes_historiques (
  id integer NOT NULL DEFAULT nextval('mitjanes_historiques_id_seq'::regclass),
  soci_id integer NOT NULL,
  year integer NOT NULL,
  modalitat character varying NOT NULL,
  mitjana numeric NOT NULL,
  created_at timestamp without time zone DEFAULT now(),
  CONSTRAINT mitjanes_historiques_pkey PRIMARY KEY (id),
  CONSTRAINT fk_mitjanes_historiques_soci_id FOREIGN KEY (soci_id) REFERENCES public.socis(numero_soci)
);

CREATE TABLE public.notes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  content text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT notes_pkey PRIMARY KEY (id),
  CONSTRAINT notes_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);

CREATE TABLE public.notification_history (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  tipus text NOT NULL,
  titol text NOT NULL,
  missatge text NOT NULL,
  enviada_el timestamp with time zone NOT NULL DEFAULT now(),
  llegida_el timestamp with time zone,
  challenge_id uuid,
  event_id uuid,
  payload jsonb,
  success boolean NOT NULL DEFAULT true,
  error_message text,
  CONSTRAINT notification_history_pkey PRIMARY KEY (id),
  CONSTRAINT notification_history_challenge_id_fkey FOREIGN KEY (challenge_id) REFERENCES public.challenges(id),
  CONSTRAINT notification_history_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);

CREATE TABLE public.notification_preferences (
  user_id uuid NOT NULL,
  reptes_nous boolean NOT NULL DEFAULT true,
  caducitat_terminis boolean NOT NULL DEFAULT true,
  recordatoris_partides boolean NOT NULL DEFAULT true,
  hores_abans_recordatori integer NOT NULL DEFAULT 24,
  minuts_abans_caducitat integer NOT NULL DEFAULT 1440,
  silenci_nocturn boolean NOT NULL DEFAULT true,
  hora_inici_silenci time without time zone NOT NULL DEFAULT '22:00:00'::time without time zone,
  hora_fi_silenci time without time zone NOT NULL DEFAULT '08:00:00'::time without time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT notification_preferences_pkey PRIMARY KEY (user_id),
  CONSTRAINT notification_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);

CREATE TABLE public.penalties (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL,
  player_id uuid NOT NULL,
  tipus USER-DEFINED NOT NULL,
  detalls text,
  creat_el timestamp with time zone NOT NULL DEFAULT now(),
  challenge_id uuid,
  CONSTRAINT penalties_pkey PRIMARY KEY (id),
  CONSTRAINT penalties_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id),
  CONSTRAINT penalties_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.players(id),
  CONSTRAINT penalties_challenge_id_fkey FOREIGN KEY (challenge_id) REFERENCES public.challenges(id)
);

CREATE TABLE public.player_weekly_positions (
  event_id uuid NOT NULL,
  player_id uuid NOT NULL,
  setmana integer NOT NULL,
  posicio integer NOT NULL,
  CONSTRAINT player_weekly_positions_pkey PRIMARY KEY (player_id, setmana, event_id),
  CONSTRAINT player_weekly_positions_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id),
  CONSTRAINT player_weekly_positions_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.players(id)
);

CREATE TABLE public.players (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  nom text NOT NULL,
  email text UNIQUE,
  mitjana numeric,
  estat USER-DEFINED NOT NULL DEFAULT 'actiu'::player_state,
  club text,
  avatar_url text,
  data_ultim_repte date,
  creat_el timestamp with time zone NOT NULL DEFAULT now(),
  numero_soci integer,
  CONSTRAINT players_pkey PRIMARY KEY (id),
  CONSTRAINT players_numero_soci_fkey FOREIGN KEY (numero_soci) REFERENCES public.socis(numero_soci)
);

CREATE TABLE public.push_subscriptions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  endpoint text NOT NULL UNIQUE,
  p256dh_key text NOT NULL,
  auth_key text NOT NULL,
  user_agent text,
  activa boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT push_subscriptions_pkey PRIMARY KEY (id),
  CONSTRAINT push_subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);

CREATE TABLE public.ranking_positions (
  event_id uuid NOT NULL,
  posicio smallint NOT NULL CHECK (posicio >= 1 AND posicio <= 20),
  player_id uuid NOT NULL,
  assignat_el timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT ranking_positions_pkey PRIMARY KEY (posicio, event_id),
  CONSTRAINT ranking_positions_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id),
  CONSTRAINT ranking_positions_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.players(id)
);

CREATE TABLE public.scheduled_notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  tipus text NOT NULL,
  scheduled_for timestamp with time zone NOT NULL,
  payload jsonb NOT NULL,
  processed boolean NOT NULL DEFAULT false,
  processed_at timestamp with time zone,
  challenge_id uuid,
  event_id uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT scheduled_notifications_pkey PRIMARY KEY (id),
  CONSTRAINT scheduled_notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT scheduled_notifications_challenge_id_fkey FOREIGN KEY (challenge_id) REFERENCES public.challenges(id)
);

CREATE TABLE public.socis (
  numero_soci integer NOT NULL,
  cognoms text NOT NULL,
  nom text NOT NULL,
  email text UNIQUE,
  de_baixa boolean DEFAULT false,
  data_baixa date,
  CONSTRAINT socis_pkey PRIMARY KEY (numero_soci)
);

CREATE TABLE public.waiting_list (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL,
  ordre integer NOT NULL,
  data_inscripcio timestamp with time zone NOT NULL DEFAULT now(),
  event_id uuid NOT NULL,
  CONSTRAINT waiting_list_pkey PRIMARY KEY (id),
  CONSTRAINT waiting_list_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.players(id),
  CONSTRAINT waiting_list_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id)
);