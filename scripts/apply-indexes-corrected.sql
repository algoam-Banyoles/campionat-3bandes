-- ===============================================
-- SCRIPT MANUAL D'ÍNDEXS I OPTIMITZACIONS (CORREGIT)
-- ===============================================
-- Executa aquest SQL a Supabase Dashboard > SQL Editor
-- URL: https://app.supabase.com/project/[PROJECT_ID]/sql

-- Aquest script només crea índexs nous que no existeixen ja al schema
-- i utilitza els noms correctes de columnes

-- ÍNDEXS ADDICIONALS PER CHALLENGES
-- ===============================================
CREATE INDEX IF NOT EXISTS idx_challenges_estat ON challenges(estat);
CREATE INDEX IF NOT EXISTS idx_challenges_estat_data_proposta ON challenges(estat, data_proposta DESC);
CREATE INDEX IF NOT EXISTS idx_challenges_data_programada_nn ON challenges(data_programada) WHERE data_programada IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_challenges_data_acceptacio_desc ON challenges(data_acceptacio DESC) WHERE data_acceptacio IS NOT NULL;

-- ÍNDEXS PER LA TAULA RANKING_POSITIONS
-- ===============================================
CREATE INDEX IF NOT EXISTS idx_ranking_positions_event_id ON ranking_positions(event_id);
CREATE INDEX IF NOT EXISTS idx_ranking_positions_player_id ON ranking_positions(player_id);
CREATE INDEX IF NOT EXISTS idx_ranking_positions_event_posicio ON ranking_positions(event_id, posicio);

-- ÍNDEXS PER LA TAULA MITJANES_HISTORIQUES
-- ===============================================
CREATE INDEX IF NOT EXISTS idx_mitjanes_historiques_soci_id ON mitjanes_historiques(soci_id);
CREATE INDEX IF NOT EXISTS idx_mitjanes_historiques_modalitat ON mitjanes_historiques(modalitat);
CREATE INDEX IF NOT EXISTS idx_mitjanes_historiques_year ON mitjanes_historiques(year);
CREATE INDEX IF NOT EXISTS idx_mitjanes_historiques_soci_year ON mitjanes_historiques(soci_id, year);
CREATE INDEX IF NOT EXISTS idx_mitjanes_historiques_modalitat_year ON mitjanes_historiques(modalitat, year);
CREATE INDEX IF NOT EXISTS idx_mitjanes_historiques_mitjana_desc ON mitjanes_historiques(mitjana DESC) WHERE mitjana IS NOT NULL;

-- ÍNDEXS PER LA TAULA PLAYERS
-- ===============================================
CREATE INDEX IF NOT EXISTS idx_players_estat ON players(estat);
CREATE INDEX IF NOT EXISTS idx_players_numero_soci ON players(numero_soci);

-- ÍNDEXS ADDICIONALS PER MATCHES
-- ===============================================
-- Nota: idx_matches_challenge i idx_matches_data_joc ja existeixen
CREATE INDEX IF NOT EXISTS idx_matches_resultat ON matches(resultat);
CREATE INDEX IF NOT EXISTS idx_matches_signat ON matches(signat_reptador, signat_reptat) WHERE (signat_reptador = false OR signat_reptat = false);

-- ÍNDEXS PER LA TAULA HISTORY_POSITION_CHANGES
-- ===============================================
CREATE INDEX IF NOT EXISTS idx_history_changes_event_id ON history_position_changes(event_id);
CREATE INDEX IF NOT EXISTS idx_history_changes_player_id ON history_position_changes(player_id);
CREATE INDEX IF NOT EXISTS idx_history_changes_creat_el ON history_position_changes(creat_el DESC);

-- ÍNDEXS PER LA TAULA WAITING_LIST (si existeix)
-- ===============================================
CREATE INDEX IF NOT EXISTS idx_waiting_list_event_id ON waiting_list(event_id);
CREATE INDEX IF NOT EXISTS idx_waiting_list_player_id ON waiting_list(player_id);
CREATE INDEX IF NOT EXISTS idx_waiting_list_event_ordre ON waiting_list(event_id, ordre);

-- ÍNDEXS PER LA TAULA SOCIS
-- ===============================================
CREATE INDEX IF NOT EXISTS idx_socis_email ON socis(email) WHERE email IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_socis_de_baixa ON socis(de_baixa);
CREATE INDEX IF NOT EXISTS idx_socis_nom_cognoms ON socis(nom, cognoms);

-- ÍNDEXS PER LA TAULA APP_SETTINGS
-- ===============================================
CREATE INDEX IF NOT EXISTS idx_app_settings_updated_at ON app_settings(updated_at DESC);

-- ANALYZE per optimitzar l'optimitzador de queries
-- ===============================================
ANALYZE challenges;
ANALYZE ranking_positions;
ANALYZE mitjanes_historiques;
ANALYZE socis;
ANALYZE players;
ANALYZE events;
ANALYZE matches;
ANALYZE history_position_changes;
ANALYZE app_settings;

-- Executar només si waiting_list existeix
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'waiting_list') THEN
        EXECUTE 'ANALYZE waiting_list';
    END IF;
END $$;

-- Verificar índexs creats
-- ===============================================
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes 
WHERE tablename IN ('challenges', 'ranking_positions', 'mitjanes_historiques', 'players', 'matches', 'history_position_changes', 'socis')
    AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;

-- Mostrar estadístiques de taules
-- ===============================================
SELECT 
    schemaname,
    tablename,
    n_tup_ins as inserts,
    n_tup_upd as updates,
    n_tup_del as deletes,
    n_live_tup as live_rows,
    last_analyze
FROM pg_stat_user_tables 
WHERE schemaname = 'public'
ORDER BY n_live_tup DESC;