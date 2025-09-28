-- Migration: Consolidate players and socis tables for multi-event architecture
-- This migration eliminates redundancy between players and socis tables
-- Event-specific data moves to ranking_positions and waiting_list tables

BEGIN;

-- 1. Add missing columns to socis table (general member data)
ALTER TABLE public.socis ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid();
ALTER TABLE public.socis ADD COLUMN IF NOT EXISTS club text;
ALTER TABLE public.socis ADD COLUMN IF NOT EXISTS avatar_url text;
ALTER TABLE public.socis ADD COLUMN IF NOT EXISTS creat_el timestamp with time zone DEFAULT now();
ALTER TABLE public.socis ADD COLUMN IF NOT EXISTS actualitzat_el timestamp with time zone;

-- Add telefon and de_baixa if they don't exist
ALTER TABLE public.socis ADD COLUMN IF NOT EXISTS telefon text;
ALTER TABLE public.socis ADD COLUMN IF NOT EXISTS de_baixa boolean DEFAULT false;

-- 2. Add event-specific columns to ranking_positions and waiting_list
ALTER TABLE public.ranking_positions ADD COLUMN IF NOT EXISTS mitjana numeric(6,3);
ALTER TABLE public.ranking_positions ADD COLUMN IF NOT EXISTS estat player_state DEFAULT 'actiu'::player_state;
ALTER TABLE public.ranking_positions ADD COLUMN IF NOT EXISTS data_ultim_repte date;

ALTER TABLE public.waiting_list ADD COLUMN IF NOT EXISTS estat player_state DEFAULT 'actiu'::player_state;
ALTER TABLE public.waiting_list ADD COLUMN IF NOT EXISTS data_ultim_repte date;

-- 3. Create unique constraint on id for socis
CREATE UNIQUE INDEX IF NOT EXISTS socis_id_key ON public.socis USING btree (id);

-- 4. Migrate data from players to socis
-- Update existing socis with player general data where numero_soci matches
UPDATE public.socis
SET
    id = p.id,
    club = p.club,
    avatar_url = p.avatar_url,
    creat_el = p.creat_el,
    actualitzat_el = now()
FROM public.players p
WHERE public.socis.numero_soci = p.numero_soci;

-- Insert players that don't have a corresponding soci (edge case)
INSERT INTO public.socis (
    numero_soci, nom, cognoms, email, telefon, de_baixa,
    id, club, avatar_url, creat_el
)
SELECT
    COALESCE(p.numero_soci, (SELECT COALESCE(MAX(numero_soci), 0) + 1 FROM public.socis)),
    p.nom,
    '', -- cognoms empty since players doesn't have this split
    p.email,
    null, -- telefon
    false, -- de_baixa
    p.id,
    p.club,
    p.avatar_url,
    p.creat_el
FROM public.players p
WHERE p.numero_soci IS NULL
   OR p.numero_soci NOT IN (SELECT numero_soci FROM public.socis);

-- 5. Migrate event-specific data to ranking_positions
UPDATE public.ranking_positions
SET
    mitjana = p.mitjana,
    estat = p.estat,
    data_ultim_repte = p.data_ultim_repte
FROM public.players p
WHERE ranking_positions.player_id = p.id;

-- 6. Migrate event-specific data to waiting_list
UPDATE public.waiting_list
SET
    estat = p.estat,
    data_ultim_repte = p.data_ultim_repte
FROM public.players p
WHERE waiting_list.player_id = p.id;

-- 7. Update foreign key references from players.id to socis.id
-- Add temporary columns to store the new socis.id references
ALTER TABLE public.challenges ADD COLUMN IF NOT EXISTS reptador_soci_id uuid;
ALTER TABLE public.challenges ADD COLUMN IF NOT EXISTS reptat_soci_id uuid;

ALTER TABLE public.history_position_changes ADD COLUMN IF NOT EXISTS player_soci_id uuid;
ALTER TABLE public.initial_ranking ADD COLUMN IF NOT EXISTS player_soci_id uuid;
ALTER TABLE public.penalties ADD COLUMN IF NOT EXISTS player_soci_id uuid;
ALTER TABLE public.player_weekly_positions ADD COLUMN IF NOT EXISTS player_soci_id uuid;
ALTER TABLE public.ranking_positions ADD COLUMN IF NOT EXISTS player_soci_id uuid;
ALTER TABLE public.waiting_list ADD COLUMN IF NOT EXISTS player_soci_id uuid;

-- Update the temporary columns with corresponding socis.id
UPDATE public.challenges
SET reptador_soci_id = s.id
FROM public.socis s, public.players p
WHERE challenges.reptador_id = p.id AND p.numero_soci = s.numero_soci;

UPDATE public.challenges
SET reptat_soci_id = s.id
FROM public.socis s, public.players p
WHERE challenges.reptat_id = p.id AND p.numero_soci = s.numero_soci;

UPDATE public.history_position_changes
SET player_soci_id = s.id
FROM public.socis s, public.players p
WHERE history_position_changes.player_id = p.id AND p.numero_soci = s.numero_soci;

UPDATE public.initial_ranking
SET player_soci_id = s.id
FROM public.socis s, public.players p
WHERE initial_ranking.player_id = p.id AND p.numero_soci = s.numero_soci;

UPDATE public.penalties
SET player_soci_id = s.id
FROM public.socis s, public.players p
WHERE penalties.player_id = p.id AND p.numero_soci = s.numero_soci;

UPDATE public.player_weekly_positions
SET player_soci_id = s.id
FROM public.socis s, public.players p
WHERE player_weekly_positions.player_id = p.id AND p.numero_soci = s.numero_soci;

UPDATE public.ranking_positions
SET player_soci_id = s.id
FROM public.socis s, public.players p
WHERE ranking_positions.player_id = p.id AND p.numero_soci = s.numero_soci;

UPDATE public.waiting_list
SET player_soci_id = s.id
FROM public.socis s, public.players p
WHERE waiting_list.player_id = p.id AND p.numero_soci = s.numero_soci;

-- 8. Drop views and policies that depend on the old columns (use CASCADE to drop all dependencies)
DROP VIEW IF EXISTS public.v_challenges_pending CASCADE;
DROP VIEW IF EXISTS public.v_player_badges CASCADE;
DROP VIEW IF EXISTS public.v_player_timeline CASCADE;
DROP VIEW IF EXISTS public.v_ranking CASCADE;
DROP VIEW IF EXISTS public.v_position_changes CASCADE;
DROP POLICY IF EXISTS "Players can insert challenges" ON public.challenges;
DROP POLICY IF EXISTS "upd_challenges_by_reptat" ON public.challenges;
DROP TRIGGER IF EXISTS trg_enforce_max_rank_gap ON public.challenges;

-- 9. Drop old foreign key constraints
ALTER TABLE public.challenges DROP CONSTRAINT IF EXISTS challenges_reptador_id_fkey;
ALTER TABLE public.challenges DROP CONSTRAINT IF EXISTS challenges_reptat_id_fkey;
ALTER TABLE public.history_position_changes DROP CONSTRAINT IF EXISTS history_position_changes_player_id_fkey;
ALTER TABLE public.initial_ranking DROP CONSTRAINT IF EXISTS initial_ranking_player_id_fkey;
ALTER TABLE public.penalties DROP CONSTRAINT IF EXISTS penalties_player_id_fkey;
ALTER TABLE public.player_weekly_positions DROP CONSTRAINT IF EXISTS player_weekly_positions_player_id_fkey;
ALTER TABLE public.ranking_positions DROP CONSTRAINT IF EXISTS ranking_positions_player_id_fkey;
ALTER TABLE public.waiting_list DROP CONSTRAINT IF EXISTS waiting_list_player_id_fkey;

-- 10. Rename columns (drop old, rename new)
ALTER TABLE public.challenges DROP COLUMN IF EXISTS reptador_id;
ALTER TABLE public.challenges DROP COLUMN IF EXISTS reptat_id;
ALTER TABLE public.challenges RENAME COLUMN reptador_soci_id TO reptador_id;
ALTER TABLE public.challenges RENAME COLUMN reptat_soci_id TO reptat_id;

ALTER TABLE public.history_position_changes DROP COLUMN IF EXISTS player_id;
ALTER TABLE public.history_position_changes RENAME COLUMN player_soci_id TO player_id;

ALTER TABLE public.initial_ranking DROP COLUMN IF EXISTS player_id;
ALTER TABLE public.initial_ranking RENAME COLUMN player_soci_id TO player_id;

ALTER TABLE public.penalties DROP COLUMN IF EXISTS player_id;
ALTER TABLE public.penalties RENAME COLUMN player_soci_id TO player_id;

ALTER TABLE public.player_weekly_positions DROP COLUMN IF EXISTS player_id;
ALTER TABLE public.player_weekly_positions RENAME COLUMN player_soci_id TO player_id;

ALTER TABLE public.ranking_positions DROP COLUMN IF EXISTS player_id;
ALTER TABLE public.ranking_positions RENAME COLUMN player_soci_id TO player_id;

ALTER TABLE public.waiting_list DROP COLUMN IF EXISTS player_id;
ALTER TABLE public.waiting_list RENAME COLUMN player_soci_id TO player_id;

-- 11. Add new foreign key constraints pointing to socis
ALTER TABLE public.challenges ADD CONSTRAINT challenges_reptador_id_fkey
    FOREIGN KEY (reptador_id) REFERENCES socis(id) ON DELETE RESTRICT;
ALTER TABLE public.challenges ADD CONSTRAINT challenges_reptat_id_fkey
    FOREIGN KEY (reptat_id) REFERENCES socis(id) ON DELETE RESTRICT;

ALTER TABLE public.history_position_changes ADD CONSTRAINT history_position_changes_player_id_fkey
    FOREIGN KEY (player_id) REFERENCES socis(id) ON DELETE CASCADE;

ALTER TABLE public.initial_ranking ADD CONSTRAINT initial_ranking_player_id_fkey
    FOREIGN KEY (player_id) REFERENCES socis(id) ON DELETE RESTRICT;

ALTER TABLE public.penalties ADD CONSTRAINT penalties_player_id_fkey
    FOREIGN KEY (player_id) REFERENCES socis(id) ON DELETE CASCADE;

ALTER TABLE public.player_weekly_positions ADD CONSTRAINT player_weekly_positions_player_id_fkey
    FOREIGN KEY (player_id) REFERENCES socis(id);

ALTER TABLE public.ranking_positions ADD CONSTRAINT ranking_positions_player_id_fkey
    FOREIGN KEY (player_id) REFERENCES socis(id) ON DELETE RESTRICT;

ALTER TABLE public.waiting_list ADD CONSTRAINT waiting_list_player_id_fkey
    FOREIGN KEY (player_id) REFERENCES socis(id) ON DELETE CASCADE;

-- 12. Drop the players table
DROP TABLE IF EXISTS public.players CASCADE;

-- 13. Add constraints and indexes for the new structure
-- Drop the old primary key and set the new one
ALTER TABLE public.socis DROP CONSTRAINT socis_pkey;
ALTER TABLE public.socis ADD CONSTRAINT socis_id_pk PRIMARY KEY USING INDEX socis_id_key;

-- Update email constraint to allow nulls but ensure uniqueness when not null
ALTER TABLE public.socis DROP CONSTRAINT IF EXISTS socis_email_key;
CREATE UNIQUE INDEX socis_email_key ON public.socis (email) WHERE email IS NOT NULL;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_socis_de_baixa ON public.socis USING btree (de_baixa) WHERE de_baixa = false;
CREATE INDEX IF NOT EXISTS idx_ranking_positions_estat ON public.ranking_positions USING btree (estat);
CREATE INDEX IF NOT EXISTS idx_ranking_positions_data_ultim_repte ON public.ranking_positions USING btree (data_ultim_repte);
CREATE INDEX IF NOT EXISTS idx_waiting_list_estat ON public.waiting_list USING btree (estat);
CREATE INDEX IF NOT EXISTS idx_waiting_list_data_ultim_repte ON public.waiting_list USING btree (data_ultim_repte);

-- 14. Recreate views and policies with the new schema
CREATE OR REPLACE VIEW public.v_challenges_pending AS
SELECT
    id,
    event_id,
    reptador_id,
    reptat_id,
    estat::text AS estat,
    data_proposta,
    data_acceptacio,
    data_programada,
    CASE
        WHEN estat = 'proposat'::challenge_state THEN EXTRACT(day FROM now() - data_proposta)::integer
        WHEN estat = 'acceptat'::challenge_state THEN EXTRACT(day FROM now() - data_acceptacio)::integer
        ELSE NULL::integer
    END AS dies_transcorreguts
FROM challenges c
WHERE estat = ANY (ARRAY['proposat'::challenge_state, 'acceptat'::challenge_state]);

-- Add back the policy (now references socis)
CREATE POLICY "Players can insert challenges" ON public.challenges
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = reptador_id);

-- 15. Update player_state enum if needed (ensure it exists)
DO $$ BEGIN
    CREATE TYPE player_state AS ENUM ('actiu', 'inactiu', 'pre_inactiu', 'baixa');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

COMMIT;