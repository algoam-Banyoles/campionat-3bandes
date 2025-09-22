-- ===============================================
-- SCRIPT MANUAL D'ÍNDEXS I OPTIMITZACIONS
-- ===============================================
-- Executa aquest SQL a Supabase Dashboard > SQL Editor
-- URL: https://app.supabase.com/project/[PROJECT_ID]/sql

-- Primer, crear els índexs (si no existeixen)
-- ===============================================

-- ÍNDEXS PER LA TAULA CHALLENGES
-- ===============================================
-- Nota: alguns índexs ja existeixen al schema (ex: idx_challenges_event_players)
CREATE INDEX IF NOT EXISTS idx_challenges_estat ON challenges(estat);
CREATE INDEX IF NOT EXISTS idx_challenges_estat_data_proposta ON challenges(estat, data_proposta DESC);
CREATE INDEX IF NOT EXISTS idx_challenges_data_programada ON challenges(data_programada) WHERE data_programada IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_challenges_data_acceptacio ON challenges(data_acceptacio DESC) WHERE data_acceptacio IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_challenges_active_by_player ON challenges(estat, reptador_id, reptat_id, data_proposta DESC) WHERE estat IN ('proposat', 'acceptat', 'programat');

-- ÍNDEXS PER LA TAULA RANKING_POSITIONS
-- ===============================================
CREATE INDEX IF NOT EXISTS idx_ranking_positions_event_id ON ranking_positions(event_id);
CREATE INDEX IF NOT EXISTS idx_ranking_positions_player_id ON ranking_positions(player_id);
CREATE INDEX IF NOT EXISTS idx_ranking_positions_event_posicio ON ranking_positions(event_id, posicio);
CREATE INDEX IF NOT EXISTS idx_ranking_positions_event_player ON ranking_positions(event_id, player_id);

-- ÍNDEXS PER LA TAULA MITJANES_HISTORIQUES
-- ===============================================
CREATE INDEX IF NOT EXISTS idx_mitjanes_historiques_soci ON mitjanes_historiques(soci);
CREATE INDEX IF NOT EXISTS idx_mitjanes_historiques_modalitat ON mitjanes_historiques(modalitat);
CREATE INDEX IF NOT EXISTS idx_mitjanes_historiques_year ON mitjanes_historiques(year);
CREATE INDEX IF NOT EXISTS idx_mitjanes_historiques_soci_year ON mitjanes_historiques(soci, year);
CREATE INDEX IF NOT EXISTS idx_mitjanes_historiques_modalitat_year ON mitjanes_historiques(modalitat, year);
CREATE INDEX IF NOT EXISTS idx_mitjanes_historiques_modalitat_year_mitjana ON mitjanes_historiques(modalitat, year, mitjana DESC) WHERE mitjana IS NOT NULL;

-- ÍNDEXS PER LA TAULA PLAYERS
-- ===============================================
CREATE INDEX IF NOT EXISTS idx_players_estat ON players(estat);
CREATE INDEX IF NOT EXISTS idx_players_numero_soci ON players(numero_soci);

-- ÍNDEXS PER LA TAULA MATCHES
-- ===============================================
-- Nota: idx_matches_challenge i idx_matches_data_joc ja existeixen al schema
CREATE INDEX IF NOT EXISTS idx_matches_resultat ON matches(resultat);
CREATE INDEX IF NOT EXISTS idx_matches_data_joc_desc ON matches(data_joc DESC);
CREATE INDEX IF NOT EXISTS idx_matches_signat ON matches(signat_reptador, signat_reptat) WHERE (signat_reptador = false OR signat_reptat = false);

-- ÍNDEXS PER LA TAULA HISTORY_POSITION_CHANGES
-- ===============================================
CREATE INDEX IF NOT EXISTS idx_history_changes_event_id ON history_position_changes(event_id);
CREATE INDEX IF NOT EXISTS idx_history_changes_player_id ON history_position_changes(player_id);
CREATE INDEX IF NOT EXISTS idx_history_changes_creat_el ON history_position_changes(creat_el DESC);

-- ÍNDEXS PER LA TAULA WAITING_LIST
-- ===============================================
CREATE INDEX IF NOT EXISTS idx_waiting_list_event_id ON waiting_list(event_id);
CREATE INDEX IF NOT EXISTS idx_waiting_list_player_id ON waiting_list(player_id);
CREATE INDEX IF NOT EXISTS idx_waiting_list_event_ordre ON waiting_list(event_id, ordre);

-- Segon, executar ANALYZE per optimitzar l'optimitzador de queries
-- ===============================================
ANALYZE challenges;
ANALYZE ranking_positions;
ANALYZE mitjanes_historiques;
ANALYZE players;
ANALYZE events;
ANALYZE matches;
ANALYZE history_position_changes;
ANALYZE waiting_list;
ANALYZE app_settings;

-- Verificar que els índexs s'han creat correctament
-- ===============================================
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes 
WHERE tablename IN ('challenges', 'ranking_positions', 'mitjanes_historiques', 'players', 'matches')
    AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;