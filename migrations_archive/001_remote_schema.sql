drop extension if exists "pg_net";

create extension if not exists "btree_gist" with schema "public";

create type "public"."challenge_state" as enum ('proposat', 'acceptat', 'refusat', 'caducat', 'jugat', 'anullat', 'programat');

create type "public"."challenge_type" as enum ('normal', 'access');

create type "public"."match_result" as enum ('guanya_reptador', 'guanya_reptat', 'empat_tiebreak_reptador', 'empat_tiebreak_reptat', 'walkover_reptador', 'walkover_reptat');

create type "public"."penalty_type" as enum ('incompareixenca', 'desacord_dates', 'pre_inactivitat', 'inactivitat', 'baixa_voluntaria');

create type "public"."player_state" as enum ('actiu', 'pre_inactiu', 'inactiu', 'baixa');


  create table "public"."admins" (
    "email" text not null
      );


alter table "public"."admins" enable row level security;


  create table "public"."app_settings" (
    "id" uuid not null default gen_random_uuid(),
    "caramboles_objectiu" smallint not null default 2,
    "max_entrades" smallint not null default 50,
    "allow_tiebreak" boolean not null default true,
    "updated_at" timestamp with time zone not null default now(),
    "cooldown_min_dies" smallint not null default 3,
    "cooldown_max_dies" smallint not null default 7,
    "dies_acceptar_repte" smallint not null default 7,
    "dies_jugar_despres_acceptar" smallint not null default 7,
    "ranking_max_jugadors" smallint not null default 20,
    "max_rank_gap" smallint not null default 2,
    "pre_inactiu_setmanes" smallint not null default 3,
    "inactiu_setmanes" smallint not null default 6
      );


alter table "public"."app_settings" enable row level security;


  create table "public"."challenges" (
    "id" uuid not null default gen_random_uuid(),
    "event_id" uuid not null,
    "tipus" challenge_type not null default 'normal'::challenge_type,
    "reptador_id" uuid not null,
    "reptat_id" uuid not null,
    "estat" challenge_state not null default 'proposat'::challenge_state,
    "dates_proposades" timestamp with time zone[] not null default '{}'::timestamp with time zone[],
    "data_proposta" timestamp with time zone not null default now(),
    "data_acceptacio" timestamp with time zone,
    "observacions" text,
    "pos_reptador" smallint,
    "pos_reptat" smallint,
    "reprogram_count" smallint not null default 0,
    "data_programada" timestamp with time zone,
    "reprogramacions" integer not null default 0
      );


alter table "public"."challenges" enable row level security;


  create table "public"."events" (
    "id" uuid not null default gen_random_uuid(),
    "nom" text not null,
    "temporada" text not null,
    "creat_el" timestamp with time zone not null default now(),
    "actiu" boolean not null default true
      );


alter table "public"."events" enable row level security;


  create table "public"."history_position_changes" (
    "id" uuid not null default gen_random_uuid(),
    "event_id" uuid not null,
    "player_id" uuid not null,
    "posicio_anterior" smallint not null,
    "posicio_nova" smallint not null,
    "motiu" text not null,
    "ref_challenge" uuid,
    "creat_el" timestamp with time zone not null default now()
      );


alter table "public"."history_position_changes" enable row level security;


  create table "public"."initial_ranking" (
    "event_id" uuid not null,
    "posicio" smallint not null,
    "player_id" uuid not null
      );


alter table "public"."initial_ranking" enable row level security;


  create table "public"."maintenance_run_items" (
    "id" uuid not null default gen_random_uuid(),
    "run_id" uuid not null,
    "kind" text not null,
    "payload" jsonb not null,
    "created_at" timestamp with time zone not null default now()
      );



  create table "public"."maintenance_runs" (
    "id" uuid not null default gen_random_uuid(),
    "started_at" timestamp with time zone not null default now(),
    "finished_at" timestamp with time zone,
    "triggered_by" text not null default 'auto'::text,
    "ok" boolean,
    "notes" text
      );



  create table "public"."matches" (
    "id" uuid not null default gen_random_uuid(),
    "challenge_id" uuid not null,
    "data_joc" timestamp with time zone not null default now(),
    "caramboles_reptador" smallint,
    "caramboles_reptat" smallint,
    "entrades" smallint,
    "serie_max_reptador" smallint default 0,
    "serie_max_reptat" smallint default 0,
    "resultat" match_result not null,
    "signat_reptador" boolean default false,
    "signat_reptat" boolean default false,
    "creat_el" timestamp with time zone not null default now(),
    "tiebreak" boolean not null default false,
    "tiebreak_reptador" smallint,
    "tiebreak_reptat" smallint
      );


alter table "public"."matches" enable row level security;


  create table "public"."notes" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid,
    "content" text not null,
    "created_at" timestamp with time zone default now()
      );


alter table "public"."notes" enable row level security;


  create table "public"."penalties" (
    "id" uuid not null default gen_random_uuid(),
    "event_id" uuid not null,
    "player_id" uuid not null,
    "tipus" penalty_type not null,
    "detalls" text,
    "creat_el" timestamp with time zone not null default now(),
    "challenge_id" uuid
      );


alter table "public"."penalties" enable row level security;


  create table "public"."player_weekly_positions" (
    "event_id" uuid not null,
    "player_id" uuid not null,
    "setmana" integer not null,
    "posicio" integer not null
      );


alter table "public"."player_weekly_positions" enable row level security;


  create table "public"."players" (
    "id" uuid not null default gen_random_uuid(),
    "nom" text not null,
    "email" text,
    "mitjana" numeric(6,3),
    "estat" player_state not null default 'actiu'::player_state,
    "club" text,
    "avatar_url" text,
    "data_ultim_repte" date,
    "creat_el" timestamp with time zone not null default now(),
    "numero_soci" integer
      );


alter table "public"."players" enable row level security;


  create table "public"."ranking_positions" (
    "event_id" uuid not null,
    "posicio" smallint not null,
    "player_id" uuid not null,
    "assignat_el" timestamp with time zone not null default now()
      );


alter table "public"."ranking_positions" enable row level security;


  create table "public"."socis" (
    "numero_soci" integer not null,
    "cognoms" text not null,
    "nom" text not null,
    "email" text
      );



  create table "public"."waiting_list" (
    "id" uuid not null default gen_random_uuid(),
    "player_id" uuid not null,
    "ordre" integer not null,
    "data_inscripcio" timestamp with time zone not null default now(),
    "event_id" uuid not null
      );


alter table "public"."waiting_list" enable row level security;

CREATE UNIQUE INDEX admins_pkey ON public.admins USING btree (email);

CREATE UNIQUE INDEX app_settings_pkey ON public.app_settings USING btree (id);

CREATE UNIQUE INDEX challenges_pkey ON public.challenges USING btree (id);

CREATE UNIQUE INDEX events_pkey ON public.events USING btree (id);

CREATE UNIQUE INDEX history_position_changes_pkey ON public.history_position_changes USING btree (id);

CREATE INDEX idx_challenges_event_players ON public.challenges USING btree (event_id, reptador_id, reptat_id);

CREATE INDEX idx_initial_ranking_event ON public.initial_ranking USING btree (event_id, posicio);

CREATE INDEX idx_maintenance_run_items_run ON public.maintenance_run_items USING btree (run_id);

CREATE INDEX idx_matches_challenge ON public.matches USING btree (challenge_id);

CREATE INDEX idx_matches_data_joc ON public.matches USING btree (data_joc);

CREATE INDEX idx_rp_event_player ON public.ranking_positions USING btree (event_id, player_id);

CREATE INDEX idx_rp_event_pos ON public.ranking_positions USING btree (event_id, posicio);

CREATE INDEX idx_waiting_ordre ON public.waiting_list USING btree (ordre);

CREATE UNIQUE INDEX initial_ranking_pkey ON public.initial_ranking USING btree (event_id, posicio);

CREATE INDEX ix_waiting_ordre ON public.waiting_list USING btree (ordre);

CREATE UNIQUE INDEX maintenance_run_items_pkey ON public.maintenance_run_items USING btree (id);

CREATE UNIQUE INDEX maintenance_runs_pkey ON public.maintenance_runs USING btree (id);

CREATE UNIQUE INDEX matches_pkey ON public.matches USING btree (id);

CREATE UNIQUE INDEX notes_pkey ON public.notes USING btree (id);

CREATE UNIQUE INDEX penalties_pkey ON public.penalties USING btree (id);

CREATE UNIQUE INDEX player_weekly_positions_pkey ON public.player_weekly_positions USING btree (event_id, player_id, setmana);

CREATE INDEX player_weekly_positions_player_idx ON public.player_weekly_positions USING btree (player_id);

CREATE UNIQUE INDEX players_email_key ON public.players USING btree (email);

CREATE UNIQUE INDEX players_pkey ON public.players USING btree (id);

CREATE UNIQUE INDEX ranking_positions_event_player_uk ON public.ranking_positions USING btree (event_id, player_id);

CREATE UNIQUE INDEX ranking_positions_pkey ON public.ranking_positions USING btree (event_id, posicio);

CREATE UNIQUE INDEX socis_email_key ON public.socis USING btree (email);

CREATE UNIQUE INDEX socis_pkey ON public.socis USING btree (numero_soci);

CREATE UNIQUE INDEX uq_event_unique ON public.events USING btree (nom, temporada);

CREATE UNIQUE INDEX uq_one_active_challenge_per_challengee ON public.challenges USING btree (reptat_id) WHERE (estat = ANY (ARRAY['proposat'::challenge_state, 'acceptat'::challenge_state]));

CREATE UNIQUE INDEX uq_one_active_challenge_per_challenger ON public.challenges USING btree (reptador_id) WHERE (estat = ANY (ARRAY['proposat'::challenge_state, 'acceptat'::challenge_state]));

CREATE UNIQUE INDEX uq_one_active_challenge_per_pair ON public.challenges USING btree (LEAST(reptador_id, reptat_id), GREATEST(reptador_id, reptat_id)) WHERE (estat = ANY (ARRAY['proposat'::challenge_state, 'acceptat'::challenge_state]));

CREATE UNIQUE INDEX ux_challenge_active_pair ON public.challenges USING btree (event_id, reptador_id, reptat_id) WHERE (estat = ANY (ARRAY['proposat'::challenge_state, 'acceptat'::challenge_state, 'programat'::challenge_state]));

CREATE UNIQUE INDEX ux_challenge_active_reptador ON public.challenges USING btree (event_id, reptador_id) WHERE (estat = ANY (ARRAY['proposat'::challenge_state, 'acceptat'::challenge_state, 'programat'::challenge_state]));

CREATE UNIQUE INDEX ux_challenge_active_reptat ON public.challenges USING btree (event_id, reptat_id) WHERE (estat = ANY (ARRAY['proposat'::challenge_state, 'acceptat'::challenge_state, 'programat'::challenge_state]));

CREATE UNIQUE INDEX ux_events_actiu ON public.events USING btree (actiu) WHERE actiu;

CREATE UNIQUE INDEX ux_one_active_challenge_as_reptador ON public.challenges USING btree (reptador_id) WHERE (estat = ANY (ARRAY['proposat'::challenge_state, 'acceptat'::challenge_state]));

CREATE UNIQUE INDEX ux_one_active_challenge_as_reptat ON public.challenges USING btree (reptat_id) WHERE (estat = ANY (ARRAY['proposat'::challenge_state, 'acceptat'::challenge_state]));

CREATE INDEX waiting_list_event_ordre_idx ON public.waiting_list USING btree (event_id, ordre);

CREATE UNIQUE INDEX waiting_list_event_player_uk ON public.waiting_list USING btree (event_id, player_id);

CREATE UNIQUE INDEX waiting_list_pkey ON public.waiting_list USING btree (id);

alter table "public"."admins" add constraint "admins_pkey" PRIMARY KEY using index "admins_pkey";

alter table "public"."app_settings" add constraint "app_settings_pkey" PRIMARY KEY using index "app_settings_pkey";

alter table "public"."challenges" add constraint "challenges_pkey" PRIMARY KEY using index "challenges_pkey";

alter table "public"."events" add constraint "events_pkey" PRIMARY KEY using index "events_pkey";

alter table "public"."history_position_changes" add constraint "history_position_changes_pkey" PRIMARY KEY using index "history_position_changes_pkey";

alter table "public"."initial_ranking" add constraint "initial_ranking_pkey" PRIMARY KEY using index "initial_ranking_pkey";

alter table "public"."maintenance_run_items" add constraint "maintenance_run_items_pkey" PRIMARY KEY using index "maintenance_run_items_pkey";

alter table "public"."maintenance_runs" add constraint "maintenance_runs_pkey" PRIMARY KEY using index "maintenance_runs_pkey";

alter table "public"."matches" add constraint "matches_pkey" PRIMARY KEY using index "matches_pkey";

alter table "public"."notes" add constraint "notes_pkey" PRIMARY KEY using index "notes_pkey";

alter table "public"."penalties" add constraint "penalties_pkey" PRIMARY KEY using index "penalties_pkey";

alter table "public"."player_weekly_positions" add constraint "player_weekly_positions_pkey" PRIMARY KEY using index "player_weekly_positions_pkey";

alter table "public"."players" add constraint "players_pkey" PRIMARY KEY using index "players_pkey";

alter table "public"."ranking_positions" add constraint "ranking_positions_pkey" PRIMARY KEY using index "ranking_positions_pkey" DEFERRABLE;

alter table "public"."socis" add constraint "socis_pkey" PRIMARY KEY using index "socis_pkey";

alter table "public"."waiting_list" add constraint "waiting_list_pkey" PRIMARY KEY using index "waiting_list_pkey";

alter table "public"."app_settings" add constraint "app_settings_cooldown_max_dies_check" CHECK ((cooldown_max_dies >= 0)) not valid;

alter table "public"."app_settings" validate constraint "app_settings_cooldown_max_dies_check";

alter table "public"."app_settings" add constraint "app_settings_cooldown_min_dies_check" CHECK ((cooldown_min_dies >= 0)) not valid;

alter table "public"."app_settings" validate constraint "app_settings_cooldown_min_dies_check";

alter table "public"."app_settings" add constraint "app_settings_dies_acceptar_repte_check" CHECK ((dies_acceptar_repte > 0)) not valid;

alter table "public"."app_settings" validate constraint "app_settings_dies_acceptar_repte_check";

alter table "public"."app_settings" add constraint "app_settings_dies_jugar_despres_acceptar_check" CHECK ((dies_jugar_despres_acceptar > 0)) not valid;

alter table "public"."app_settings" validate constraint "app_settings_dies_jugar_despres_acceptar_check";

alter table "public"."app_settings" add constraint "app_settings_max_rank_gap_check" CHECK ((max_rank_gap >= 1)) not valid;

alter table "public"."app_settings" validate constraint "app_settings_max_rank_gap_check";

alter table "public"."app_settings" add constraint "app_settings_ranking_max_jugadors_check" CHECK ((ranking_max_jugadors > 0)) not valid;

alter table "public"."app_settings" validate constraint "app_settings_ranking_max_jugadors_check";

alter table "public"."challenges" add constraint "challenges_event_id_fkey" FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE not valid;

alter table "public"."challenges" validate constraint "challenges_event_id_fkey";

alter table "public"."challenges" add constraint "challenges_reprogramacions_ck" CHECK ((reprogramacions >= 0)) not valid;

alter table "public"."challenges" validate constraint "challenges_reprogramacions_ck";

alter table "public"."challenges" add constraint "challenges_reptador_id_fkey" FOREIGN KEY (reptador_id) REFERENCES players(id) ON DELETE RESTRICT not valid;

alter table "public"."challenges" validate constraint "challenges_reptador_id_fkey";

alter table "public"."challenges" add constraint "challenges_reptat_id_fkey" FOREIGN KEY (reptat_id) REFERENCES players(id) ON DELETE RESTRICT not valid;

alter table "public"."challenges" validate constraint "challenges_reptat_id_fkey";

alter table "public"."history_position_changes" add constraint "history_position_changes_event_id_fkey" FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE not valid;

alter table "public"."history_position_changes" validate constraint "history_position_changes_event_id_fkey";

alter table "public"."history_position_changes" add constraint "history_position_changes_player_id_fkey" FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE not valid;

alter table "public"."history_position_changes" validate constraint "history_position_changes_player_id_fkey";

alter table "public"."history_position_changes" add constraint "history_position_changes_ref_challenge_fkey" FOREIGN KEY (ref_challenge) REFERENCES challenges(id) not valid;

alter table "public"."history_position_changes" validate constraint "history_position_changes_ref_challenge_fkey";

alter table "public"."initial_ranking" add constraint "initial_ranking_event_id_fkey" FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE not valid;

alter table "public"."initial_ranking" validate constraint "initial_ranking_event_id_fkey";

alter table "public"."initial_ranking" add constraint "initial_ranking_player_id_fkey" FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE RESTRICT not valid;

alter table "public"."initial_ranking" validate constraint "initial_ranking_player_id_fkey";

alter table "public"."initial_ranking" add constraint "initial_ranking_posicio_check" CHECK (((posicio >= 1) AND (posicio <= 20))) not valid;

alter table "public"."initial_ranking" validate constraint "initial_ranking_posicio_check";

alter table "public"."maintenance_run_items" add constraint "maintenance_run_items_run_id_fkey" FOREIGN KEY (run_id) REFERENCES maintenance_runs(id) ON DELETE CASCADE not valid;

alter table "public"."maintenance_run_items" validate constraint "maintenance_run_items_run_id_fkey";

alter table "public"."matches" add constraint "chk_caramboles_nonneg" CHECK ((((caramboles_reptador IS NULL) OR (caramboles_reptador >= 0)) AND ((caramboles_reptat IS NULL) OR (caramboles_reptat >= 0)))) not valid;

alter table "public"."matches" validate constraint "chk_caramboles_nonneg";

alter table "public"."matches" add constraint "chk_entrades_nonneg" CHECK (((entrades IS NULL) OR (entrades >= 0))) not valid;

alter table "public"."matches" validate constraint "chk_entrades_nonneg";

alter table "public"."matches" add constraint "matches_caramboles_reptador_check" CHECK ((caramboles_reptador >= 0)) not valid;

alter table "public"."matches" validate constraint "matches_caramboles_reptador_check";

alter table "public"."matches" add constraint "matches_caramboles_reptat_check" CHECK ((caramboles_reptat >= 0)) not valid;

alter table "public"."matches" validate constraint "matches_caramboles_reptat_check";

alter table "public"."matches" add constraint "matches_challenge_id_fkey" FOREIGN KEY (challenge_id) REFERENCES challenges(id) ON DELETE CASCADE not valid;

alter table "public"."matches" validate constraint "matches_challenge_id_fkey";

alter table "public"."matches" add constraint "matches_entrades_check" CHECK ((entrades >= 0)) not valid;

alter table "public"."matches" validate constraint "matches_entrades_check";

alter table "public"."matches" add constraint "matches_tiebreak_scores_chk" CHECK ((((tiebreak = false) AND (tiebreak_reptador IS NULL) AND (tiebreak_reptat IS NULL)) OR ((tiebreak = true) AND (tiebreak_reptador IS NOT NULL) AND (tiebreak_reptat IS NOT NULL)))) not valid;

alter table "public"."matches" validate constraint "matches_tiebreak_scores_chk";

alter table "public"."notes" add constraint "notes_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."notes" validate constraint "notes_user_id_fkey";

alter table "public"."penalties" add constraint "penalties_challenge_id_fkey" FOREIGN KEY (challenge_id) REFERENCES challenges(id) not valid;

alter table "public"."penalties" validate constraint "penalties_challenge_id_fkey";

alter table "public"."penalties" add constraint "penalties_event_id_fkey" FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE not valid;

alter table "public"."penalties" validate constraint "penalties_event_id_fkey";

alter table "public"."penalties" add constraint "penalties_player_id_fkey" FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE not valid;

alter table "public"."penalties" validate constraint "penalties_player_id_fkey";

alter table "public"."player_weekly_positions" add constraint "player_weekly_positions_event_id_fkey" FOREIGN KEY (event_id) REFERENCES events(id) not valid;

alter table "public"."player_weekly_positions" validate constraint "player_weekly_positions_event_id_fkey";

alter table "public"."player_weekly_positions" add constraint "player_weekly_positions_player_id_fkey" FOREIGN KEY (player_id) REFERENCES players(id) not valid;

alter table "public"."player_weekly_positions" validate constraint "player_weekly_positions_player_id_fkey";

alter table "public"."players" add constraint "players_email_key" UNIQUE using index "players_email_key";

alter table "public"."players" add constraint "players_numero_soci_fkey" FOREIGN KEY (numero_soci) REFERENCES socis(numero_soci) not valid;

alter table "public"."players" validate constraint "players_numero_soci_fkey";

alter table "public"."ranking_positions" add constraint "ranking_positions_event_id_fkey" FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE not valid;

alter table "public"."ranking_positions" validate constraint "ranking_positions_event_id_fkey";

alter table "public"."ranking_positions" add constraint "ranking_positions_event_player_uk" UNIQUE using index "ranking_positions_event_player_uk" DEFERRABLE;

alter table "public"."ranking_positions" add constraint "ranking_positions_player_id_fkey" FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE RESTRICT not valid;

alter table "public"."ranking_positions" validate constraint "ranking_positions_player_id_fkey";

alter table "public"."ranking_positions" add constraint "ranking_positions_posicio_check" CHECK (((posicio >= 1) AND (posicio <= 20))) not valid;

alter table "public"."ranking_positions" validate constraint "ranking_positions_posicio_check";

alter table "public"."socis" add constraint "socis_email_key" UNIQUE using index "socis_email_key";

alter table "public"."waiting_list" add constraint "waiting_list_event_id_fkey" FOREIGN KEY (event_id) REFERENCES events(id) not valid;

alter table "public"."waiting_list" validate constraint "waiting_list_event_id_fkey";

alter table "public"."waiting_list" add constraint "waiting_list_event_player_uk" UNIQUE using index "waiting_list_event_player_uk";

alter table "public"."waiting_list" add constraint "waiting_list_player_id_fkey" FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE not valid;

alter table "public"."waiting_list" validate constraint "waiting_list_player_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public._admins_email_lowercase()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  new.email := lower(new.email);
  return new;
end$function$
;

CREATE OR REPLACE FUNCTION public._app_settings_set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  new.updated_at := now();
  return new;
end; $function$
;

CREATE OR REPLACE FUNCTION public._set_search_path()
 RETURNS void
 LANGUAGE sql
AS $function$
  select set_config('search_path','public', true);
$function$
;

CREATE OR REPLACE FUNCTION public.accept_challenge(_id uuid, _data timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  dies_accept smallint; dt_proposta timestamptz;
begin
  select dies_acceptar_repte into dies_accept from public.app_settings limit 1;
  select data_proposta into dt_proposta from public.challenges where id=_id;

  if now() > dt_proposta + make_interval(days => dies_accept) then
    update public.challenges set estat='expirat' where id=_id;
    raise exception 'Repte expirat per falta d’acceptació';
  end if;

  update public.challenges
     set estat='acceptat', data_acceptacio=now(),
         data_programada = coalesce(_data, data_programada)
   where id=_id and estat='proposat';
  if not found then raise exception 'Només es pot acceptar un repte proposat';
  end if;
end$function$
;

CREATE OR REPLACE FUNCTION public.admin_apply_disagreement(p_event uuid, p_player_a uuid, p_player_b uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  -- Revalidació interna si voleu (es pot mantenir per auditar correu)
  perform is_admin_by_email();
  if not found then
    raise exception 'No ets admin';
  end if;

  perform apply_disagreement_drop(p_event, p_player_a, p_player_b);
end$function$
;

CREATE OR REPLACE FUNCTION public.admin_apply_no_show(p_challenge uuid, p_no_show_player uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  if not public.is_admin_by_email() then
    raise exception 'No ets admin';
  end if;

  perform public.apply_no_show_win(p_challenge, p_no_show_player);
end
$function$
;

CREATE OR REPLACE FUNCTION public.admin_run_all_sweeps()
 RETURNS TABLE(kind text, payload jsonb)
 LANGUAGE plpgsql
AS $function$
begin
  -- Sweep de reptes fora de termini (llegeix app_settings)
  return query
  select 'challenges_overdue'::text,
         coalesce(json_agg(row_to_json(t)), '[]'::json)::jsonb
  from public.sweep_overdue_challenges_from_settings_mvp2() as t;

  -- Sweep d’inactivitat
  return query
  select 'inactivity'::text,
         coalesce(json_agg(row_to_json(t)), '[]'::json)::jsonb
  from public.sweep_inactivity_from_settings() as t;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_run_maintenance()
 RETURNS TABLE(kind text, payload jsonb)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  -- Sweeps de reptes (terminis)
  return query
  select 'challenges_overdue',
         coalesce(json_agg(row_to_json(t)), '[]'::json)::jsonb
  from public.sweep_overdue_challenges_from_settings_mvp2() as t;

  -- Sweep d’inactivitat
  return query
  select 'inactivity',
         coalesce(json_agg(row_to_json(t)), '[]'::json)::jsonb
  from public.sweep_inactivity_from_settings() as t;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_run_maintenance_and_log(p_triggered_by text DEFAULT 'auto'::text)
 RETURNS TABLE(kind text, payload jsonb)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_run_id uuid;
  v_any_rows boolean := false;
  r record;
begin
  -- Obrir capçalera de l'execució
  insert into public.maintenance_runs(triggered_by)
  values (coalesce(p_triggered_by,'auto'))
  returning id into v_run_id;

  -- Executar el manteniment existent i desar cada bloc de resultats
  for r in
    select * from public.admin_run_maintenance()
  loop
    v_any_rows := true;

    insert into public.maintenance_run_items(run_id, kind, payload)
    values (v_run_id, r.kind, r.payload);

    -- Tornar també el resultat cap a fora
    kind := r.kind;
    payload := r.payload;
    return next;
  end loop;

  -- Tancar capçalera amb èxit
  update public.maintenance_runs
     set finished_at = now(),
         ok = true,
         notes = case when v_any_rows then null else 'Sense canvis' end
   where id = v_run_id;

exception when others then
  -- Registrar error i propagar-lo
  update public.maintenance_runs
     set finished_at = now(),
         ok = false,
         notes = coalesce(notes,'') || case when coalesce(notes,'')<>'' then E'\n' end
                 || 'ERROR: ' || sqlstate || ' - ' || sqlerrm
   where id = v_run_id;
  raise;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_update_challenge_state(p_challenge uuid, p_new_state challenge_state)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  if not public.is_admin_by_email() then
    raise exception 'No ets admin';
  end if;

  if p_new_state not in ('acceptat','refusat','anullat','caducat') then
    raise exception 'Estat no permès per admin_update_challenge_state';
  end if;

  update public.challenges
  set estat = p_new_state
  where id = p_challenge;
end
$function$
;

CREATE OR REPLACE FUNCTION public.admin_update_settings(p_dies_acceptar smallint, p_dies_jugar smallint, p_pre_inact smallint, p_inact smallint)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
  update public.app_settings
     set dies_acceptar_repte         = p_dies_acceptar,
         dies_jugar_despres_acceptar = p_dies_jugar,
         pre_inactiu_setmanes        = p_pre_inact,
         inactiu_setmanes            = p_inact,
         updated_at                  = now()
   where id = (
     select id from public.app_settings
     order by updated_at desc
     limit 1
   );
$function$
;

CREATE OR REPLACE FUNCTION public.apply_challenge_penalty(p_challenge uuid, p_tipus text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_event   uuid;
  v_reptador uuid;
  v_reptat  uuid;
  v_pos_r   INTEGER;
  v_pos_t   INTEGER;
  v_swap    uuid;
  v_next    uuid;
  v_pos     INTEGER;
BEGIN
  SELECT event_id, reptador_id, reptat_id, pos_reptador, pos_reptat
    INTO v_event, v_reptador, v_reptat, v_pos_r, v_pos_t
    FROM challenges
   WHERE id = p_challenge;

  IF v_event IS NULL THEN
    RETURN json_build_object('ok', FALSE, 'error', 'challenge_not_found');
  END IF;

  IF p_tipus = 'incompareixenca' THEN
    UPDATE challenges SET estat = 'refusat' WHERE id = p_challenge;

    INSERT INTO penalties(event_id, challenge_id, player_id, tipus)
    VALUES (v_event, p_challenge, v_reptat, p_tipus);

    IF v_pos_r IS NOT NULL
       AND v_pos_t IS NOT NULL
       AND v_pos_r <> v_pos_t THEN
      UPDATE ranking_positions
         SET posicio = CASE
            WHEN player_id = v_reptador THEN v_pos_t
            WHEN player_id = v_reptat   THEN v_pos_r
            ELSE posicio
         END
       WHERE event_id = v_event
         AND player_id IN (v_reptador, v_reptat);

      INSERT INTO history_position_changes(
        event_id, player_id, posicio_anterior, posicio_nova,
        motiu, ref_challenge
      )
      VALUES
        (v_event, v_reptador, v_pos_r, v_pos_t,
         'victoria per incompareixença', p_challenge),
        (v_event, v_reptat,   v_pos_t, v_pos_r,
         'derrota per incompareixença', p_challenge);
    END IF;

    RETURN json_build_object('ok', TRUE);

  ELSIF p_tipus = 'desacord_dates' THEN
    FOR v_swap IN
      SELECT player_id
        FROM ranking_positions
       WHERE event_id = v_event
         AND player_id IN (v_reptador, v_reptat)
       ORDER BY posicio
    LOOP
      SELECT posicio INTO v_pos
        FROM ranking_positions
       WHERE event_id = v_event AND player_id = v_swap;

      SELECT player_id INTO v_next
        FROM ranking_positions
       WHERE event_id = v_event AND posicio = v_pos + 1;

      IF v_next IS NOT NULL THEN
        UPDATE ranking_positions
           SET posicio = v_pos + 1
         WHERE event_id = v_event AND player_id = v_swap;

        UPDATE ranking_positions
           SET posicio = v_pos
         WHERE event_id = v_event AND player_id = v_next;

        INSERT INTO history_position_changes(
          event_id, player_id, posicio_anterior, posicio_nova,
          motiu, ref_challenge
        )
        VALUES
          (v_event, v_swap, v_pos, v_pos + 1,
           'penalització desacord dates', p_challenge),
          (v_event, v_next, v_pos + 1, v_pos,
           'puja per penalització', p_challenge);
      END IF;

      INSERT INTO penalties(event_id, challenge_id, player_id, tipus)
      VALUES (v_event, p_challenge, v_swap, p_tipus);
    END LOOP;

    UPDATE challenges SET estat = 'anullat' WHERE id = p_challenge;
    RETURN json_build_object('ok', TRUE);

  ELSE
    RETURN json_build_object('ok', FALSE, 'error', 'tipus_not_supported');
  END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.apply_disagreement_drop(p_event uuid, p_player_a uuid, p_player_b uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  pos_a int;
  pos_b int;
  min_pos int;
  max_pos int;
  next_exists boolean;
begin
  -- Posicions actuals dins l'event
  select posicio into pos_a from ranking_positions
   where event_id = p_event and player_id = p_player_a;
  select posicio into pos_b from ranking_positions
   where event_id = p_event and player_id = p_player_b;

  if pos_a is null or pos_b is null then
    raise exception 'Cal que ambdós estiguin al rànquing per aplicar la penalització';
  end if;

  min_pos := least(pos_a, pos_b);
  max_pos := greatest(pos_a, pos_b);

  -- Ha d'existir algú just darrere del pitjor classificat
  select exists (
    select 1 from ranking_positions
    where event_id = p_event and posicio = max_pos + 1
  ) into next_exists;

  if not next_exists then
    raise exception 'No es pot aplicar la penalització: no hi ha cap jugador darrere de la posició %.', max_pos;
  end if;

  -- Diferim claus per evitar col·lisions transitòries (el CHECK segueix actiu)
  set constraints ranking_positions_pkey deferred;
  set constraints ranking_positions_event_player_uk deferred;

  -- Recol·locació en una sola passada i sempre dins del rang 1..N:
  --  - el "següent" (max+1) puja a min_pos
  --  - el tram [min..max] baixa 1 posició
  with affected as (
    select event_id,
           posicio,
           case
             when posicio = max_pos + 1 then min_pos
             when posicio between min_pos and max_pos then posicio + 1
             else posicio
           end as new_pos
    from ranking_positions
    where event_id = p_event
      and (posicio between min_pos and max_pos or posicio = max_pos + 1)
  )
  update ranking_positions rp
     set posicio     = a.new_pos,
         assignat_el = now()
    from affected a
   where rp.event_id = a.event_id
     and rp.posicio  = a.posicio;

  -- Log (si existeix la taula)
  if exists (select 1 from information_schema.tables
             where table_schema='public' and table_name='penalties') then
    insert into penalties(event_id, player_id, tipus, detalls)
    values
      (p_event, p_player_a, 'desacord_dates', 'Pèrdua d’una posició per desacord en dates'),
      (p_event, p_player_b, 'desacord_dates', 'Pèrdua d’una posició per desacord en dates');
  end if;
end$function$
;

CREATE OR REPLACE FUNCTION public.apply_match_result(p_challenge uuid)
 RETURNS record
 LANGUAGE plpgsql
 STABLE
AS $function$
declare
  v_event uuid;
  v_reptador uuid;
  v_reptat uuid;
  v_pos_r smallint;
  v_pos_t smallint;
  v_result text;
begin
  -- Dades bàsiques del repte
  select c.event_id, c.reptador_id, c.reptat_id, c.pos_reptador, c.pos_reptat
    into v_event, v_reptador, v_reptat, v_pos_r, v_pos_t
  from challenges c
  where c.id = p_challenge;

  if v_event is null then
    return (false, 'challenge_not_found');
  end if;

  -- Darrer resultat registrat del partit vinculat
  select m.resultat::text
    into v_result
  from matches m
  where m.challenge_id = p_challenge
  order by m.creat_el desc
  limit 1;

  if v_result is null then
    return (false, 'match_not_found');
  end if;

  if v_pos_r is null or v_pos_t is null or v_pos_r = v_pos_t then
    return (false, 'positions_missing_or_equal');
  end if;

  -- Només hi ha intercanvi si guanya el reptador
  if v_result = 'reptador' then
    update ranking_positions rp
       set posicio = case
                       when rp.player_id = v_reptador then v_pos_t
                       when rp.player_id = v_reptat   then v_pos_r
                       else rp.posicio
                     end
     where rp.event_id = v_event
       and rp.player_id in (v_reptador, v_reptat);

    insert into history_position_changes(
      event_id, player_id, posicio_anterior, posicio_nova, motiu, ref_challenge
    )
    values
      (v_event, v_reptador, v_pos_r, v_pos_t, 'victòria repte', p_challenge),
      (v_event, v_reptat,   v_pos_t, v_pos_r, 'derrota repte',  p_challenge);
  end if;

  return (true, null::text);
end$function$
;

CREATE OR REPLACE FUNCTION public.apply_no_show_win(p_challenge uuid, p_quies_no_show uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
declare
  c record;
  guanyador uuid;
  perdedor uuid;
  motiu text;
begin
  select * into c from public.challenges where id=p_challenge;
  if c is null then raise exception 'Repte inexistent'; end if;

  if p_quies_no_show = c.reptat_id then
    guanyador := c.reptador_id; perdedor := c.reptat_id;
    motiu := 'Incompareixença del reptat';
  elsif p_quies_no_show = c.reptador_id then
    -- (no definit explícitament a la normativa, però assumim simetria)
    guanyador := c.reptat_id; perdedor := c.reptador_id;
    motiu := 'Incompareixença del reptador';
  else
    raise exception 'El jugador indicat no forma part del repte';
  end if;

  -- registrar penalització
  insert into public.penalties(event_id, player_id, tipus, detalls)
  values (c.event_id, p_quies_no_show, 'incompareixenca', motiu);

  -- si guanya el reptador (cas normatiu), intercanvi directe
  if guanyador = c.reptador_id then
    perform public.swap_positions(c.event_id, c.reptador_id, c.reptat_id, 'Victòria per incompareixença', c.id);
  end if;

  update public.challenges set estat='anullat' where id=p_challenge;
end $function$
;

CREATE OR REPLACE FUNCTION public.apply_voluntary_drop(p_event uuid, p_player uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  b RECORD;
  v_pos  INTEGER;
  v_wait uuid;
BEGIN
  SELECT posicio INTO v_pos
    FROM ranking_positions
   WHERE event_id = p_event AND player_id = p_player;

  IF v_pos IS NULL THEN
    RETURN;
  END IF;

  DELETE FROM ranking_positions
   WHERE event_id = p_event AND player_id = p_player;

  INSERT INTO history_position_changes(
    event_id, player_id, posicio_anterior, posicio_nova,
    motiu, ref_challenge
  )
  VALUES (p_event, p_player, v_pos, NULL, 'baixa', NULL);

  FOR b IN
    SELECT player_id, posicio
      FROM ranking_positions
     WHERE event_id = p_event AND posicio > v_pos
     ORDER BY posicio
  LOOP
    UPDATE ranking_positions
       SET posicio = b.posicio - 1
     WHERE event_id = p_event AND player_id = b.player_id;

    INSERT INTO history_position_changes(
      event_id, player_id, posicio_anterior, posicio_nova,
      motiu, ref_challenge
    )
    VALUES (
      p_event,
      b.player_id,
      b.posicio,
      b.posicio - 1,
      'puja per baixa',
      NULL
    );
  END LOOP;

  SELECT player_id INTO v_wait
    FROM waiting_list
   WHERE event_id = p_event
   ORDER BY ordre
   LIMIT 1;

  IF v_wait IS NOT NULL THEN
    INSERT INTO ranking_positions(event_id, player_id, posicio)
    VALUES (p_event, v_wait, 20);

    DELETE FROM waiting_list
      WHERE event_id = p_event AND player_id = v_wait;

    INSERT INTO history_position_changes(
      event_id, player_id, posicio_anterior, posicio_nova,
      motiu, ref_challenge
    )
    VALUES (p_event, v_wait, NULL, 20, 'entra per baixa', NULL);
  END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.apply_voluntary_leave(p_player_id uuid, p_event_id uuid)
 RETURNS TABLE(ok boolean, reason text)
 LANGUAGE plpgsql
AS $function$
declare
  v_pos smallint;
  v_first_waiting uuid;
begin
  select posicio into v_pos
  from public.ranking_positions
  where event_id = p_event_id and player_id = p_player_id;

  if v_pos is null then
    ok := false; reason := 'jugador no trobat al rànquing'; return next; return;
  end if;

  -- elimina del rànquing
  delete from public.ranking_positions
   where event_id = p_event_id and player_id = p_player_id;

  -- promou primer de la waiting list
  select player_id into v_first_waiting
  from public.waiting_list
  where event_id = p_event_id
  order by ordre asc
  limit 1;

  if v_first_waiting is not null then
    insert into public.ranking_positions (event_id, posicio, player_id, assignat_el)
    values (p_event_id, 20, v_first_waiting, now());

    delete from public.waiting_list
     where event_id = p_event_id and player_id = v_first_waiting;

    insert into public.history_position_changes
      (event_id, player_id, posicio_anterior, posicio_nova, motiu, ref_challenge)
    values
      (p_event_id, v_first_waiting, null, 20, 'baixa voluntària: entra des de waiting list', null);
  end if;

  ok := true;
  reason := format('Jugador %s baixa voluntària; promogut %s', p_player_id, coalesce(v_first_waiting::text,'cap'));
  return next;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.can_create_challenge(p_event uuid, p_reptador uuid, p_reptat uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
AS $function$
declare
  v_max_gap integer;
  v_cd_min integer;
  v_cd_max integer;
  v_pos_reptador integer;
  v_pos_reptat integer;
  v_last timestamp with time zone;
  v_days integer;
begin
  select coalesce(max_rank_gap, 2),
         coalesce(cooldown_min_dies, 7),
         cooldown_max_dies
    into v_max_gap, v_cd_min, v_cd_max
    from app_settings
   order by updated_at desc limit 1;

  if p_reptador = p_reptat then
    return false;
  end if;

  if not exists (select 1 from events where id = p_event and actiu) then
    return false;
  end if;

  if not exists (select 1 from players where id = p_reptador and estat='actiu') then
    return false;
  end if;
  if not exists (select 1 from players where id = p_reptat and estat='actiu') then
    return false;
  end if;

  select posicio into v_pos_reptador
    from ranking_positions where event_id=p_event and player_id=p_reptador;
  select posicio into v_pos_reptat
    from ranking_positions where event_id=p_event and player_id=p_reptat;

  if v_pos_reptador is null or v_pos_reptat is null then
    return false;
  end if;

  if abs(v_pos_reptador - v_pos_reptat) > v_max_gap then
    return false;
  end if;

  if exists (
    select 1 from challenges
     where event_id=p_event
       and estat in ('proposat','acceptat','programat')
       and (reptador_id in (p_reptador,p_reptat) or reptat_id in (p_reptador,p_reptat))
  ) then
    return false;
  end if;

  select max(coalesce(data_joc,data_acceptacio,data_proposta))
    into v_last
    from challenges
   where event_id=p_event
     and ((reptador_id=p_reptador and reptat_id=p_reptat) or
          (reptador_id=p_reptat and reptat_id=p_reptador))
     and estat not in ('proposat','acceptat','programat');

  if v_last is not null then
    v_days := (now()::date - v_last::date);
    if v_days < v_cd_min then
      return false;
    end if;
    if v_cd_max is not null and v_days > v_cd_max then
      return false;
    end if;
  end if;

  return true;
end$function$
;

CREATE OR REPLACE FUNCTION public.can_create_challenge_detail(p_event uuid, p_reptador uuid, p_reptat uuid)
 RETURNS json
 LANGUAGE plpgsql
 STABLE
AS $function$
declare
  v_max_gap integer;
  v_cd_min integer;
  v_cd_max integer;
  v_pos_reptador integer;
  v_pos_reptat integer;
  v_last timestamp with time zone;
  v_days integer;
begin
  select coalesce(max_rank_gap, 2),
         coalesce(cooldown_min_dies, 7),
         cooldown_max_dies
    into v_max_gap, v_cd_min, v_cd_max
    from app_settings
   order by updated_at desc limit 1;

  if p_reptador = p_reptat then
    return json_build_object('ok',false,'reason','No et pots reptar a tu mateix');
  end if;

  if not exists (select 1 from events where id = p_event and actiu) then
    return json_build_object('ok',false,'reason','Event inactiu');
  end if;

  if not exists (select 1 from players where id = p_reptador and estat='actiu') then
    return json_build_object('ok',false,'reason','Reptador inactiu');
  end if;
  if not exists (select 1 from players where id = p_reptat and estat='actiu') then
    return json_build_object('ok',false,'reason','Reptat inactiu');
  end if;

  select posicio into v_pos_reptador
    from ranking_positions where event_id=p_event and player_id=p_reptador;
  select posicio into v_pos_reptat
    from ranking_positions where event_id=p_event and player_id=p_reptat;

  if v_pos_reptador is null then
    return json_build_object('ok',false,'reason','El reptador no és al rànquing');
  end if;
  if v_pos_reptat is null then
    return json_build_object('ok',false,'reason','El reptat no és al rànquing');
  end if;

  if abs(v_pos_reptador - v_pos_reptat) > v_max_gap then
    return json_build_object('ok',false,'reason','Diferència de posicions massa gran');
  end if;

  if exists (
    select 1 from challenges
     where event_id=p_event
       and estat in ('proposat','acceptat','programat')
       and (reptador_id in (p_reptador,p_reptat) or reptat_id in (p_reptador,p_reptat))
  ) then
    return json_build_object('ok',false,'reason','Ja hi ha un repte actiu');
  end if;

  select max(coalesce(data_joc,data_acceptacio,data_proposta))
    into v_last
    from challenges
   where event_id=p_event
     and ((reptador_id=p_reptador and reptat_id=p_reptat) or
          (reptador_id=p_reptat and reptat_id=p_reptador))
     and estat not in ('proposat','acceptat','programat');

  if v_last is not null then
    v_days := (now()::date - v_last::date);
    if v_days < v_cd_min then
      return json_build_object('ok',false,'reason','Temps mínim entre reptes no complert');
    end if;
    if v_cd_max is not null and v_days > v_cd_max then
      return json_build_object('ok',false,'reason','Temps màxim entre reptes excedit');
    end if;
  end if;

  return json_build_object('ok',true,'reason',null);
end$function$
;

CREATE OR REPLACE FUNCTION public.capture_initial_ranking(p_event uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform capture_weekly_ranking(p_event);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.capture_weekly_ranking(p_event uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_event uuid;
  v_week integer;
begin
  if p_event is null then
    select id into v_event from events where actiu is true limit 1;
  else
    v_event := p_event;
  end if;

  select coalesce(max(setmana), 0) + 1 into v_week
    from player_weekly_positions
    where event_id = v_event;

  insert into player_weekly_positions(event_id, player_id, setmana, posicio)
  select rp.event_id, rp.player_id, v_week, rp.posicio
    from ranking_positions rp
    where rp.event_id = v_event;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.create_challenge(_reptador uuid, _reptat uuid, _tipus challenge_type)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  _event_id uuid;
  pos_r smallint; pos_t smallint;
  cooldown_min int; cooldown_max int;
begin
  select id into _event_id from public.events where actiu limit 1;
  if _event_id is null then raise exception 'No active event';
  end if;

  -- Un repte actiu per jugador
  if exists (select 1 from public.challenges
             where estat in ('proposat','acceptat') and (reptador_id=_reptador or reptat_id=_reptador))
  then raise exception 'El reptador ja té un repte actiu';
  end if;
  if exists (select 1 from public.challenges
             where estat in ('proposat','acceptat') and (reptador_id=_reptat or reptat_id=_reptat))
  then raise exception 'El reptat ja té un repte actiu';
  end if;

  -- Posicions actuals
  select posicio into pos_r from public.ranking_positions where event_id=_event_id and player_id=_reptador;
  select posicio into pos_t from public.ranking_positions where event_id=_event_id and player_id=_reptat;

  if _tipus='normal' then
    if pos_r is null or pos_t is null then
      raise exception 'Repte normal requereix que ambdós siguin al rànquing';
    end if;
    if abs(pos_t - pos_r) > 2 then
      raise exception 'Només pots reptar fins a 2 posicions amunt/avall';
    end if;
  end if;

  -- cool-down
  select cooldown_min_dies, cooldown_max_dies into cooldown_min, cooldown_max from public.app_settings limit 1;
  if exists (
     select 1 from public.challenges c
     join public.matches m on m.challenge_id=c.id
     where (c.reptador_id=_reptador or c.reptat_id=_reptador)
       and m.data_joc >= now() - make_interval(days => cooldown_min)
  ) then
     raise exception 'Cal respectar el cooldown mínim de % dies', cooldown_min;
  end if;

  insert into public.challenges(event_id, tipus, reptador_id, reptat_id, estat,
                                dates_proposades, pos_reptador, pos_reptat)
  values (_event_id, _tipus, _reptador, _reptat, 'proposat', '{}', pos_r, pos_t)
  returning id into _event_id;
  return _event_id;
end$function$
;

CREATE OR REPLACE FUNCTION public.current_player_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE
AS $function$
  select p.id
  from public.players p
  where p.email = (auth.jwt() ->> 'email')
  limit 1
$function$
;

CREATE OR REPLACE FUNCTION public.enforce_max_rank_gap()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
  gap smallint;
  s_max smallint;
BEGIN
  SELECT max_rank_gap INTO s_max
  FROM public.app_settings
  ORDER BY updated_at DESC
  LIMIT 1;

  -- obtenim posicions actuals
  WITH rp AS (
    SELECT player_id, posicio
    FROM public.ranking_positions
    WHERE event_id = NEW.event_id
  )
  SELECT (rpr.posicio - rpt.posicio) INTO gap
  FROM rp rpr
  JOIN rp rpt ON rpr.player_id = NEW.reptat_id AND rpt.player_id = NEW.reptador_id;

  IF gap IS NULL THEN
    RAISE EXCEPTION 'No es troben les posicions de reptador/reptat per a l''event %', NEW.event_id;
  END IF;

  IF gap > s_max THEN
    RAISE EXCEPTION 'No pots reptar més de % posicions per sobre (gap=%)', s_max, gap;
  END IF;

  RETURN NEW;
END $function$
;

CREATE OR REPLACE FUNCTION public.fn_challenges_set_positions()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF NEW.pos_reptador IS NULL THEN
    SELECT posicio INTO NEW.pos_reptador
    FROM ranking_positions
    WHERE event_id = NEW.event_id AND player_id = NEW.reptador_id;
  END IF;

  IF NEW.pos_reptat IS NULL THEN
    SELECT posicio INTO NEW.pos_reptat
    FROM ranking_positions
    WHERE event_id = NEW.event_id AND player_id = NEW.reptat_id;
  END IF;

  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.fn_matches_finalize()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  UPDATE challenges
     SET estat = 'jugat'
   WHERE id = NEW.challenge_id;

  UPDATE players
     SET data_ultim_repte = NEW.data_joc::date
   WHERE id IN (
       SELECT reptador_id FROM challenges WHERE id = NEW.challenge_id
       UNION
       SELECT reptat_id   FROM challenges WHERE id = NEW.challenge_id
   );

  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_active_event()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select id from public.events where actiu = true limit 1
$function$
;

CREATE OR REPLACE FUNCTION public.get_active_event_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select id
  from public.events
  where actiu = true
  order by creat_el desc
  limit 1
$function$
;

CREATE OR REPLACE FUNCTION public.get_posicio(p_event uuid, p_player uuid)
 RETURNS integer
 LANGUAGE sql
 STABLE
AS $function$
  select rp.posicio
  from public.ranking_positions rp
  where rp.event_id = p_event and rp.player_id = p_player
$function$
;

CREATE OR REPLACE FUNCTION public.get_ranking()
 RETURNS TABLE(posicio smallint, player_id uuid, nom text)
 LANGUAGE sql
AS $function$
  SELECT rp.posicio, rp.player_id, p.nom
  FROM ranking_positions rp
  JOIN players p ON p.id = rp.player_id
  ORDER BY rp.posicio
$function$
;

CREATE OR REPLACE FUNCTION public.get_settings()
 RETURNS app_settings
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select *
  from public.app_settings
  order by updated_at desc
  limit 1
$function$
;

CREATE OR REPLACE FUNCTION public.get_waiting_list()
 RETURNS TABLE(ordre integer, player_id uuid, nom text)
 LANGUAGE sql
AS $function$
  SELECT wl.ordre, wl.player_id, p.nom
  FROM waiting_list wl
  JOIN players p ON p.id = wl.player_id
  ORDER BY wl.ordre
$function$
;

CREATE OR REPLACE FUNCTION public.guard_unique_membership()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
declare
  v_event uuid;
  v_player uuid;
  v_table text := tg_table_name;
begin
  if v_table = 'waiting_list' then
    v_event := new.event_id; v_player := new.player_id;
    if exists(select 1 from public.ranking_positions where event_id=v_event and player_id=v_player) then
      raise exception 'Jugador % ja és al rànquing de l''event %', v_player, v_event;
    end if;
  elsif v_table = 'ranking_positions' then
    v_event := new.event_id; v_player := new.player_id;
    if exists(select 1 from public.waiting_list where event_id=v_event and player_id=v_player) then
      raise exception 'Jugador % ja és a la llista d''espera de l''event %', v_player, v_event;
    end if;
  end if;
  return new;
end
$function$
;

CREATE OR REPLACE FUNCTION public.is_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE
AS $function$
  select coalesce((auth.jwt() ->> 'role') = 'admin', false)
$function$
;

CREATE OR REPLACE FUNCTION public.is_admin(p_email text)
 RETURNS boolean
 LANGUAGE sql
AS $function$
  SELECT EXISTS(SELECT 1 FROM admins WHERE email = lower(p_email))
$function$
;

CREATE OR REPLACE FUNCTION public.is_admin_by_email()
 RETURNS boolean
 LANGUAGE sql
 STABLE
AS $function$
  select exists (
    select 1
    from public.admins a
    where a.email = (auth.jwt() ->> 'email')
  )
$function$
;

CREATE OR REPLACE FUNCTION public.list_eligible_opponents(p_player uuid)
 RETURNS TABLE(player_id uuid, nom text, posicio smallint)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with active_event as (
    select id from public.events
    where actiu = true
    order by creat_el desc
    limit 1
  ),
  my_pos as (
    select rp.posicio
    from public.ranking_positions rp, active_event e
    where rp.event_id = e.id and rp.player_id = p_player
    limit 1
  ),
  busy as (
    select reptador_id as pid from public.challenges
      where estat in ('proposat','acceptat','programat')
    union
    select reptat_id from public.challenges
      where estat in ('proposat','acceptat','programat')
  )
  select rp.player_id, pl.nom, rp.posicio
  from public.ranking_positions rp
  join public.players pl on pl.id = rp.player_id
  join active_event e on e.id = rp.event_id
  join my_pos mp on true
  where rp.player_id <> p_player
    and rp.posicio between greatest(mp.posicio - 2, 1) and (mp.posicio - 1)
    and rp.player_id not in (select pid from busy)
  order by rp.posicio asc;
$function$
;

CREATE OR REPLACE FUNCTION public.penalitza_incompareixenca(p_challenge uuid, p_quem_guanya text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  chal record;
  win_result public.match_result;
  m_id uuid;
begin
  select * into chal from public.challenges where id = p_challenge;
  if not found then
    return json_build_object('ok', false, 'error', 'Repte inexistent');
  end if;

  if p_quem_guanya not in ('reptador','reptat') then
    return json_build_object('ok', false, 'error', 'Paràmetre guanyador invàlid');
  end if;

  win_result := case
    when p_quem_guanya = 'reptador' then 'guanya_reptador'
    else 'guanya_reptat'
  end;

  insert into public.matches (challenge_id, data_joc, caramboles_reptador, caramboles_reptat, entrades, resultat)
  values (p_challenge, now(), 0, 0, 0, win_result)
  returning id into m_id;

  insert into public.penalties (event_id, player_id, tipus, detalls)
  values (chal.event_id,
          case when p_quem_guanya='reptador' then chal.reptat_id else chal.reptador_id end,
          'incompareixenca',
          'Derrota per incompareixença');

  update public.challenges set estat='jugat' where id = p_challenge;

  perform public.apply_match_result(p_challenge);

  return json_build_object('ok', true, 'match_id', m_id);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.penalitza_no_acord_dates(p_challenge uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  chal record;
  e uuid;
  pos_rep int;
  pos_rat int;
begin
  select * into chal from public.challenges where id = p_challenge;
  if not found then
    return json_build_object('ok', false, 'error', 'Repte inexistent');
  end if;

  e := chal.event_id;
  select posicio into pos_rep from public.ranking_positions where event_id=e and player_id=chal.reptador_id;
  select posicio into pos_rat from public.ranking_positions where event_id=e and player_id=chal.reptat_id;

  if pos_rep is null or pos_rat is null then
    return json_build_object('ok', false, 'error', 'Jugadors no són al rànquing');
  end if;

  -- baixa reptador si no és 20
  if pos_rep < 20 then
    update public.ranking_positions
    set posicio = posicio + 1
    where event_id=e and posicio = pos_rep + 1;

    update public.ranking_positions
    set posicio = posicio + 1
    where event_id=e and player_id = chal.reptador_id;

    insert into public.history_position_changes(event_id, player_id, posicio_anterior, posicio_nova, motiu, ref_challenge)
    values (e, chal.reptador_id, pos_rep, pos_rep+1, 'No acord de dates', p_challenge);
  end if;

  -- baixa reptat si no és 20
  if pos_rat < 20 then
    update public.ranking_positions
    set posicio = posicio + 1
    where event_id=e and posicio = pos_rat + 1;

    update public.ranking_positions
    set posicio = posicio + 1
    where event_id=e and player_id = chal.reptat_id;

    insert into public.history_position_changes(event_id, player_id, posicio_anterior, posicio_nova, motiu, ref_challenge)
    values (e, chal.reptat_id, pos_rat, pos_rat+1, 'No acord de dates', p_challenge);
  end if;

  update public.challenges set estat='anullat' where id=p_challenge;

  return json_build_object('ok', true);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.penalize_unprogrammed_after_accept(p_challenge_id uuid)
 RETURNS TABLE(ok boolean, reason text)
 LANGUAGE plpgsql
AS $function$
declare
  v_event uuid;
  v_reptador uuid;
  v_reptat uuid;
  v_estat text;
  v_prog timestamptz;

  v_pos_reptador smallint;
  v_pos_reptat smallint;
  v_min smallint;
  v_max smallint;
  v_next_player uuid;
  v_exists_next boolean;
begin
  -- Llegeix el repte
  select c.event_id, c.reptador_id, c.reptat_id, c.estat::text, c.data_programada
    into v_event, v_reptador, v_reptat, v_estat, v_prog
  from public.challenges c
  where c.id = p_challenge_id;

  if v_event is null then
    ok := false; reason := 'repte inexistent'; return next; return;
  end if;

  -- Només té sentit en reptes acceptats sense programació
  if not (v_estat = 'acceptat' and v_prog is null) then
    ok := false; reason := 'no és estat acceptat sense data'; return next; return;
  end if;

  -- Posicions actuals dels dos jugadors
  select posicio into v_pos_reptador
  from public.ranking_positions
  where event_id = v_event and player_id = v_reptador;

  select posicio into v_pos_reptat
  from public.ranking_positions
  where event_id = v_event and player_id = v_reptat;

  if v_pos_reptador is null or v_pos_reptat is null then
    ok := false; reason := 'jugadors fora del rànquing'; return next; return;
  end if;

  v_min := least(v_pos_reptador, v_pos_reptat);
  v_max := greatest(v_pos_reptador, v_pos_reptat);

  -- Busca el jugador just a sota del bloc (posició v_max+1) si existeix
  select player_id into v_next_player
  from public.ranking_positions
  where event_id = v_event and posicio = v_max + 1;

  v_exists_next := found;

  -- Promoció del següent (si n'hi ha): moure'l a v_min
  if v_exists_next then
    -- posa'l temporalment a -1 per no xocar
    update public.ranking_positions
       set posicio = -1
     where event_id = v_event and player_id = v_next_player;
  end if;

  -- Baixada del bloc [v_min..v_max] → posicio+1
  update public.ranking_positions
     set posicio = posicio + 1
   where event_id = v_event
     and posicio between v_min and v_max;

  -- Col·loca el "next" a la posició v_min (si existeix)
  if v_exists_next then
    update public.ranking_positions
       set posicio = v_min
     where event_id = v_event and player_id = v_next_player;
  end if;

  -- Històric: registrem els dos jugadors (i el promogut si n'hi ha)
  insert into public.history_position_changes
    (event_id, player_id, posicio_anterior, posicio_nova, motiu, ref_challenge)
  values
    (v_event, v_reptador, v_pos_reptador, v_pos_reptador + 1, 'desacord de dates (baixa 1)', p_challenge_id),
    (v_event, v_reptat,   v_pos_reptat,   v_pos_reptat   + 1, 'desacord de dates (baixa 1)', p_challenge_id);

  if v_exists_next then
    insert into public.history_position_changes
      (event_id, player_id, posicio_anterior, posicio_nova, motiu, ref_challenge)
    values
      (v_event, v_next_player, v_max + 1, v_min, 'desacord de dates (promoció del següent)', p_challenge_id);
  end if;

  -- Marca el repte com anul·lat per desacord de dates
  update public.challenges
     set estat = 'anullat',
         observacions = coalesce(observacions,'') || case when coalesce(observacions,'') <> '' then E'\n' else '' end
                        || 'Tancat per desacord de dates: baixada de bloc aplicada'
   where id = p_challenge_id;

  if v_exists_next then
    ok := true; reason := format('bloc [%s..%s] baixa 1; %s puja a %s', v_min, v_max, v_next_player, v_min);
  else
    ok := true; reason := format('bloc [%s..%s] baixa 1; no hi ha següent per promocionar', v_min, v_max);
  end if;
  return next;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.player_te_repte_actiu(p_event uuid, p_player uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.challenges c
    where c.event_id = p_event
      and c.estat in ('proposat','acceptat','programat')
      and (c.reptador_id = p_player or c.reptat_id = p_player)
  )
$function$
;

CREATE OR REPLACE FUNCTION public.posicio_actual(p_event uuid, p_player uuid)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select posicio
  from public.ranking_positions
  where event_id = p_event and player_id = p_player
$function$
;

CREATE OR REPLACE FUNCTION public.process_refusal_or_timeout(p_challenge_id uuid)
 RETURNS TABLE(ok boolean, reason text)
 LANGUAGE plpgsql
AS $function$
declare
  v_event uuid;
  v_reptador uuid;
  v_reptat uuid;
  v_estat text;
  v_pos_reptador smallint;
  v_pos_reptat smallint;
begin
  -- Llegeix el repte
  select c.event_id, c.reptador_id, c.reptat_id, c.estat::text
    into v_event, v_reptador, v_reptat, v_estat
  from public.challenges c
  where c.id = p_challenge_id;

  if v_event is null then
    ok := false; reason := 'repte inexistent'; return next; return;
  end if;

  -- Només té sentit en reptes "proposats" (no resposta/refús)
  if v_estat <> 'proposat' then
    ok := false; reason := 'el repte no és en estat proposat'; return next; return;
  end if;

  -- Llegeix posicions actuals al rànquing
  select posicio into v_pos_reptador
  from public.ranking_positions
  where event_id = v_event and player_id = v_reptador;

  select posicio into v_pos_reptat
  from public.ranking_positions
  where event_id = v_event and player_id = v_reptat;

  if v_pos_reptador is null or v_pos_reptat is null then
    ok := false; reason := 'jugadors fora del rànquing'; return next; return;
  end if;

  -- Intercanvi segur de posicions (evitem xocs d’unicitat amb posició temporal -1)
  perform 1;
  update public.ranking_positions
     set posicio = -1
   where event_id = v_event and player_id = v_reptador;

  update public.ranking_positions
     set posicio = v_pos_reptador
   where event_id = v_event and player_id = v_reptat;

  update public.ranking_positions
     set posicio = v_pos_reptat
   where event_id = v_event and player_id = v_reptador;

  -- Històric de canvis
  insert into public.history_position_changes
    (event_id, player_id, posicio_anterior, posicio_nova, motiu, ref_challenge)
  values
    (v_event, v_reptador, v_pos_reptador, v_pos_reptat, 'walkover (incompareixença del reptat)', p_challenge_id),
    (v_event, v_reptat,   v_pos_reptat,   v_pos_reptador, 'walkover (incompareixença del reptat)', p_challenge_id);

  -- Tanca el repte com caducat per manca de resposta
  update public.challenges
     set estat = 'caducat',
         observacions = coalesce(observacions,'') || case when coalesce(observacions,'') <> '' then E'\n' else '' end
                        || 'Tancat per walkover: incompareixença/refús del reptat'
   where id = p_challenge_id;

  ok := true; reason := format('intercanvi %s<->%s aplicat', v_pos_reptador, v_pos_reptat);
  return next;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.program_challenge(p_challenge uuid, p_when timestamp with time zone)
 RETURNS TABLE(ok boolean, reason text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_is_admin boolean;
  v_estat public.challenge_state;
  v_count smallint;
begin
  -- És admin?
  select exists (
    select 1 from public.admins a where a.email = (auth.jwt() ->> 'email')
  ) into v_is_admin;

  select c.estat, c.reprogram_count
  into v_estat, v_count
  from public.challenges c
  where c.id = p_challenge
  for update;

  if not found then
    return query select false, 'challenge_not_found';
    return;
  end if;

  -- Límits per usuaris no-admin
  if not v_is_admin then
    if v_estat = 'programat' and v_count >= 1 then
      return query select false, 'reprogram_limit_reached';
    end if;
  end if;

  -- Actualitza: passa a 'programat' i incrementa reprogram_count només si ja estava programat
  update public.challenges
  set data_acceptacio = p_when,
      estat = 'programat',
      reprogram_count = case
        when v_estat = 'programat' and not v_is_admin then v_count + 1
        else v_count
      end
  where id = p_challenge;

  return query select true, null;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.programar_repte(p_challenge uuid, p_data timestamp with time zone, p_actor_email text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  is_admin boolean;
  cur_reprog smallint;
  cur_estat public.challenge_state;
begin
  select public.is_admin(p_actor_email) into is_admin;
  select reprogramacions, estat into cur_reprog, cur_estat
  from public.challenges where id = p_challenge;

  if cur_estat not in ('proposat','acceptat','programat') then
    return json_build_object('ok', false, 'error', 'Aquest repte no es pot programar');
  end if;

  if not is_admin and cur_reprog >= 1 then
    return json_build_object('ok', false, 'error', 'Ja s’ha reprogramat una vegada (cal administrador)');
  end if;

  update public.challenges
  set data_programada = p_data,
      estat = 'programat',
      reprogramacions = case when cur_estat = 'programat' then reprogramacions + 1 else reprogramacions end
  where id = p_challenge;

  return json_build_object('ok', true);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.promote_first_waiting(event_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
declare
  v_wait_id uuid;
  v_player uuid;
  v_pos_max smallint;
begin
  -- Primer de la llista
  select id, player_id into v_wait_id, v_player
  from public.waiting_list
  order by ordre asc, data_inscripcio asc
  limit 1;

  if v_wait_id is null then
    return null; -- no hi ha ningú en espera
  end if;

  -- Quina és la posició màxima del rànquing (esperat 20)
  select coalesce(max(posicio), 0) into v_pos_max
  from public.ranking_positions
  where event_id = event_id;

  if v_pos_max < 20 then
    -- Si per alguna raó hi ha menys de 20, entrem al final
    insert into public.ranking_positions(event_id, posicio, player_id)
    values (event_id, greatest(v_pos_max + 1, 20), v_player);
  else
    -- Entrar com a posició 20
    insert into public.ranking_positions(event_id, posicio, player_id)
    values (event_id, 20, v_player);
  end if;

  -- Treure de la llista d’espera
  delete from public.waiting_list where id = v_wait_id;

  return v_player;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.record_match_and_resolve(p_challenge uuid, p_data_joc timestamp with time zone, p_car_r smallint, p_car_t smallint, p_entrades smallint, p_serie_r smallint DEFAULT 0, p_serie_t smallint DEFAULT 0, p_tiebreak boolean DEFAULT false, p_tb_r smallint DEFAULT NULL::smallint, p_tb_t smallint DEFAULT NULL::smallint)
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
DECLARE
  s record;
  c public.challenges;
  m_id uuid;
  winner public.match_result;
  ev uuid;
  reptador uuid;
  reptat uuid;
  pos_r smallint;
  pos_t smallint;
BEGIN
  SELECT * INTO c FROM public.challenges WHERE id = p_challenge FOR UPDATE;
  IF c.id IS NULL THEN RAISE EXCEPTION 'Repte % no existeix', p_challenge; END IF;
  IF c.estat NOT IN ('acceptat','programat') THEN
    RAISE EXCEPTION 'No es pot registrar el partit: estat actual %', c.estat;
  END IF;

  -- Determinar guanyador
  IF p_car_r > p_car_t THEN
    winner := 'reptador';
  ELSIF p_car_t > p_car_r THEN
    winner := 'reptat';
  ELSE
    IF p_tiebreak THEN
      IF p_tb_r IS NULL OR p_tb_t IS NULL THEN
        RAISE EXCEPTION 'Falten dades de tiebreak';
      END IF;
      winner := CASE WHEN p_tb_r > p_tb_t THEN 'reptador'
                     WHEN p_tb_t > p_tb_r THEN 'reptat'
                     ELSE 'empat' END;
    ELSE
      winner := 'empat';
    END IF;
  END IF;

  INSERT INTO public.matches (
    challenge_id, data_joc, caramboles_reptador, caramboles_reptat,
    entrades, serie_max_reptador, serie_max_reptat, resultat,
    tiebreak, tiebreak_reptador, tiebreak_reptat
  ) VALUES (
    p_challenge, p_data_joc, p_car_r, p_car_t,
    p_entrades, p_serie_r, p_serie_t, winner,
    p_tiebreak, p_tb_r, p_tb_t
  ) RETURNING id INTO m_id;

  UPDATE public.challenges SET estat='jugat' WHERE id = p_challenge;

  ev := c.event_id; reptador := c.reptador_id; reptat := c.reptat_id;

  SELECT posicio INTO pos_r FROM public.ranking_positions WHERE event_id = ev AND player_id = reptador;
  SELECT posicio INTO pos_t FROM public.ranking_positions WHERE event_id = ev AND player_id = reptat;

  IF winner = 'reptador' AND pos_r IS NOT NULL AND pos_t IS NOT NULL AND pos_r > pos_t THEN
    -- intercanvi
    UPDATE public.ranking_positions SET player_id = reptador WHERE event_id=ev AND posicio=pos_t;
    UPDATE public.ranking_positions SET player_id = reptat   WHERE event_id=ev AND posicio=pos_r;

    INSERT INTO public.history_position_changes(event_id, player_id, posicio_anterior, posicio_nova, motiu, ref_challenge)
    VALUES
      (ev, reptador, pos_r, pos_t, 'victòria repte', p_challenge),
      (ev, reptat,   pos_t, pos_r, 'derrota repte',  p_challenge);
  END IF;

  UPDATE public.players SET data_ultim_repte = p_data_joc::date WHERE id IN (reptador, reptat);

  RETURN m_id;
END; $function$
;

CREATE OR REPLACE FUNCTION public.reset_event_to_initial(p_event uuid DEFAULT NULL::uuid, p_clear_waiting boolean DEFAULT false)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
declare
  v_event uuid := coalesce(p_event, public.get_active_event_id());
  v_count int := 0;
begin
  if v_event is null then
    return json_build_object('ok', false, 'error', 'No hi ha event actiu');
  end if;

  -- Esborra dependències
  delete from public.matches
  using public.challenges c
  where matches.challenge_id = c.id
    and c.event_id = v_event;

  delete from public.challenges where event_id = v_event;
  delete from public.penalties where event_id = v_event;
  delete from public.history_position_changes where event_id = v_event;

  if p_clear_waiting then
    delete from public.waiting_list;
  end if;

  -- Restaura rànquing des de initial_ranking
  delete from public.ranking_positions where event_id = v_event;

  insert into public.ranking_positions(event_id, posicio, player_id)
  select ir.event_id, ir.posicio, ir.player_id
  from public.initial_ranking ir
  where ir.event_id = v_event
  order by ir.posicio;

  get diagnostics v_count = row_count;

  -- Assegura estat 'actiu' als jugadors del rànquing restaurat
  update public.players p
  set estat = 'actiu'
  where p.id in (
    select player_id from public.ranking_positions where event_id = v_event
  );

  return json_build_object('ok', true, 'restored', v_count);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.reset_full_competition()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_matches   INTEGER;
  v_history   INTEGER;
  v_penalties INTEGER;
  v_challenges INTEGER;
  v_ranking   INTEGER;
  v_waitlist  INTEGER;
  v_events    INTEGER;
  v_players   INTEGER;
  v_event_id  uuid;
  v_player_id uuid;
  i           INTEGER;
BEGIN
  -- comptatges previs
  SELECT COUNT(*) INTO v_matches   FROM matches;
  SELECT COUNT(*) INTO v_history   FROM history_position_changes;
  SELECT COUNT(*) INTO v_penalties FROM penalties;
  SELECT COUNT(*) INTO v_challenges FROM challenges;
  SELECT COUNT(*) INTO v_ranking   FROM ranking_positions;
  SELECT COUNT(*) INTO v_waitlist  FROM waiting_list;
  SELECT COUNT(*) INTO v_events    FROM events;
  SELECT COUNT(*) INTO v_players   FROM players;

  -- reset de taules
  TRUNCATE TABLE matches CASCADE;
  TRUNCATE TABLE history_position_changes CASCADE;
  TRUNCATE TABLE penalties CASCADE;
  TRUNCATE TABLE challenges CASCADE;
  TRUNCATE TABLE ranking_positions CASCADE;
  TRUNCATE TABLE waiting_list CASCADE;
  TRUNCATE TABLE events CASCADE;
  TRUNCATE TABLE players CASCADE;

  -- nou event i jugadors base
  INSERT INTO events(nom, temporada, actiu)
  VALUES ('Campionat Continu 3 Bandes',
          to_char(NOW(),'YYYY-YYYY'), TRUE)
  RETURNING id INTO v_event_id;

  FOR i IN 1..20 LOOP
    INSERT INTO players(nom, email, estat)
    VALUES (format('Jugador %02s', i), NULL, 'actiu')
    RETURNING id INTO v_player_id;

    INSERT INTO ranking_positions(event_id, posicio, player_id)
    VALUES (v_event_id, i, v_player_id);
  END LOOP;

  FOR i IN 1..5 LOOP
    INSERT INTO players(nom, email, estat)
    VALUES (format('Aspirant %02s', i), NULL, 'actiu')
    RETURNING id INTO v_player_id;

    INSERT INTO waiting_list(event_id, player_id, ordre)
    VALUES (v_event_id, v_player_id, i);
  END LOOP;

  RETURN json_build_object(
    'ok', TRUE,
    'event_id', v_event_id,
    'deleted', json_build_object(
      'matches',   v_matches,
      'history_position_changes', v_history,
      'penalties', v_penalties,
      'challenges', v_challenges,
      'ranking_positions', v_ranking,
      'waiting_list', v_waitlist,
      'events', v_events,
      'players', v_players
    ),
    'seeded', json_build_object(
      'ranking_players', 20,
      'waiting_list', 5
    )
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.resolve_access_challenge(p_challenge uuid, p_winner text)
 RETURNS json
 LANGUAGE plpgsql
 STABLE
AS $function$
declare
  chal record;
  e uuid;
  pos20_player uuid;
  wl_first uuid;
  loser uuid;
  winner uuid;
  max_ordre int;
begin
  select * into chal from challenges where id = p_challenge;
  if not found or chal.tipus <> 'access' then
    return json_build_object('ok', false, 'error', 'Repte d’accés inexistent o invàlid');
  end if;

  if p_winner not in ('reptador','reptat') then
    return json_build_object('ok', false, 'error', 'Paràmetre guanyador invàlid');
  end if;

  e := chal.event_id;

  select player_id into pos20_player
    from ranking_positions
   where event_id = e and posicio = 20;

  select player_id into wl_first
    from waiting_list
   where event_id = e
   order by ordre asc
   limit 1;

  if pos20_player is null or wl_first is null then
    return json_build_object('ok', false, 'error', 'Falta posició 20 o llista d’espera buida');
  end if;

  if p_winner = 'reptador' then
    winner := chal.reptador_id; loser := chal.reptat_id;
  else
    winner := chal.reptat_id;   loser := chal.reptador_id;
  end if;

  if winner = wl_first and loser = pos20_player then
    -- Entra el primer de la llista a la pos. 20, i el de la pos. 20 passa al final de la llista
    update ranking_positions
       set player_id = wl_first
     where event_id = e and posicio = 20;

    select coalesce(max(ordre),0) into max_ordre
      from waiting_list where event_id = e;

    delete from waiting_list where event_id = e and player_id = wl_first;

    insert into waiting_list(event_id, player_id, ordre)
    values (e, pos20_player, max_ordre + 1);

  elsif winner = pos20_player and loser = wl_first then
    -- Manté la pos. 20; el primer de la llista cau al final
    select coalesce(max(ordre),0) into max_ordre
      from waiting_list where event_id = e;

    update waiting_list
       set ordre = max_ordre + 1
     where event_id = e and player_id = wl_first;

  else
    return json_build_object('ok', false, 'error', 'Participants incorrectes (no són Top-20 vs 1a llista)');
  end if;

  update challenges set estat = 'jugat' where id = p_challenge;

  return json_build_object('ok', true);
end$function$
;

CREATE OR REPLACE FUNCTION public.rotate_waiting_list(p_event uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_first RECORD;
  v_max   INTEGER;
BEGIN
  SELECT player_id, ordre, data_inscripcio
    INTO v_first
    FROM waiting_list
   WHERE event_id = p_event
   ORDER BY ordre
   LIMIT 1;

  IF v_first.player_id IS NULL THEN
    RETURN;
  END IF;

  IF v_first.data_inscripcio < NOW() - INTERVAL '15 days' THEN
    SELECT COALESCE(MAX(ordre),0) + 1 INTO v_max
      FROM waiting_list
     WHERE event_id = p_event;

    UPDATE waiting_list
       SET ordre = v_max,
           data_inscripcio = NOW()
     WHERE event_id = p_event AND player_id = v_first.player_id;
  END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.run_challenge_deadlines()
 RETURNS json
 LANGUAGE plpgsql
AS $function$
declare
  s record;
  expired_accept int := 0;
  expired_play   int := 0;
begin
  select dies_acceptar_repte, dies_jugar_despres_acceptar
    into s
  from app_settings
  order by updated_at desc
  limit 1;

  -- No acceptats dins termini -> 'caducat'
  update challenges c
     set estat = 'caducat'
   where c.estat = 'proposat'
     and c.data_proposta is not null
     and now() > c.data_proposta + (s.dies_acceptar_repte || ' days')::interval;

  get diagnostics expired_accept = row_count;

  -- Acceptats/Programats però no jugats dins termini -> 'anullat'
  update challenges c
     set estat = 'anullat'
   where c.estat in ('acceptat','programat')
     and c.data_acceptacio is not null
     and now() > c.data_acceptacio + (s.dies_jugar_despres_acceptar || ' days')::interval;

  get diagnostics expired_play = row_count;

  return json_build_object('ok', true,
                           'caducats_sense_acceptar', expired_accept,
                           'anullats_sense_jugar',    expired_play);
end$function$
;

CREATE OR REPLACE FUNCTION public.run_inactivity_sweep()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  e uuid := public.get_active_event();
  s app_settings := public.get_settings();
  r record;
  last_play timestamptz;
  changed_pre int := 0;
  changed_inact int := 0;
  wl_first uuid;
begin
  if e is null then
    return json_build_object('ok', false, 'error', 'No hi ha event actiu');
  end if;

  -- Recorre tot el rànquing (posició asc)
  for r in
    select posicio, player_id
    from public.ranking_positions
    where event_id = e
    order by posicio asc
  loop
    select public.ultim_partit_jugat(r.player_id) into last_play;

    -- Inactiu?
    if last_play is null or now() - last_play >= (s.inactiu_setmanes || ' weeks')::interval then
      -- treure del rànquing i moure primer de l’espera a posició 20
      select player_id into wl_first
      from public.waiting_list
      order by ordre asc
      limit 1;

      if wl_first is not null then
        -- posa wl_first a posició 20
        update public.ranking_positions
        set player_id = wl_first
        where event_id = e and posicio = 20;

        -- el que estava a posició 20 cau al final de l’espera
        insert into public.waiting_list(player_id, ordre)
        select player_id, (select coalesce(max(ordre),0)+1 from public.waiting_list)
        from public.ranking_positions
        where event_id = e and posicio = 20 and player_id <> wl_first;

        -- elimina wl_first de la waiting_list (ara és al rànquing)
        delete from public.waiting_list where player_id = wl_first;

        -- elimina el jugador inactiu del rànquing (compactant posicions per sobre)
        perform 1; -- ja l’hem substituït via posició 20; ara fem shift dels de sota cap amunt
        update public.ranking_positions
        set posicio = posicio - 1
        where event_id=e and posicio > r.posicio;

        delete from public.ranking_positions
        where event_id=e and player_id = r.player_id;

        insert into public.history_position_changes(event_id, player_id, posicio_anterior, posicio_nova, motiu)
        values (e, r.player_id, r.posicio, null, 'Inactiu (retirat del rànquing)');

        changed_inact := changed_inact + 1;
      end if;

    -- Pre-inactiu? (baixa 5 posicions si es pot)
    elsif now() - last_play >= (s.pre_inactiu_setmanes || ' weeks')::interval then
      if r.posicio <= 15 then
        -- De r.posicio a r.posicio+5
        update public.ranking_positions
        set posicio = posicio - 1
        where event_id=e and posicio between r.posicio+1 and r.posicio+5;

        update public.ranking_positions
        set posicio = r.posicio + 5
        where event_id=e and player_id = r.player_id;

        insert into public.history_position_changes(event_id, player_id, posicio_anterior, posicio_nova, motiu)
        values (e, r.player_id, r.posicio, r.posicio+5, 'Pre-inactiu (baixa 5 posicions)');

        changed_pre := changed_pre + 1;
      end if;
    end if;
  end loop;

  return json_build_object('ok', true, 'pre_inactiu_baixats', changed_pre, 'inactiu_reemplaçats', changed_inact);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.shift_block_down(p_event uuid, p_posicio_inici integer, p_posicio_final integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
declare
  rec record;
begin
  for rec in
    select posicio, player_id from public.ranking_positions
    where event_id=p_event and posicio between p_posicio_inici and p_posicio_final
    order by posicio asc
  loop
    update public.ranking_positions
      set posicio = rec.posicio + 1, assignat_el = now()
      where event_id=p_event and posicio = rec.posicio;
  end loop;
end $function$
;

CREATE OR REPLACE FUNCTION public.shift_down_player(p_event uuid, p_player uuid, p_steps integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
declare
  v_pos smallint;
  v_new smallint;
  i int;
  v_swap_player uuid;
begin
  if p_steps <= 0 then
    return;
  end if;

  select posicio into v_pos
  from public.ranking_positions
  where event_id = p_event and player_id = p_player;

  if v_pos is null then
    return;
  end if;

  v_new := least(v_pos + p_steps, 999); -- tall de seguretat

  for i in 1..p_steps loop
    -- jugador immediatament inferior
    select player_id into v_swap_player
    from public.ranking_positions
    where event_id = p_event and posicio = v_pos + 1;

    exit when v_swap_player is null; -- ja era al final

    -- intercanvi v_pos <-> v_pos+1
    update public.ranking_positions
    set posicio = case
      when player_id = p_player then v_pos + 1
      when player_id = v_swap_player then v_pos
      else posicio
    end
    where event_id = p_event and player_id in (p_player, v_swap_player);

    -- historial
    insert into public.history_position_changes(event_id, player_id, posicio_anterior, posicio_nova, motiu)
    values (p_event, p_player, v_pos, v_pos + 1, 'pre-inactivitat: baixa 1 posició');

    insert into public.history_position_changes(event_id, player_id, posicio_anterior, posicio_nova, motiu)
    values (p_event, v_swap_player, v_pos + 1, v_pos, 'pre-inactivitat: puja 1 posició');

    v_pos := v_pos + 1;
  end loop;

  -- Si cau >20, mobilitzar waiting_list
  if v_pos > 20 then
    -- jugador surt del rànquing
    delete from public.ranking_positions
    where event_id = p_event and player_id = p_player;

    insert into public.history_position_changes(event_id, player_id, posicio_anterior, posicio_nova, motiu)
    values (p_event, p_player, v_pos, null, 'pre-inactivitat: surt del Top-20');

    perform public.promote_first_waiting(p_event);
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.swap_if_below(p_event uuid, p_winner uuid, p_loser uuid)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
declare
  pos_w smallint;
  pos_l smallint;
begin
  select posicio into pos_w from public.ranking_positions where event_id = p_event and player_id = p_winner;
  select posicio into pos_l from public.ranking_positions where event_id = p_event and player_id = p_loser;

  if pos_w is null or pos_l is null then
    return false;
  end if;

  if pos_w > pos_l then
    -- intercanvi
    update public.ranking_positions
    set posicio = case
      when player_id = p_winner then pos_l
      when player_id = p_loser then pos_w
      else posicio
    end
    where event_id = p_event and player_id in (p_winner, p_loser);

    insert into public.history_position_changes(event_id, player_id, posicio_anterior, posicio_nova, motiu)
    values (p_event, p_winner, pos_w, pos_l, 'intercanvi per sanció');

    insert into public.history_position_changes(event_id, player_id, posicio_anterior, posicio_nova, motiu)
    values (p_event, p_loser, pos_l, pos_w, 'intercanvi per sanció');

    return true;
  end if;

  return false;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.swap_positions(p_event uuid, p_player_a uuid, p_player_b uuid, p_motiu text, p_ref_challenge uuid DEFAULT NULL::uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
declare
  pos_a int;
  pos_b int;
begin
  select posicio into pos_a from public.ranking_positions where event_id=p_event and player_id=p_player_a;
  select posicio into pos_b from public.ranking_positions where event_id=p_event and player_id=p_player_b;

  if pos_a is null or pos_b is null then
    raise exception 'Alguna posició no existeix a ranking_positions';
  end if;

  update public.ranking_positions set player_id=p_player_b, assignat_el=now() where event_id=p_event and posicio=pos_a;
  update public.ranking_positions set player_id=p_player_a, assignat_el=now() where event_id=p_event and posicio=pos_b;

  insert into public.history_position_changes(event_id, player_id, posicio_anterior, posicio_nova, motiu, ref_challenge)
  values
    (p_event, p_player_a, pos_a, pos_b, p_motiu, p_ref_challenge),
    (p_event, p_player_b, pos_b, pos_a, p_motiu, p_ref_challenge);
end $function$
;

CREATE OR REPLACE FUNCTION public.sweep_inactivity_from_settings()
 RETURNS TABLE(player_id uuid, action text, ok boolean, reason text)
 LANGUAGE plpgsql
AS $function$
declare
  v_event uuid;
  v_pre_weeks int;
  v_inact_weeks int;
  r record;
begin
  -- Event actiu
  select id into v_event
  from public.events
  where actiu = true
  order by creat_el desc
  limit 1;

  if v_event is null then
    return; -- no hi ha cap event actiu
  end if;

  -- Llegeix valors d'app_settings més recents
  select pre_inactiu_setmanes, inactiu_setmanes
    into v_pre_weeks, v_inact_weeks
  from public.app_settings
  order by updated_at desc
  limit 1;

  -- Recorre jugadors del rànquing de l’event
  for r in
    select rp.player_id, rp.posicio, p.data_ultim_repte
    from public.ranking_positions rp
    join public.players p on p.id = rp.player_id
    where rp.event_id = v_event
  loop
    -- Si mai ha jugat, el podem saltar (o tractar com a cas especial si vols)
    if r.data_ultim_repte is null then
      continue;
    end if;

    if r.data_ultim_repte < now() - (v_inact_weeks || ' weeks')::interval then
      return query select * from public.apply_inactivity(r.player_id, v_event);
    elsif r.data_ultim_repte < now() - (v_pre_weeks || ' weeks')::interval then
      return query select * from public.apply_pre_inactivity(r.player_id, v_event);
    end if;
  end loop;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.sweep_overdue_challenges_from_settings()
 RETURNS TABLE(challenge_id uuid, action text, ok boolean, reason text)
 LANGUAGE plpgsql
AS $function$
declare
  v_days_prop integer;
  v_days_acc  integer;
begin
  select s.dies_acceptar_repte, s.dies_jugar_despres_acceptar
    into v_days_prop, v_days_acc
  from public.app_settings s
  order by s.updated_at desc
  limit 1;

  return query
  select * from public.sweep_overdue_challenges(v_days_prop, v_days_acc);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.sweep_overdue_challenges_from_settings_mvp()
 RETURNS TABLE(challenge_id uuid, action text, ok boolean, reason text)
 LANGUAGE plpgsql
AS $function$
declare
  v_days_prop integer;
  v_days_acc integer;
begin
  select dies_acceptar_repte, dies_jugar_despres_acceptar
    into v_days_prop, v_days_acc
  from public.app_settings
  order by updated_at desc
  limit 1;

  return query
  select * from public.sweep_overdue_challenges_mvp(v_days_prop, v_days_acc);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.sweep_overdue_challenges_from_settings_mvp2()
 RETURNS TABLE(challenge_id uuid, action text, done boolean, msg text)
 LANGUAGE plpgsql
AS $function$
declare
  v_days_prop integer;
  v_days_acc integer;
begin
  select dies_acceptar_repte, dies_jugar_despres_acceptar
    into v_days_prop, v_days_acc
  from public.app_settings
  order by updated_at desc
  limit 1;

  return query
  select * from public.sweep_overdue_challenges_mvp2(v_days_prop, v_days_acc);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.sweep_overdue_challenges_mvp(p_days_proposat integer, p_days_acceptat integer)
 RETURNS TABLE(challenge_id uuid, action text, ok boolean, reason text)
 LANGUAGE plpgsql
AS $function$
declare
  r record;
  v_ok boolean;
  v_reason text;
begin
  perform public._set_search_path();

  -- a) PROPOSAT fora de termini
  for r in
    select c.id
    from public.challenges c
    where c.estat = 'proposat'
      and c.data_proposta < now() - make_interval(days => p_days_proposat)
  loop
    -- la funció té OUT params: no posar llista de columnes a l'àlies
    select ok, reason
      into v_ok, v_reason
    from public.process_refusal_or_timeout(r.id);

    return query select r.id, 'refusal_or_timeout', v_ok, v_reason;
  end loop;

  -- b) ACCEPTAT sense programar fora de termini
  for r in
    select c.id
    from public.challenges c
    where c.estat = 'acceptat'
      and c.data_programada is null
      and c.data_acceptacio < now() - make_interval(days => p_days_acceptat)
  loop
    select ok, reason
      into v_ok, v_reason
    from public.penalize_unprogrammed_after_accept(r.id);

    return query select r.id, 'penalize_unprogrammed', v_ok, v_reason;
  end loop;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.sweep_overdue_challenges_mvp2(p_days_proposat integer, p_days_acceptat integer)
 RETURNS TABLE(challenge_id uuid, action text, done boolean, msg text)
 LANGUAGE plpgsql
AS $function$
declare
  r record;
  v_ok boolean;
  v_reason text;
begin
  perform public._set_search_path();

  -- a) PROPOSAT fora de termini
  for r in
    select c.id
    from public.challenges c
    where c.estat = 'proposat'
      and c.data_proposta < now() - make_interval(days => p_days_proposat)
  loop
    -- Qualificar sempre amb àlies per evitar ambigüitats
    select x.ok, x.reason
      into v_ok, v_reason
    from public.process_refusal_or_timeout(r.id) as x;

    return query select r.id, 'refusal_or_timeout', v_ok, v_reason;
  end loop;

  -- b) ACCEPTAT sense programar fora de termini
  for r in
    select c.id
    from public.challenges c
    where c.estat = 'acceptat'
      and c.data_programada is null
      and c.data_acceptacio < now() - make_interval(days => p_days_acceptat)
  loop
    select x.ok, x.reason
      into v_ok, v_reason
    from public.penalize_unprogrammed_after_accept(r.id) as x;

    return query select r.id, 'penalize_unprogrammed', v_ok, v_reason;
  end loop;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_challenges_accept()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  if new.estat = 'acceptat' and old.estat <> 'acceptat' then
    new.data_acceptacio := now();
  end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.trg_challenges_validate()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
declare
  pos_reptador int;
  pos_reptat int;
  last_rep_reptador date;
  last_rep_reptat date;
begin
  -- emplenar posicions derivades
  select get_posicio(new.event_id, new.reptador_id) into pos_reptador;
  select get_posicio(new.event_id, new.reptat_id) into pos_reptat;
  new.pos_reptador := pos_reptador;
  new.pos_reptat := pos_reptat;

  if new.tipus = 'normal' then
    if pos_reptador is null or pos_reptat is null then
      raise exception 'Per reptes normals, ambdós han de ser al rànquing (no a la llista d''espera)';
    end if;
    if not (pos_reptador > pos_reptat and (pos_reptador - pos_reptat) <= 2) then
      raise exception 'Només pots reptar fins a 2 posicions per sobre teu';
    end if;
  else
    -- tipus access: el reptat ha de ser posició 20
    if pos_reptat is distinct from 20 then
      raise exception 'Reptes d''accés només contra la posició 20';
    end if;
  end if;

  -- regla 7 dies des del darrer repte per cada jugador (excepte si el repte anterior va ser refusat)
  select data_ultim_repte into last_rep_reptador from public.players where id=new.reptador_id;
  select data_ultim_repte into last_rep_reptat from public.players where id=new.reptat_id;

  if last_rep_reptador is not null and (current_date - last_rep_reptador) < 7 then
    raise exception 'Han de passar 7 dies des del darrer repte del reptador';
  end if;
  if last_rep_reptat is not null and (current_date - last_rep_reptat) < 7 then
    raise exception 'Han de passar 7 dies des del darrer repte del reptat';
  end if;

  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.trg_inc_reprogramacions()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  -- només compta com a reprogramació si JA hi havia data i la nova és diferent
  if tg_op = 'UPDATE'
     and NEW.data_programada is distinct from OLD.data_programada
     and OLD.data_programada is not null
  then
    NEW.reprogramacions := coalesce(OLD.reprogramacions,0) + 1;
  end if;
  return NEW;
end$function$
;

CREATE OR REPLACE FUNCTION public.trg_matches_apply_result()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
declare
  ev uuid;
  rep record;
  motiu text;
  reptador_guanya boolean;
begin
  select c.*, get_posicio(c.event_id, c.reptador_id) as pos_r, get_posicio(c.event_id, c.reptat_id) as pos_t
  into rep
  from public.challenges c
  where c.id = new.challenge_id;

  if rep is null then
    raise exception 'Challenge inexistent';
  end if;

  -- marcar estat del repte
  update public.challenges set estat = 'jugat' where id = rep.id;

  -- actualitzar data_ultim_repte dels dos jugadors
  update public.players set data_ultim_repte = current_date where id in (rep.reptador_id, rep.reptat_id);

  -- determinar si guanya reptador
  reptador_guanya := (new.resultat in ('guanya_reptador','empat_tiebreak_reptador'));

  if rep.tipus = 'normal' then
    if reptador_guanya then
      motiu := 'Intercanvi per victòria del reptador (repte normal)';
      perform public.swap_positions(rep.event_id, rep.reptador_id, rep.reptat_id, motiu, rep.id);
    end if;
    -- si perd el reptador, no hi ha canvis (normativa)
  else
    -- tipus access (contra posició 20)
    if reptador_guanya then
      -- reptador entra a posició 20, el 20è surt i va a la cua de l'espera
      -- qui és el 20è ara? (era rep.reptat_id)
      perform public.waitlist_append(rep.reptat_id);
      update public.ranking_positions set player_id = rep.reptador_id, assignat_el=now()
      where event_id = rep.event_id and posicio = 20;

      insert into public.history_position_changes(event_id, player_id, posicio_anterior, posicio_nova, motiu, ref_challenge)
      values
        (rep.event_id, rep.reptador_id, null, 20, 'Accés: entra com a 20è', rep.id),
        (rep.event_id, rep.reptat_id, 20, null, 'Accés: surt a llista d''espera', rep.id);
    else
      -- reptador perd: va al final de la llista d'espera
      perform public.waitlist_append(rep.reptador_id);
    end if;
  end if;

  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.ultim_partit_jugat(p_player uuid)
 RETURNS timestamp with time zone
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select max(m.data_joc)
  from public.matches m
  join public.challenges c on c.id = m.challenge_id
  where c.reptador_id = p_player or c.reptat_id = p_player
$function$
;

create or replace view "public"."v_challenges_pending" as  SELECT id,
    event_id,
    reptador_id,
    reptat_id,
    (estat)::text AS estat,
    data_proposta,
    data_acceptacio,
    data_programada,
        CASE
            WHEN (estat = 'proposat'::challenge_state) THEN (EXTRACT(day FROM (now() - data_proposta)))::integer
            WHEN (estat = 'acceptat'::challenge_state) THEN (EXTRACT(day FROM (now() - data_acceptacio)))::integer
            ELSE NULL::integer
        END AS dies_transcorreguts
   FROM challenges c
  WHERE (estat = ANY (ARRAY['proposat'::challenge_state, 'acceptat'::challenge_state]));


create or replace view "public"."v_maintenance_run_details" as  SELECT run_id,
    kind,
    jsonb_array_length(payload) AS items_count,
    payload,
    created_at
   FROM maintenance_run_items ri
  ORDER BY created_at DESC;


create or replace view "public"."v_maintenance_runs" as  SELECT id,
    triggered_by,
    started_at,
    finished_at,
    (EXTRACT(epoch FROM (finished_at - started_at)))::integer AS duration_sec,
    ok,
    notes
   FROM maintenance_runs r
  ORDER BY started_at DESC;


create or replace view "public"."v_player_badges" as  WITH cfg AS (
         SELECT app_settings.cooldown_min_dies
           FROM app_settings
          ORDER BY app_settings.updated_at DESC
         LIMIT 1
        ), ev AS (
         SELECT events.id AS event_id
           FROM events
          WHERE (events.actiu = true)
          ORDER BY events.creat_el DESC
         LIMIT 1
        ), rp AS (
         SELECT rp_1.event_id,
            rp_1.player_id,
            rp_1.posicio
           FROM (ranking_positions rp_1
             JOIN ev ON ((ev.event_id = rp_1.event_id)))
        ), last_play AS (
         SELECT p.id AS player_id,
            p.data_ultim_repte AS last_play_date,
            (CURRENT_DATE - p.data_ultim_repte) AS days_since_last
           FROM players p
        ), active_ch AS (
         SELECT c.event_id,
            c.reptador_id AS player_id
           FROM challenges c
          WHERE (c.estat = ANY (ARRAY['proposat'::challenge_state, 'acceptat'::challenge_state, 'programat'::challenge_state]))
        UNION
         SELECT c.event_id,
            c.reptat_id AS player_id
           FROM challenges c
          WHERE (c.estat = ANY (ARRAY['proposat'::challenge_state, 'acceptat'::challenge_state, 'programat'::challenge_state]))
        )
 SELECT rp.event_id,
    rp.player_id,
    rp.posicio,
    COALESCE(lp.last_play_date, NULL::date) AS last_play_date,
        CASE
            WHEN (lp.days_since_last IS NOT NULL) THEN lp.days_since_last
            ELSE NULL::integer
        END AS days_since_last,
    (EXISTS ( SELECT 1
           FROM active_ch ac
          WHERE ((ac.event_id = rp.event_id) AND (ac.player_id = rp.player_id)))) AS has_active_challenge,
        CASE
            WHEN (lp.days_since_last IS NULL) THEN false
            WHEN (lp.days_since_last < ( SELECT cfg.cooldown_min_dies
               FROM cfg)) THEN true
            ELSE false
        END AS in_cooldown,
        CASE
            WHEN (EXISTS ( SELECT 1
               FROM active_ch ac
              WHERE ((ac.event_id = rp.event_id) AND (ac.player_id = rp.player_id)))) THEN false
            WHEN ((lp.days_since_last IS NOT NULL) AND (lp.days_since_last < ( SELECT cfg.cooldown_min_dies
               FROM cfg))) THEN false
            ELSE true
        END AS can_be_challenged
   FROM (rp
     LEFT JOIN last_play lp ON ((lp.player_id = rp.player_id)));


create or replace view "public"."v_player_timeline" as  SELECT h.event_id,
    h.player_id,
    h.posicio_anterior,
    h.posicio_nova,
    h.motiu,
    h.creat_el,
    h.ref_challenge,
    (c.estat)::text AS challenge_estat
   FROM (history_position_changes h
     LEFT JOIN challenges c ON ((c.id = h.ref_challenge)));


CREATE OR REPLACE FUNCTION public.waitlist_append(p_event uuid, p_player uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
declare max_ordre int;
begin
  select coalesce(max(ordre),0)
    into max_ordre
    from waiting_list
   where event_id = p_event;

  insert into waiting_list(event_id, player_id, ordre)
  values (p_event, p_player, max_ordre + 1)
  on conflict (event_id, player_id) do nothing;
end$function$
;

CREATE OR REPLACE FUNCTION public.waitlist_append(p_player uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
declare
  max_ordre int;
begin
  select coalesce(max(ordre),0) into max_ordre from public.waiting_list;
  insert into public.waiting_list(player_id, ordre) values (p_player, max_ordre+1)
  on conflict (player_id) do nothing;
end $function$
;

CREATE OR REPLACE FUNCTION public.waitlist_pop_first(OUT o_player uuid)
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
declare
  rec record;
begin
  select id, player_id into rec from public.waiting_list order by ordre asc limit 1;
  if rec.id is null then
    o_player := null;
    return;
  end if;
  o_player := rec.player_id;
  delete from public.waiting_list where id = rec.id;
  -- re-normalitzar ordres
  with ren as (
    select id, row_number() over(order by ordre) as rn from public.waiting_list
  )
  update public.waiting_list w
    set ordre = ren.rn
  from ren
  where w.id = ren.id;
end $function$
;

CREATE OR REPLACE FUNCTION public.waitlist_pop_first(p_event uuid, OUT o_player uuid)
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
declare rec record;
begin
  select id, player_id
    into rec
    from waiting_list
   where event_id = p_event
   order by ordre asc
   limit 1;

  if rec.id is null then
    o_player := null; return;
  end if;

  o_player := rec.player_id;
  delete from waiting_list where id = rec.id;

  with ren as (
    select id, row_number() over(order by ordre) rn
      from waiting_list
     where event_id = p_event
  )
  update waiting_list w
     set ordre = ren.rn
    from ren
   where w.id = ren.id;
end$function$
;

grant delete on table "public"."admins" to "anon";

grant insert on table "public"."admins" to "anon";

grant references on table "public"."admins" to "anon";

grant select on table "public"."admins" to "anon";

grant trigger on table "public"."admins" to "anon";

grant truncate on table "public"."admins" to "anon";

grant update on table "public"."admins" to "anon";

grant delete on table "public"."admins" to "authenticated";

grant insert on table "public"."admins" to "authenticated";

grant references on table "public"."admins" to "authenticated";

grant select on table "public"."admins" to "authenticated";

grant trigger on table "public"."admins" to "authenticated";

grant truncate on table "public"."admins" to "authenticated";

grant update on table "public"."admins" to "authenticated";

grant delete on table "public"."admins" to "service_role";

grant insert on table "public"."admins" to "service_role";

grant references on table "public"."admins" to "service_role";

grant select on table "public"."admins" to "service_role";

grant trigger on table "public"."admins" to "service_role";

grant truncate on table "public"."admins" to "service_role";

grant update on table "public"."admins" to "service_role";

grant delete on table "public"."app_settings" to "anon";

grant insert on table "public"."app_settings" to "anon";

grant references on table "public"."app_settings" to "anon";

grant select on table "public"."app_settings" to "anon";

grant trigger on table "public"."app_settings" to "anon";

grant truncate on table "public"."app_settings" to "anon";

grant update on table "public"."app_settings" to "anon";

grant delete on table "public"."app_settings" to "authenticated";

grant insert on table "public"."app_settings" to "authenticated";

grant references on table "public"."app_settings" to "authenticated";

grant select on table "public"."app_settings" to "authenticated";

grant trigger on table "public"."app_settings" to "authenticated";

grant truncate on table "public"."app_settings" to "authenticated";

grant update on table "public"."app_settings" to "authenticated";

grant delete on table "public"."app_settings" to "service_role";

grant insert on table "public"."app_settings" to "service_role";

grant references on table "public"."app_settings" to "service_role";

grant select on table "public"."app_settings" to "service_role";

grant trigger on table "public"."app_settings" to "service_role";

grant truncate on table "public"."app_settings" to "service_role";

grant update on table "public"."app_settings" to "service_role";

grant delete on table "public"."challenges" to "anon";

grant insert on table "public"."challenges" to "anon";

grant references on table "public"."challenges" to "anon";

grant select on table "public"."challenges" to "anon";

grant trigger on table "public"."challenges" to "anon";

grant truncate on table "public"."challenges" to "anon";

grant update on table "public"."challenges" to "anon";

grant delete on table "public"."challenges" to "authenticated";

grant insert on table "public"."challenges" to "authenticated";

grant references on table "public"."challenges" to "authenticated";

grant select on table "public"."challenges" to "authenticated";

grant trigger on table "public"."challenges" to "authenticated";

grant truncate on table "public"."challenges" to "authenticated";

grant update on table "public"."challenges" to "authenticated";

grant delete on table "public"."challenges" to "service_role";

grant insert on table "public"."challenges" to "service_role";

grant references on table "public"."challenges" to "service_role";

grant select on table "public"."challenges" to "service_role";

grant trigger on table "public"."challenges" to "service_role";

grant truncate on table "public"."challenges" to "service_role";

grant update on table "public"."challenges" to "service_role";

grant delete on table "public"."events" to "anon";

grant insert on table "public"."events" to "anon";

grant references on table "public"."events" to "anon";

grant select on table "public"."events" to "anon";

grant trigger on table "public"."events" to "anon";

grant truncate on table "public"."events" to "anon";

grant update on table "public"."events" to "anon";

grant delete on table "public"."events" to "authenticated";

grant insert on table "public"."events" to "authenticated";

grant references on table "public"."events" to "authenticated";

grant select on table "public"."events" to "authenticated";

grant trigger on table "public"."events" to "authenticated";

grant truncate on table "public"."events" to "authenticated";

grant update on table "public"."events" to "authenticated";

grant delete on table "public"."events" to "service_role";

grant insert on table "public"."events" to "service_role";

grant references on table "public"."events" to "service_role";

grant select on table "public"."events" to "service_role";

grant trigger on table "public"."events" to "service_role";

grant truncate on table "public"."events" to "service_role";

grant update on table "public"."events" to "service_role";

grant delete on table "public"."history_position_changes" to "anon";

grant insert on table "public"."history_position_changes" to "anon";

grant references on table "public"."history_position_changes" to "anon";

grant select on table "public"."history_position_changes" to "anon";

grant trigger on table "public"."history_position_changes" to "anon";

grant truncate on table "public"."history_position_changes" to "anon";

grant update on table "public"."history_position_changes" to "anon";

grant delete on table "public"."history_position_changes" to "authenticated";

grant insert on table "public"."history_position_changes" to "authenticated";

grant references on table "public"."history_position_changes" to "authenticated";

grant select on table "public"."history_position_changes" to "authenticated";

grant trigger on table "public"."history_position_changes" to "authenticated";

grant truncate on table "public"."history_position_changes" to "authenticated";

grant update on table "public"."history_position_changes" to "authenticated";

grant delete on table "public"."history_position_changes" to "service_role";

grant insert on table "public"."history_position_changes" to "service_role";

grant references on table "public"."history_position_changes" to "service_role";

grant select on table "public"."history_position_changes" to "service_role";

grant trigger on table "public"."history_position_changes" to "service_role";

grant truncate on table "public"."history_position_changes" to "service_role";

grant update on table "public"."history_position_changes" to "service_role";

grant delete on table "public"."initial_ranking" to "anon";

grant insert on table "public"."initial_ranking" to "anon";

grant references on table "public"."initial_ranking" to "anon";

grant select on table "public"."initial_ranking" to "anon";

grant trigger on table "public"."initial_ranking" to "anon";

grant truncate on table "public"."initial_ranking" to "anon";

grant update on table "public"."initial_ranking" to "anon";

grant delete on table "public"."initial_ranking" to "authenticated";

grant insert on table "public"."initial_ranking" to "authenticated";

grant references on table "public"."initial_ranking" to "authenticated";

grant select on table "public"."initial_ranking" to "authenticated";

grant trigger on table "public"."initial_ranking" to "authenticated";

grant truncate on table "public"."initial_ranking" to "authenticated";

grant update on table "public"."initial_ranking" to "authenticated";

grant delete on table "public"."initial_ranking" to "service_role";

grant insert on table "public"."initial_ranking" to "service_role";

grant references on table "public"."initial_ranking" to "service_role";

grant select on table "public"."initial_ranking" to "service_role";

grant trigger on table "public"."initial_ranking" to "service_role";

grant truncate on table "public"."initial_ranking" to "service_role";

grant update on table "public"."initial_ranking" to "service_role";

grant delete on table "public"."maintenance_run_items" to "anon";

grant insert on table "public"."maintenance_run_items" to "anon";

grant references on table "public"."maintenance_run_items" to "anon";

grant select on table "public"."maintenance_run_items" to "anon";

grant trigger on table "public"."maintenance_run_items" to "anon";

grant truncate on table "public"."maintenance_run_items" to "anon";

grant update on table "public"."maintenance_run_items" to "anon";

grant delete on table "public"."maintenance_run_items" to "authenticated";

grant insert on table "public"."maintenance_run_items" to "authenticated";

grant references on table "public"."maintenance_run_items" to "authenticated";

grant select on table "public"."maintenance_run_items" to "authenticated";

grant trigger on table "public"."maintenance_run_items" to "authenticated";

grant truncate on table "public"."maintenance_run_items" to "authenticated";

grant update on table "public"."maintenance_run_items" to "authenticated";

grant delete on table "public"."maintenance_run_items" to "service_role";

grant insert on table "public"."maintenance_run_items" to "service_role";

grant references on table "public"."maintenance_run_items" to "service_role";

grant select on table "public"."maintenance_run_items" to "service_role";

grant trigger on table "public"."maintenance_run_items" to "service_role";

grant truncate on table "public"."maintenance_run_items" to "service_role";

grant update on table "public"."maintenance_run_items" to "service_role";

grant delete on table "public"."maintenance_runs" to "anon";

grant insert on table "public"."maintenance_runs" to "anon";

grant references on table "public"."maintenance_runs" to "anon";

grant select on table "public"."maintenance_runs" to "anon";

grant trigger on table "public"."maintenance_runs" to "anon";

grant truncate on table "public"."maintenance_runs" to "anon";

grant update on table "public"."maintenance_runs" to "anon";

grant delete on table "public"."maintenance_runs" to "authenticated";

grant insert on table "public"."maintenance_runs" to "authenticated";

grant references on table "public"."maintenance_runs" to "authenticated";

grant select on table "public"."maintenance_runs" to "authenticated";

grant trigger on table "public"."maintenance_runs" to "authenticated";

grant truncate on table "public"."maintenance_runs" to "authenticated";

grant update on table "public"."maintenance_runs" to "authenticated";

grant delete on table "public"."maintenance_runs" to "service_role";

grant insert on table "public"."maintenance_runs" to "service_role";

grant references on table "public"."maintenance_runs" to "service_role";

grant select on table "public"."maintenance_runs" to "service_role";

grant trigger on table "public"."maintenance_runs" to "service_role";

grant truncate on table "public"."maintenance_runs" to "service_role";

grant update on table "public"."maintenance_runs" to "service_role";

grant delete on table "public"."matches" to "anon";

grant insert on table "public"."matches" to "anon";

grant references on table "public"."matches" to "anon";

grant select on table "public"."matches" to "anon";

grant trigger on table "public"."matches" to "anon";

grant truncate on table "public"."matches" to "anon";

grant update on table "public"."matches" to "anon";

grant delete on table "public"."matches" to "authenticated";

grant insert on table "public"."matches" to "authenticated";

grant references on table "public"."matches" to "authenticated";

grant select on table "public"."matches" to "authenticated";

grant trigger on table "public"."matches" to "authenticated";

grant truncate on table "public"."matches" to "authenticated";

grant update on table "public"."matches" to "authenticated";

grant delete on table "public"."matches" to "service_role";

grant insert on table "public"."matches" to "service_role";

grant references on table "public"."matches" to "service_role";

grant select on table "public"."matches" to "service_role";

grant trigger on table "public"."matches" to "service_role";

grant truncate on table "public"."matches" to "service_role";

grant update on table "public"."matches" to "service_role";

grant delete on table "public"."notes" to "anon";

grant insert on table "public"."notes" to "anon";

grant references on table "public"."notes" to "anon";

grant select on table "public"."notes" to "anon";

grant trigger on table "public"."notes" to "anon";

grant truncate on table "public"."notes" to "anon";

grant update on table "public"."notes" to "anon";

grant delete on table "public"."notes" to "authenticated";

grant insert on table "public"."notes" to "authenticated";

grant references on table "public"."notes" to "authenticated";

grant select on table "public"."notes" to "authenticated";

grant trigger on table "public"."notes" to "authenticated";

grant truncate on table "public"."notes" to "authenticated";

grant update on table "public"."notes" to "authenticated";

grant delete on table "public"."notes" to "service_role";

grant insert on table "public"."notes" to "service_role";

grant references on table "public"."notes" to "service_role";

grant select on table "public"."notes" to "service_role";

grant trigger on table "public"."notes" to "service_role";

grant truncate on table "public"."notes" to "service_role";

grant update on table "public"."notes" to "service_role";

grant delete on table "public"."penalties" to "anon";

grant insert on table "public"."penalties" to "anon";

grant references on table "public"."penalties" to "anon";

grant select on table "public"."penalties" to "anon";

grant trigger on table "public"."penalties" to "anon";

grant truncate on table "public"."penalties" to "anon";

grant update on table "public"."penalties" to "anon";

grant delete on table "public"."penalties" to "authenticated";

grant insert on table "public"."penalties" to "authenticated";

grant references on table "public"."penalties" to "authenticated";

grant select on table "public"."penalties" to "authenticated";

grant trigger on table "public"."penalties" to "authenticated";

grant truncate on table "public"."penalties" to "authenticated";

grant update on table "public"."penalties" to "authenticated";

grant delete on table "public"."penalties" to "service_role";

grant insert on table "public"."penalties" to "service_role";

grant references on table "public"."penalties" to "service_role";

grant select on table "public"."penalties" to "service_role";

grant trigger on table "public"."penalties" to "service_role";

grant truncate on table "public"."penalties" to "service_role";

grant update on table "public"."penalties" to "service_role";

grant delete on table "public"."player_weekly_positions" to "anon";

grant insert on table "public"."player_weekly_positions" to "anon";

grant references on table "public"."player_weekly_positions" to "anon";

grant select on table "public"."player_weekly_positions" to "anon";

grant trigger on table "public"."player_weekly_positions" to "anon";

grant truncate on table "public"."player_weekly_positions" to "anon";

grant update on table "public"."player_weekly_positions" to "anon";

grant delete on table "public"."player_weekly_positions" to "authenticated";

grant insert on table "public"."player_weekly_positions" to "authenticated";

grant references on table "public"."player_weekly_positions" to "authenticated";

grant select on table "public"."player_weekly_positions" to "authenticated";

grant trigger on table "public"."player_weekly_positions" to "authenticated";

grant truncate on table "public"."player_weekly_positions" to "authenticated";

grant update on table "public"."player_weekly_positions" to "authenticated";

grant delete on table "public"."player_weekly_positions" to "service_role";

grant insert on table "public"."player_weekly_positions" to "service_role";

grant references on table "public"."player_weekly_positions" to "service_role";

grant select on table "public"."player_weekly_positions" to "service_role";

grant trigger on table "public"."player_weekly_positions" to "service_role";

grant truncate on table "public"."player_weekly_positions" to "service_role";

grant update on table "public"."player_weekly_positions" to "service_role";

grant delete on table "public"."players" to "anon";

grant insert on table "public"."players" to "anon";

grant references on table "public"."players" to "anon";

grant select on table "public"."players" to "anon";

grant trigger on table "public"."players" to "anon";

grant truncate on table "public"."players" to "anon";

grant update on table "public"."players" to "anon";

grant delete on table "public"."players" to "authenticated";

grant insert on table "public"."players" to "authenticated";

grant references on table "public"."players" to "authenticated";

grant select on table "public"."players" to "authenticated";

grant trigger on table "public"."players" to "authenticated";

grant truncate on table "public"."players" to "authenticated";

grant update on table "public"."players" to "authenticated";

grant delete on table "public"."players" to "service_role";

grant insert on table "public"."players" to "service_role";

grant references on table "public"."players" to "service_role";

grant select on table "public"."players" to "service_role";

grant trigger on table "public"."players" to "service_role";

grant truncate on table "public"."players" to "service_role";

grant update on table "public"."players" to "service_role";

grant delete on table "public"."ranking_positions" to "anon";

grant insert on table "public"."ranking_positions" to "anon";

grant references on table "public"."ranking_positions" to "anon";

grant select on table "public"."ranking_positions" to "anon";

grant trigger on table "public"."ranking_positions" to "anon";

grant truncate on table "public"."ranking_positions" to "anon";

grant update on table "public"."ranking_positions" to "anon";

grant delete on table "public"."ranking_positions" to "authenticated";

grant insert on table "public"."ranking_positions" to "authenticated";

grant references on table "public"."ranking_positions" to "authenticated";

grant select on table "public"."ranking_positions" to "authenticated";

grant trigger on table "public"."ranking_positions" to "authenticated";

grant truncate on table "public"."ranking_positions" to "authenticated";

grant update on table "public"."ranking_positions" to "authenticated";

grant delete on table "public"."ranking_positions" to "service_role";

grant insert on table "public"."ranking_positions" to "service_role";

grant references on table "public"."ranking_positions" to "service_role";

grant select on table "public"."ranking_positions" to "service_role";

grant trigger on table "public"."ranking_positions" to "service_role";

grant truncate on table "public"."ranking_positions" to "service_role";

grant update on table "public"."ranking_positions" to "service_role";

grant delete on table "public"."socis" to "anon";

grant insert on table "public"."socis" to "anon";

grant references on table "public"."socis" to "anon";

grant select on table "public"."socis" to "anon";

grant trigger on table "public"."socis" to "anon";

grant truncate on table "public"."socis" to "anon";

grant update on table "public"."socis" to "anon";

grant delete on table "public"."socis" to "authenticated";

grant insert on table "public"."socis" to "authenticated";

grant references on table "public"."socis" to "authenticated";

grant select on table "public"."socis" to "authenticated";

grant trigger on table "public"."socis" to "authenticated";

grant truncate on table "public"."socis" to "authenticated";

grant update on table "public"."socis" to "authenticated";

grant delete on table "public"."socis" to "service_role";

grant insert on table "public"."socis" to "service_role";

grant references on table "public"."socis" to "service_role";

grant select on table "public"."socis" to "service_role";

grant trigger on table "public"."socis" to "service_role";

grant truncate on table "public"."socis" to "service_role";

grant update on table "public"."socis" to "service_role";

grant delete on table "public"."waiting_list" to "anon";

grant insert on table "public"."waiting_list" to "anon";

grant references on table "public"."waiting_list" to "anon";

grant select on table "public"."waiting_list" to "anon";

grant trigger on table "public"."waiting_list" to "anon";

grant truncate on table "public"."waiting_list" to "anon";

grant update on table "public"."waiting_list" to "anon";

grant delete on table "public"."waiting_list" to "authenticated";

grant insert on table "public"."waiting_list" to "authenticated";

grant references on table "public"."waiting_list" to "authenticated";

grant select on table "public"."waiting_list" to "authenticated";

grant trigger on table "public"."waiting_list" to "authenticated";

grant truncate on table "public"."waiting_list" to "authenticated";

grant update on table "public"."waiting_list" to "authenticated";

grant delete on table "public"."waiting_list" to "service_role";

grant insert on table "public"."waiting_list" to "service_role";

grant references on table "public"."waiting_list" to "service_role";

grant select on table "public"."waiting_list" to "service_role";

grant trigger on table "public"."waiting_list" to "service_role";

grant truncate on table "public"."waiting_list" to "service_role";

grant update on table "public"."waiting_list" to "service_role";


  create policy "sel_admins_public"
  on "public"."admins"
  as permissive
  for select
  to public
using (true);



  create policy "un usuari pot veure si és admin"
  on "public"."admins"
  as permissive
  for select
  to authenticated
using ((lower(email) = lower((auth.jwt() ->> 'email'::text))));



  create policy "nomes admins poden update config"
  on "public"."app_settings"
  as permissive
  for update
  to authenticated
using ((EXISTS ( SELECT 1
   FROM admins a
  WHERE (a.email = (auth.jwt() ->> 'email'::text)))))
with check ((EXISTS ( SELECT 1
   FROM admins a
  WHERE (a.email = (auth.jwt() ->> 'email'::text)))));



  create policy "qualsevol pot veure config"
  on "public"."app_settings"
  as permissive
  for select
  to anon, authenticated
using (true);



  create policy "Admins can insert challenges"
  on "public"."challenges"
  as permissive
  for insert
  to authenticated
with check ((EXISTS ( SELECT 1
   FROM admins
  WHERE (admins.email = (auth.jwt() ->> 'email'::text)))));



  create policy "Admins can update challenges"
  on "public"."challenges"
  as permissive
  for update
  to authenticated
using ((EXISTS ( SELECT 1
   FROM admins
  WHERE (admins.email = (auth.jwt() ->> 'email'::text)))))
with check ((EXISTS ( SELECT 1
   FROM admins
  WHERE (admins.email = (auth.jwt() ->> 'email'::text)))));



  create policy "Authenticated users can select challenges"
  on "public"."challenges"
  as permissive
  for select
  to authenticated
using (true);



  create policy "Players can insert challenges"
  on "public"."challenges"
  as permissive
  for insert
  to public
with check (can_create_challenge(event_id, reptador_id, reptat_id));



  create policy "admin update challenges"
  on "public"."challenges"
  as permissive
  for update
  to authenticated
using (is_admin(auth.email()))
with check (is_admin(auth.email()));



  create policy "admins poden UPDATE challenges"
  on "public"."challenges"
  as permissive
  for update
  to authenticated
using ((EXISTS ( SELECT 1
   FROM admins a
  WHERE (a.email = (auth.jwt() ->> 'email'::text)))))
with check ((EXISTS ( SELECT 1
   FROM admins a
  WHERE (a.email = (auth.jwt() ->> 'email'::text)))));



  create policy "admins_update_challenges"
  on "public"."challenges"
  as permissive
  for update
  to authenticated
using ((auth.email() IN ( SELECT admins.email
   FROM admins)))
with check ((auth.email() IN ( SELECT admins.email
   FROM admins)));



  create policy "all_ch_admin"
  on "public"."challenges"
  as permissive
  for all
  to public
using (is_admin())
with check (is_admin());



  create policy "challenges_insert_auth"
  on "public"."challenges"
  as permissive
  for insert
  to authenticated
with check (true);



  create policy "challenges_select_auth"
  on "public"."challenges"
  as permissive
  for select
  to authenticated
using (true);



  create policy "ins_ch_user"
  on "public"."challenges"
  as permissive
  for insert
  to authenticated
with check ((auth.uid() IS NOT NULL));



  create policy "sel_ch"
  on "public"."challenges"
  as permissive
  for select
  to public
using (true);



  create policy "upd_challenges_by_reptat"
  on "public"."challenges"
  as permissive
  for update
  to authenticated
using (((estat = 'proposat'::challenge_state) AND (reptat_id = current_player_id())))
with check ((estat = ANY (ARRAY['acceptat'::challenge_state, 'refusat'::challenge_state])));



  create policy "Authenticated users can select events"
  on "public"."events"
  as permissive
  for select
  to authenticated
using (true);



  create policy "anon can select events"
  on "public"."events"
  as permissive
  for select
  to anon
using (true);



  create policy "auth can select events"
  on "public"."events"
  as permissive
  for select
  to authenticated
using (true);



  create policy "Authenticated users can select history_position_changes"
  on "public"."history_position_changes"
  as permissive
  for select
  to authenticated
using (true);



  create policy "admin insert history"
  on "public"."history_position_changes"
  as permissive
  for insert
  to authenticated
with check (is_admin((auth.jwt() ->> 'email'::text)));



  create policy "admins poden inserir history_position_changes"
  on "public"."history_position_changes"
  as permissive
  for insert
  to authenticated
with check ((EXISTS ( SELECT 1
   FROM admins a
  WHERE (a.email = (auth.jwt() ->> 'email'::text)))));



  create policy "all_hist_admin"
  on "public"."history_position_changes"
  as permissive
  for all
  to public
using (is_admin())
with check (is_admin());



  create policy "sel_hist"
  on "public"."history_position_changes"
  as permissive
  for select
  to public
using (true);



  create policy "Authenticated users can select initial_ranking"
  on "public"."initial_ranking"
  as permissive
  for select
  to authenticated
using (true);



  create policy "admin all initial_ranking"
  on "public"."initial_ranking"
  as permissive
  for all
  to authenticated
using (is_admin((auth.jwt() ->> 'email'::text)))
with check (is_admin((auth.jwt() ->> 'email'::text)));



  create policy "Authenticated users can select matches"
  on "public"."matches"
  as permissive
  for select
  to authenticated
using (true);



  create policy "admin insert matches"
  on "public"."matches"
  as permissive
  for insert
  to authenticated
with check (is_admin((auth.jwt() ->> 'email'::text)));



  create policy "admins poden inserir matches"
  on "public"."matches"
  as permissive
  for insert
  to authenticated
with check ((EXISTS ( SELECT 1
   FROM admins a
  WHERE (a.email = (auth.jwt() ->> 'email'::text)))));



  create policy "all_matches_admin"
  on "public"."matches"
  as permissive
  for all
  to public
using (is_admin())
with check (is_admin());



  create policy "sel_matches"
  on "public"."matches"
  as permissive
  for select
  to public
using (true);



  create policy "anonymous can read notes during dev"
  on "public"."notes"
  as permissive
  for select
  to anon
using (true);



  create policy "only owners read/write their notes"
  on "public"."notes"
  as permissive
  for all
  to authenticated
using ((auth.uid() = user_id))
with check ((auth.uid() = user_id));



  create policy "admins poden INSERT a penalties"
  on "public"."penalties"
  as permissive
  for insert
  to authenticated
with check ((EXISTS ( SELECT 1
   FROM admins a
  WHERE (a.email = (auth.jwt() ->> 'email'::text)))));



  create policy "all_pens_admin"
  on "public"."penalties"
  as permissive
  for all
  to public
using (is_admin())
with check (is_admin());



  create policy "sel_pens"
  on "public"."penalties"
  as permissive
  for select
  to public
using (is_admin());



  create policy "Authenticated users can select player_weekly_positions"
  on "public"."player_weekly_positions"
  as permissive
  for select
  to authenticated
using (true);



  create policy "Authenticated users can select players"
  on "public"."players"
  as permissive
  for select
  to authenticated
using (true);



  create policy "admin update players"
  on "public"."players"
  as permissive
  for update
  to authenticated
using (is_admin((auth.jwt() ->> 'email'::text)))
with check (is_admin((auth.jwt() ->> 'email'::text)));



  create policy "anon can select players"
  on "public"."players"
  as permissive
  for select
  to anon
using (true);



  create policy "auth can select players"
  on "public"."players"
  as permissive
  for select
  to authenticated
using (true);



  create policy "sel_players"
  on "public"."players"
  as permissive
  for select
  to public
using (true);



  create policy "upd_players_admin"
  on "public"."players"
  as permissive
  for all
  to public
using (is_admin())
with check (is_admin());



  create policy "Authenticated users can select ranking_positions"
  on "public"."ranking_positions"
  as permissive
  for select
  to authenticated
using (true);



  create policy "admin delete ranking_positions"
  on "public"."ranking_positions"
  as permissive
  for delete
  to authenticated
using (is_admin((auth.jwt() ->> 'email'::text)));



  create policy "admin insert ranking_positions"
  on "public"."ranking_positions"
  as permissive
  for insert
  to authenticated
with check (is_admin((auth.jwt() ->> 'email'::text)));



  create policy "admin update ranking_positions"
  on "public"."ranking_positions"
  as permissive
  for update
  to authenticated
using (is_admin((auth.jwt() ->> 'email'::text)))
with check (is_admin((auth.jwt() ->> 'email'::text)));



  create policy "all_ranking_admin"
  on "public"."ranking_positions"
  as permissive
  for all
  to public
using (is_admin())
with check (is_admin());



  create policy "anon can select ranking"
  on "public"."ranking_positions"
  as permissive
  for select
  to anon
using (true);



  create policy "auth can select ranking"
  on "public"."ranking_positions"
  as permissive
  for select
  to authenticated
using (true);



  create policy "sel_ranking"
  on "public"."ranking_positions"
  as permissive
  for select
  to public
using (true);



  create policy "Authenticated users can select waiting_list"
  on "public"."waiting_list"
  as permissive
  for select
  to authenticated
using (true);



  create policy "admin all waiting_list"
  on "public"."waiting_list"
  as permissive
  for all
  to authenticated
using (is_admin((auth.jwt() ->> 'email'::text)))
with check (is_admin((auth.jwt() ->> 'email'::text)));



  create policy "all_wait_admin"
  on "public"."waiting_list"
  as permissive
  for all
  to public
using (is_admin())
with check (is_admin());



  create policy "anon can select waiting"
  on "public"."waiting_list"
  as permissive
  for select
  to anon
using (true);



  create policy "auth can select waiting"
  on "public"."waiting_list"
  as permissive
  for select
  to authenticated
using (true);



  create policy "sel_wait"
  on "public"."waiting_list"
  as permissive
  for select
  to public
using (true);


CREATE TRIGGER trg_admins_email_lower BEFORE INSERT OR UPDATE ON public.admins FOR EACH ROW EXECUTE FUNCTION _admins_email_lowercase();

CREATE TRIGGER trg_app_settings_u BEFORE UPDATE ON public.app_settings FOR EACH ROW EXECUTE FUNCTION _app_settings_set_updated_at();

CREATE TRIGGER inc_reprogramacions BEFORE UPDATE OF data_programada ON public.challenges FOR EACH ROW EXECUTE FUNCTION trg_inc_reprogramacions();

CREATE TRIGGER trg_challenges_accept BEFORE UPDATE ON public.challenges FOR EACH ROW WHEN (((new.estat = 'acceptat'::challenge_state) AND (old.estat IS DISTINCT FROM 'acceptat'::challenge_state))) EXECUTE FUNCTION trg_challenges_accept();

CREATE TRIGGER trg_challenges_set_positions BEFORE INSERT ON public.challenges FOR EACH ROW EXECUTE FUNCTION fn_challenges_set_positions();

CREATE TRIGGER trg_challenges_validate BEFORE INSERT ON public.challenges FOR EACH ROW EXECUTE FUNCTION trg_challenges_validate();

CREATE TRIGGER trg_enforce_max_rank_gap BEFORE INSERT OR UPDATE OF reptador_id, reptat_id, event_id ON public.challenges FOR EACH ROW EXECUTE FUNCTION enforce_max_rank_gap();

CREATE TRIGGER trg_matches_apply_result AFTER INSERT ON public.matches FOR EACH ROW EXECUTE FUNCTION trg_matches_apply_result();

CREATE TRIGGER trg_matches_finalize AFTER INSERT ON public.matches FOR EACH ROW EXECUTE FUNCTION fn_matches_finalize();

CREATE TRIGGER trg_guard_ranking BEFORE INSERT OR UPDATE ON public.ranking_positions FOR EACH ROW EXECUTE FUNCTION guard_unique_membership();

CREATE TRIGGER trg_guard_waiting_list BEFORE INSERT OR UPDATE ON public.waiting_list FOR EACH ROW EXECUTE FUNCTION guard_unique_membership();


