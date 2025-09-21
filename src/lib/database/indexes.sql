-- Scripts d'índexs per optimitzar les consultes més freqüents
-- Executar aquests comandos a la consola SQL de Supabase

-- =====================================================
-- ÍNDEXS PER LA TAULA RANKING
-- =====================================================

-- Índex principal per posició (ja existeix probablement com a PRIMARY KEY)
-- CREATE INDEX IF NOT EXISTS idx_ranking_posicio ON ranking(posicio);

-- Índex per soci_id per trobar ràpidament la posició d'un jugador
CREATE INDEX IF NOT EXISTS idx_ranking_soci_id ON ranking(soci_id);

-- Índex compost per data d'entrada per històric de canvis
CREATE INDEX IF NOT EXISTS idx_ranking_data_entrada ON ranking(data_entrada DESC);

-- Índex per mitjana de referència per ordenacions
CREATE INDEX IF NOT EXISTS idx_ranking_mitjana_referencia ON ranking(mitjana_referencia DESC NULLS LAST);

-- =====================================================
-- ÍNDEXS PER LA TAULA CHALLENGES
-- =====================================================

-- Índex per estat (consultes molt freqüents per reptes actius)
CREATE INDEX IF NOT EXISTS idx_challenges_estat ON challenges(estat);

-- Índex compost per estat i data de creació (per llistar reptes actius ordenats)
CREATE INDEX IF NOT EXISTS idx_challenges_estat_data_creacio ON challenges(estat, data_creacio DESC);

-- Índex per reptador_id per trobar reptes d'un jugador
CREATE INDEX IF NOT EXISTS idx_challenges_reptador_id ON challenges(reptador_id);

-- Índex per reptat_id per trobar reptes d'un jugador
CREATE INDEX IF NOT EXISTS idx_challenges_reptat_id ON challenges(reptat_id);

-- Índex compost per reptador i estat (optimitzar queries de reptes per jugador)
CREATE INDEX IF NOT EXISTS idx_challenges_reptador_estat ON challenges(reptador_id, estat);

-- Índex compost per reptat i estat
CREATE INDEX IF NOT EXISTS idx_challenges_reptat_estat ON challenges(reptat_id, estat);

-- Índex per data programada (per trobar partides pendents de jugar)
CREATE INDEX IF NOT EXISTS idx_challenges_data_programada ON challenges(data_programada)
WHERE data_programada IS NOT NULL;

-- Índex per data de completat (per estadístiques històriques)
CREATE INDEX IF NOT EXISTS idx_challenges_data_completat ON challenges(data_completat DESC)
WHERE data_completat IS NOT NULL;

-- Índex compost per optimitzar queries de reptes actius d'un jugador específic
CREATE INDEX IF NOT EXISTS idx_challenges_active_by_player ON challenges(estat, reptador_id, reptat_id, data_creacio DESC)
WHERE estat IN ('pendent', 'acceptat');

-- =====================================================
-- ÍNDEXS PER LA TAULA SOCIS (PLAYERS)
-- =====================================================

-- Índex per numero_soci (probablement ja existeix com a UNIQUE)
-- CREATE UNIQUE INDEX IF NOT EXISTS idx_socis_numero_soci ON socis(numero_soci);

-- Índex per nom i cognoms per cerques ràpides
CREATE INDEX IF NOT EXISTS idx_socis_nom_cognoms ON socis(nom, cognoms);

-- Índex parcial només per socis actius (de_baixa IS NULL OR de_baixa = false)
CREATE INDEX IF NOT EXISTS idx_socis_actius ON socis(nom, cognoms)
WHERE de_baixa IS NULL OR de_baixa = false;

-- Índex GIN per cerques de text completes (si suportat per Supabase)
-- Això permet cerques més eficients amb ILIKE
CREATE INDEX IF NOT EXISTS idx_socis_text_search ON socis 
USING gin(to_tsvector('spanish', nom || ' ' || cognoms));

-- Índex per email per evitar queries lentes en autenticació
CREATE INDEX IF NOT EXISTS idx_socis_email ON socis(email)
WHERE email IS NOT NULL;

-- =====================================================
-- ÍNDEXS PER LA TAULA MITJANES_HISTORIQUES
-- =====================================================

-- Índex principal per soci_id i any
CREATE INDEX IF NOT EXISTS idx_mitjanes_historiques_soci_year ON mitjanes_historiques(soci_id, year DESC);

-- Índex per modalitat (filtrar per 3 BANDES)
CREATE INDEX IF NOT EXISTS idx_mitjanes_historiques_modalitat ON mitjanes_historiques(modalitat);

-- Índex compost per soci, modalitat i any (query més freqüent)
CREATE INDEX IF NOT EXISTS idx_mitjanes_historiques_soci_modalitat_year ON mitjanes_historiques(soci_id, modalitat, year DESC);

-- Índex per any per obtenir mitjanes d'un any específic
CREATE INDEX IF NOT EXISTS idx_mitjanes_historiques_year ON mitjanes_historiques(year DESC);

-- Índex compost per modalitat, any i mitjana (per trobar millors jugadors per any)
CREATE INDEX IF NOT EXISTS idx_mitjanes_historiques_modalitat_year_mitjana ON mitjanes_historiques(modalitat, year DESC, mitjana DESC NULLS LAST)
WHERE mitjana IS NOT NULL AND mitjana > 0;

-- =====================================================
-- ÍNDEXS ADDICIONALS PER OPTIMITZACIONS ESPECÍFIQUES
-- =====================================================

-- Índex per optimitzar JOIN entre ranking i socis
-- (aquest és redundant si ja tens FK constraints amb índexs)
-- CREATE INDEX IF NOT EXISTS idx_ranking_socis_join ON ranking(soci_id);

-- Índex per optimitzar JOIN entre challenges i socis (reptador)
CREATE INDEX IF NOT EXISTS idx_challenges_reptador_join ON challenges(reptador_id)
WHERE reptador_id IS NOT NULL;

-- Índex per optimitzar JOIN entre challenges i socis (reptat) 
CREATE INDEX IF NOT EXISTS idx_challenges_reptat_join ON challenges(reptat_id)
WHERE reptat_id IS NOT NULL;

-- =====================================================
-- ESTADÍSTIQUES I MANTENIMENT
-- =====================================================

-- Actualitzar estadístiques de les taules (Postgres automàtic, però es pot forçar)
-- ANALYZE ranking;
-- ANALYZE challenges;
-- ANALYZE socis;
-- ANALYZE mitjanes_historiques;

-- =====================================================
-- COMENTARIS I NOTES
-- =====================================================

/*
NOTES SOBRE ELS ÍNDEXS:

1. ÍNDEXS COMPOSTOS:
   - L'ordre de les columnes importa: poseu primer les columnes més selectives
   - Els índexs compostos poden servir per queries que usen només les primeres columnes

2. ÍNDEXS PARCIALS:
   - Usen menys espai i són més ràpids per queries específiques
   - Exemples: només socis actius, només reptes completats

3. ÍNDEXS GIN:
   - Optimitzen cerques de text amb ILIKE i expressions regulars
   - Utils per funcionalitats de cerca

4. MANTENIMENT:
   - Els índexs s'actualitzen automàticament
   - Poden ralentir INSERT/UPDATE/DELETE
   - Monitoritzar l'ús d'índexs amb pg_stat_user_indexes

5. TESTING:
   - Usar EXPLAIN ANALYZE per verificar que s'usen els índexs
   - Monitoritzar queries lentes amb pg_stat_statements
*/

-- =====================================================
-- QUERIES PER MONITORITZAR L'ÚS DELS ÍNDEXS
-- =====================================================

-- Veure quins índexs s'estan usant
/*
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes 
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;
*/

-- Veure la mida dels índexs
/*
SELECT 
    indexname,
    pg_size_pretty(pg_relation_size(indexname::regclass)) as size
FROM pg_indexes 
WHERE schemaname = 'public'
ORDER BY pg_relation_size(indexname::regclass) DESC;
*/

-- Queries lentes (si tens pg_stat_statements habilitat)
/*
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    rows
FROM pg_stat_statements 
WHERE query LIKE '%ranking%' OR query LIKE '%challenges%' OR query LIKE '%socis%'
ORDER BY mean_time DESC
LIMIT 10;
*/