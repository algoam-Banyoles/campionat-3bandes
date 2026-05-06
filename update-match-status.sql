-- Buscar la partida Inocentes (5818) vs Polls (8181) del campionat social de banda 2025/2026
-- i canviar l'estat de 'validat' a 'pendent_programar'

-- Primer, trobar l'event ID del campionat social de banda 2025/2026
SELECT id, nom, modalitat, temporada FROM events 
WHERE tipus_competicio = 'lliga_social' 
  AND modalitat = 'banda' 
  AND temporada = '2025-2026'
LIMIT 1;

-- Després, trobar la partida i actualizar l'estat
UPDATE calendari_partides
SET estat = 'pendent_programar'
WHERE event_id = (
  SELECT id FROM events 
  WHERE tipus_competicio = 'lliga_social' 
    AND modalitat = 'banda' 
    AND temporada = '2025-2026'
  LIMIT 1
)
AND (
  (jugador1_soci_numero = 5818 AND jugador2_soci_numero = 8181)
  OR
  (jugador1_soci_numero = 8181 AND jugador2_soci_numero = 5818)
)
AND estat = 'validat';

-- Confirmar el canvi
SELECT id, jugador1_soci_numero, jugador2_soci_numero, estat, data_programada 
FROM calendari_partides
WHERE event_id = (
  SELECT id FROM events 
  WHERE tipus_competicio = 'lliga_social' 
    AND modalitat = 'banda' 
    AND temporada = '2025-2026'
  LIMIT 1
)
AND (
  (jugador1_soci_numero = 5818 AND jugador2_soci_numero = 8181)
  OR
  (jugador1_soci_numero = 8181 AND jugador2_soci_numero = 5818)
);
