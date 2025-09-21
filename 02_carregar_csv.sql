-- PASO 2: Carregar dades del CSV
-- IMPORTANT: Aquest pas NO es pot fer amb SQL directament, has d'usar psql amb \copy

-- Instruccions per executar al terminal PowerShell:
-- cd C:\Users\algoa\campionat-3bandes
-- psql "postgresql://postgres.qbldqtaqawnahuzlzjs:Banyoles2025%21@aws-0-eu-central-1.pooler.supabase.com:6543/Continu3B?sslmode=require" -c "\copy temp_new_mitjanes(year, modalitat, posicio, nom_jugador, mitjana) FROM 'dades/Ranquing (1) (1).csv' WITH (FORMAT csv, DELIMITER ';', HEADER true)"

-- Alternativament, si el \copy no funciona, pots usar aquest SQL (però hauràs de modificar les dades):
-- Això és només un exemple de com inserir dades manualment si cal:
/*
INSERT INTO temp_new_mitjanes (year, modalitat, posicio, nom_jugador, mitjana) VALUES
(2025, '3 BANDES', 1, 'A. GÓMEZ', 0.497),
(2025, '3 BANDES', 2, 'J.F. SANTOS', 0.454),
(2025, '3 BANDES', 3, 'J.M. CAMPOS', 0.429);
-- ... (hauràs d'afegir totes les files del CSV aquí)
*/

-- Verificar que les dades s'han carregat:
SELECT COUNT(*) as total_files_carregades FROM temp_new_mitjanes;
SELECT * FROM temp_new_mitjanes LIMIT 10;