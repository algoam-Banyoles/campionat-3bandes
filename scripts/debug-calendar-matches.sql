-- ===============================================
-- INVESTIGAR I SOLUCIONAR CALENDARI GENERAL
-- ===============================================
-- Aquest script investiga per què no es mostren les partides programades al calendari

-- 1. Verificar si hi ha partides programades per l'1 d'octubre 2025
SELECT 
    'PARTIDES CALENDARI - 1 Octubre 2025' as check_type,
    COUNT(*) as total_partides
FROM calendari_partides 
WHERE data_programada::date = '2025-10-01';

-- 2. Mostrar detalls de les partides de l'1 d'octubre
SELECT 
    cp.id,
    cp.data_programada,
    cp.hora_inici,
    cp.estat,
    cp.taula_assignada,
    e.nom as event_nom,
    e.calendari_publicat,
    cat.nom as categoria_nom,
    j1.nom as jugador1_nom,
    j2.nom as jugador2_nom
FROM calendari_partides cp
JOIN events e ON e.id = cp.event_id
LEFT JOIN categories cat ON cat.id = cp.categoria_id
LEFT JOIN players j1 ON j1.id = cp.jugador1_id
LEFT JOIN players j2 ON j2.id = cp.jugador2_id
WHERE cp.data_programada::date = '2025-10-01'
ORDER BY cp.hora_inici;

-- 3. Verificar quins esdeveniments tenen calendari_publicat = true
SELECT 
    'ESDEVENIMENTS PUBLICATS' as check_type,
    id,
    nom,
    calendari_publicat,
    actiu
FROM events 
WHERE calendari_publicat = true
ORDER BY nom;

-- 4. Verificar si hi ha partides validades per events publicats
SELECT 
    'PARTIDES VALIDADES EN EVENTS PUBLICATS' as check_type,
    COUNT(*) as total_partides
FROM calendari_partides cp
JOIN events e ON e.id = cp.event_id
WHERE cp.estat = 'validat' 
    AND e.calendari_publicat = true;

-- 5. Mostrar totes les partides validades d'events publicats (sample)
SELECT 
    cp.data_programada::date as data,
    COUNT(*) as partides_dia
FROM calendari_partides cp
JOIN events e ON e.id = cp.event_id
WHERE cp.estat = 'validat' 
    AND e.calendari_publicat = true
    AND cp.data_programada >= CURRENT_DATE
GROUP BY cp.data_programada::date
ORDER BY cp.data_programada::date
LIMIT 10;

-- 6. Si no hi ha esdeveniments publicats, activar-los
-- EXECUTAR NOMÉS SI EL PUNT 3 NO MOSTRA CAP ESDEVENIMENT
-- UPDATE events SET calendari_publicat = true WHERE actiu = true;

-- 7. Verificar reptes programats del campionat ranking
SELECT 
    'REPTES PROGRAMATS' as check_type,
    COUNT(*) as total_reptes
FROM challenges 
WHERE data_programada IS NOT NULL 
    AND data_programada >= CURRENT_DATE;

-- 8. Mostrar reptes programats (sample)
SELECT 
    c.data_programada::date as data,
    COUNT(*) as reptes_dia,
    STRING_AGG(
        p1.nom || ' vs ' || p2.nom, 
        ', ' 
        ORDER BY c.data_programada
    ) as reptes
FROM challenges c
JOIN players p1 ON p1.id = c.reptador_id
JOIN players p2 ON p2.id = c.reptat_id
WHERE c.data_programada IS NOT NULL 
    AND c.data_programada >= CURRENT_DATE
GROUP BY c.data_programada::date
ORDER BY c.data_programada::date
LIMIT 5;