-- ===============================================
-- SCRIPT FINAL D'ÍNDEXS I OPTIMITZACIONS 
-- ===============================================
-- Executa aquest SQL a Supabase Dashboard > SQL Editor
-- URL: https://app.supabase.com/project/[PROJECT_ID]/sql

-- ÍNDEXS VERIFICATS AMB L'ESQUEMA REAL DE SUPABASE
-- Aquest script utilitza els noms exactes de columnes de l'esquema del núvol

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

-- ÍNDEXS PER LA TAULA MITJANES_HISTORIQUES (soci_id NO soci)
-- ===============================================
CREATE INDEX IF NOT EXISTS idx_mitjanes_historiques_soci_id ON mitjanes_historiques(soci_id);
CREATE INDEX IF NOT EXISTS idx_mitjanes_historiques_modalitat ON mitjanes_historiques(modalitat);
CREATE INDEX IF NOT EXISTS idx_mitjanes_historiques_year ON mitjanes_historiques(year);
CREATE INDEX IF NOT EXISTS idx_mitjanes_historiques_soci_year ON mitjanes_historiques(soci_id, year);
CREATE INDEX IF NOT EXISTS idx_mitjanes_historiques_modalitat_year ON mitjanes_historiques(modalitat, year);
CREATE INDEX IF NOT EXISTS idx_mitjanes_historiques_mitjana_desc ON mitjanes_historiques(mitjana DESC) WHERE mitjana IS NOT NULL;

-- ÍNDEXS PER LA TAULA SOCIS  
-- ===============================================
CREATE INDEX IF NOT EXISTS idx_socis_email ON socis(email) WHERE email IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_socis_de_baixa ON socis(de_baixa);
CREATE INDEX IF NOT EXISTS idx_socis_nom_cognoms ON socis(nom, cognoms);

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

-- ÍNDEXS PER LA TAULA WAITING_LIST
-- ===============================================
CREATE INDEX IF NOT EXISTS idx_waiting_list_event_id ON waiting_list(event_id);
CREATE INDEX IF NOT EXISTS idx_waiting_list_player_id ON waiting_list(player_id);
CREATE INDEX IF NOT EXISTS idx_waiting_list_event_ordre ON waiting_list(event_id, ordre);

-- ÍNDEXS PER NOTIFICACIONS
-- ===============================================
CREATE INDEX IF NOT EXISTS idx_notification_history_user_id ON notification_history(user_id);
CREATE INDEX IF NOT EXISTS idx_notification_history_enviada_el ON notification_history(enviada_el DESC);
CREATE INDEX IF NOT EXISTS idx_scheduled_notifications_scheduled_for ON scheduled_notifications(scheduled_for) WHERE processed = false;

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
ANALYZE waiting_list;
ANALYZE notification_history;
ANALYZE scheduled_notifications;

-- Verificar índexs creats correctament
-- ===============================================
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes 
WHERE tablename IN ('challenges', 'ranking_positions', 'mitjanes_historiques', 'socis', 'players', 'matches', 'history_position_changes')
    AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;

-- Mostrar estadístiques de taules principals
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
    AND tablename IN ('challenges', 'ranking_positions', 'mitjanes_historiques', 'socis', 'players')
ORDER BY n_live_tup DESC;

-- Verificar que els índexs crítics existeixen
-- ===============================================
SELECT 
    'ÍNDEXS CRÍTICS VERIFICATS' as status,
    COUNT(*) as total_indexes_created
FROM pg_indexes 
WHERE indexname LIKE 'idx_%'
    AND tablename IN ('mitjanes_historiques', 'challenges', 'ranking_positions');

-- Missatge de confirmació
-- ===============================================
SELECT 
    'OPTIMITZACIÓ COMPLETADA' as status,
    'Índexs aplicats i ANALYZE executat correctament' as message,
    now() as completed_at;