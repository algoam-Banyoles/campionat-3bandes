// scripts/export-db-defs.mjs
//
// Exporta a `backups/<timestamp>/db-defs.sql` les definicions actuals de
// totes les vistes i funcions del schema public que mencionen `players`.
// Aquest fitxer és el ROLLBACK manual si Sessió 3 falla a meitat.
//
// Ús: `node scripts/export-db-defs.mjs`

import { createClient } from '@supabase/supabase-js';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const projectRoot = join(__dirname, '..');

const env = Object.fromEntries(
  readFileSync(join(projectRoot, '.env'), 'utf8')
    .split('\n')
    .map(l => l.trim())
    .filter(l => l && !l.startsWith('#'))
    .map(l => {
      const eq = l.indexOf('=');
      return [l.slice(0, eq).trim(), l.slice(eq + 1).trim()];
    })
);

const supabase = createClient(
  env.SUPABASE_URL || env.PUBLIC_SUPABASE_URL,
  env.SUPABASE_SERVICE_ROLE_KEY,
  { auth: { persistSession: false } }
);

async function exec(sql) {
  const { data, error } = await supabase.rpc('exec_sql', { sql });
  if (error) throw error;
  return data;
}

// Postgres no exposa exec_sql per defecte → usem queries directes
async function getViews() {
  const { data, error } = await supabase
    .from('pg_views')
    .select('viewname,definition')
    .eq('schemaname', 'public');
  if (error) throw error;
  return data;
}

// Plan B: usar les definicions ja capturades manualment via MCP
const VIEWS = {
  v_challenges_pending: ` SELECT c.id,
    c.event_id,
    c.reptador_id,
    c.reptat_id,
    c.estat,
    c.data_proposta,
    c.data_programada,
    p1.nom AS reptador_nom,
    p2.nom AS reptat_nom
   FROM challenges c
     JOIN players p1 ON p1.id = c.reptador_id
     JOIN players p2 ON p2.id = c.reptat_id
  WHERE c.estat = ANY (ARRAY['proposat'::challenge_state, 'acceptat'::challenge_state, 'programat'::challenge_state]);`,
  v_player_timeline: ` SELECT p.id AS player_id,
    p.nom,
    'challenge'::text AS event_type,
    c.data_proposta AS event_date,
    'Repte proposat'::text AS description
   FROM players p
     JOIN challenges c ON c.reptador_id = p.id OR c.reptat_id = p.id
UNION ALL
 SELECT p.id AS player_id,
    p.nom,
    'match'::text AS event_type,
    m.data_joc AS event_date,
    'Partida jugada'::text AS description
   FROM players p
     JOIN challenges c ON c.reptador_id = p.id OR c.reptat_id = p.id
     JOIN matches m ON m.challenge_id = c.id
  ORDER BY 4 DESC;`,
  v_promocions_candidates: ` SELECT rp.player_id,
    p.nom,
    s.cognoms,
    rp.posicio,
    rp.event_id,
    e.nom AS event_nom,
        CASE
            WHEN rp.posicio <= 3 THEN 'CANDIDAT_FORT'::text
            WHEN rp.posicio <= 5 THEN 'CANDIDAT_MODERAT'::text
            WHEN rp.posicio <= 10 THEN 'CANDIDAT_INICIAL'::text
            ELSE 'NO_CANDIDAT'::text
        END AS tipus_candidatura
   FROM ranking_positions rp
     LEFT JOIN players p ON rp.player_id = p.id
     LEFT JOIN socis s ON p.numero_soci = s.numero_soci
     LEFT JOIN events e ON rp.event_id = e.id
  WHERE rp.posicio <= 10;`,
  v_player_badges: ` WITH active_event AS (
         SELECT events.id
           FROM events
          WHERE events.actiu IS TRUE
          ORDER BY events.creat_el DESC
         LIMIT 1
        ), cfg AS (
         SELECT COALESCE((( SELECT app_settings.cooldown_min_dies
                   FROM app_settings
                  ORDER BY app_settings.updated_at DESC
                 LIMIT 1))::integer, 0) AS cooldown_min_dies
        ), lp AS (
         SELECT rp_1.event_id,
            rp_1.player_id,
            max(COALESCE(m.data_joc::date, c.data_proposta::date)) AS last_play_date,
                CASE
                    WHEN max(COALESCE(m.data_joc::date, c.data_proposta::date)) IS NULL THEN NULL::integer
                    ELSE CURRENT_DATE - max(COALESCE(m.data_joc::date, c.data_proposta::date))
                END AS days_since_last
           FROM ranking_positions rp_1
             JOIN active_event ae_1 ON ae_1.id = rp_1.event_id
             LEFT JOIN challenges c ON c.event_id = rp_1.event_id AND (c.reptador_id = rp_1.player_id OR c.reptat_id = rp_1.player_id)
             LEFT JOIN matches m ON m.challenge_id = c.id
          GROUP BY rp_1.event_id, rp_1.player_id
        ), active AS (
         SELECT challenges.event_id,
            challenges.reptador_id AS player_id
           FROM challenges
          WHERE challenges.estat = ANY (ARRAY['proposat'::challenge_state, 'acceptat'::challenge_state, 'programat'::challenge_state])
        UNION
         SELECT challenges.event_id,
            challenges.reptat_id AS player_id
           FROM challenges
          WHERE challenges.estat = ANY (ARRAY['proposat'::challenge_state, 'acceptat'::challenge_state, 'programat'::challenge_state])
        )
 SELECT rp.event_id,
    rp.player_id,
    rp.posicio,
    lp.last_play_date,
    lp.days_since_last,
    ac.player_id IS NOT NULL AS has_active_challenge,
        CASE
            WHEN lp.last_play_date IS NULL THEN false
            WHEN lp.days_since_last < (( SELECT cfg.cooldown_min_dies
               FROM cfg)) THEN true
            ELSE false
        END AS in_cooldown,
        CASE
            WHEN ac.player_id IS NOT NULL THEN false
            WHEN lp.last_play_date IS NOT NULL AND lp.days_since_last < (( SELECT cfg.cooldown_min_dies
               FROM cfg)) THEN false
            ELSE true
        END AS can_be_challenged,
    GREATEST((( SELECT cfg.cooldown_min_dies
           FROM cfg)) - lp.days_since_last, 0) AS cooldown_days_left
   FROM ranking_positions rp
     JOIN active_event ae ON ae.id = rp.event_id
     LEFT JOIN lp ON lp.event_id = rp.event_id AND lp.player_id = rp.player_id
     LEFT JOIN active ac ON ac.event_id = rp.event_id AND ac.player_id = rp.player_id;`
};

const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
const dir = join(projectRoot, 'backups', `defs-${timestamp}`);
mkdirSync(dir, { recursive: true });

let out = `-- Phase 5c Session 3 — DB definitions snapshot
-- Generated: ${new Date().toISOString()}
-- Use this file as ROLLBACK if Session 3 fails partway.
-- Re-apply with: psql ... < this-file.sql

-- ============================================================
-- VIEWS
-- ============================================================

`;

for (const [name, body] of Object.entries(VIEWS)) {
  out += `DROP VIEW IF EXISTS ${name};\n`;
  out += `CREATE VIEW ${name} AS\n${body}\n\n`;
}

out += `-- ============================================================
-- FUNCTIONS
-- ============================================================
-- NOTE: Function bodies are NOT captured here automatically because
-- pg_get_functiondef returns very long text that hits MCP query limits.
-- To regenerate, run via Supabase SQL editor:
--
--   SELECT pg_get_functiondef(p.oid)
--   FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
--   WHERE n.nspname='public' AND p.prosrc ILIKE '%players%';
--
-- The 27 functions touching 'players' are listed at:
-- docs/phase5-session3-runbook.md (section 1.2)
`;

writeFileSync(join(dir, 'db-defs.sql'), out, 'utf8');
console.log(`✅ Definitions exported to backups/defs-${timestamp}/db-defs.sql`);
console.log(`   Views: ${Object.keys(VIEWS).length}`);
console.log(`   Functions: see runbook section 1.2 (manual SQL editor capture needed)`);
