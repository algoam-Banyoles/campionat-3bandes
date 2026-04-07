// scripts/backup-db.mjs
//
// Dump lògic de totes les taules crítiques abans del refactor de Fase 5c.
// Usa la service_role key del .env per saltar RLS i llegir-ho tot.
// Resultat: un fitxer JSON per taula a `backups/<timestamp>/<taula>.json`.
//
// Ús: `node scripts/backup-db.mjs`

import { createClient } from '@supabase/supabase-js';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const projectRoot = join(__dirname, '..');

// Llegim .env manualment perquè no volem dependre de cap llibreria
const envPath = join(projectRoot, '.env');
const envContent = readFileSync(envPath, 'utf8');
const env = Object.fromEntries(
  envContent
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith('#'))
    .map((line) => {
      const eq = line.indexOf('=');
      return [line.slice(0, eq).trim(), line.slice(eq + 1).trim()];
    })
);

const SUPABASE_URL = env.SUPABASE_URL || env.PUBLIC_SUPABASE_URL;
const SERVICE_KEY = env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error('❌ Falten SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY al .env');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { persistSession: false }
});

// Taules a fer dump. Inclou totes les que tenen FK cap a `players` o
// són crítiques per al refactor de Fase 5c.
const TABLES = [
  // Identitat
  'socis',
  'players',
  'admins',
  // Domini comú
  'events',
  'categories',
  'inscripcions',
  // Campionat continu
  'challenges',
  'matches',
  'ranking_positions',
  'initial_ranking',
  'waiting_list',
  'penalties',
  'history_position_changes',
  'player_weekly_positions',
  // Campionats socials
  'classificacions',
  'calendari_partides',
  // Mitjanes
  'mitjanes_historiques',
  // Hàndicap
  'handicap_config',
  'handicap_participants',
  'handicap_matches',
  'handicap_bracket_slots',
  // Calendari club
  'esdeveniments_club',
  'configuracio_calendari',
  // Contingut
  'page_content',
  'multimedia_links',
  'notes',
  // Manteniment
  'maintenance_runs',
  'maintenance_run_items'
];

const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
const backupDir = join(projectRoot, 'backups', timestamp);
mkdirSync(backupDir, { recursive: true });

console.log(`📦 Dumping ${TABLES.length} taules a backups/${timestamp}/\n`);

let totalRows = 0;
let totalSize = 0;
const errors = [];

for (const table of TABLES) {
  try {
    // Bucle de paginació per si la taula és gran (límit Supabase 1000 rows)
    const PAGE = 1000;
    let from = 0;
    const allRows = [];
    while (true) {
      const { data, error } = await supabase
        .from(table)
        .select('*')
        .range(from, from + PAGE - 1);
      if (error) throw error;
      if (!data || data.length === 0) break;
      allRows.push(...data);
      if (data.length < PAGE) break;
      from += PAGE;
    }

    const json = JSON.stringify(allRows, null, 2);
    const filePath = join(backupDir, `${table}.json`);
    writeFileSync(filePath, json, 'utf8');

    totalRows += allRows.length;
    totalSize += json.length;
    console.log(`  ✓ ${table.padEnd(28)} ${String(allRows.length).padStart(5)} rows  (${(json.length / 1024).toFixed(1)} KB)`);
  } catch (e) {
    errors.push({ table, error: e?.message ?? String(e) });
    console.error(`  ✗ ${table.padEnd(28)} ERROR: ${e?.message ?? e}`);
  }
}

const summary = {
  timestamp,
  totalTables: TABLES.length,
  successfulTables: TABLES.length - errors.length,
  totalRows,
  totalSizeKB: Math.round(totalSize / 1024),
  errors
};
writeFileSync(join(backupDir, '_summary.json'), JSON.stringify(summary, null, 2), 'utf8');

console.log(`\n📊 Total: ${totalRows} rows, ${(totalSize / 1024 / 1024).toFixed(2)} MB`);
if (errors.length > 0) {
  console.log(`⚠️  ${errors.length} taules amb errors (probablement no existeixen) — vegeu _summary.json`);
}
console.log(`✅ Backup complet a backups/${timestamp}/`);
