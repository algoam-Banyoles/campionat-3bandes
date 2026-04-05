-- ============================================================================
-- SCRIPT DE REPARACIÓ: Byes incorrectes al bracket de perdedors (v2)
-- ============================================================================
--
-- PROBLEMA: El generador antic propagava byes incorrectament a L-R2+ del
-- bracket de perdedors. Quan dos chains incorrectes convergien en una
-- mateixa partida (ex: L-R3 match 8 amb ambdós slots erroneament is_bye),
-- la v1 del script no la reseteava perquè veia "both slots is_bye".
--
-- SOLUCIÓ en 4 passos:
--   1. Reset tots els is_bye de slots de L-R2+ (net complet)
--   2. Reset de totes les partides 'bye' a L-R2+ sense guanyador real
--   3. Reset de les partides 'bye' a L-R1 on un slot era pendent
--   4. Re-aplicar correctament els byes legítims de L-R1 als slots de L-R2
--
-- SEGUR per executar múltiples vegades (idempotent).
-- No afecta partides jugades (guanyador_participant_id IS NOT NULL).
-- ============================================================================

-- ── Pas 1: Netejar tots els is_bye de L-R2+ ──────────────────────────────────
-- Inclou tant byes incorrectes (cascada buggy) com correctes (seran re-aplicats
-- al pas 4). No toca slots que ja tinguin un participant real.

UPDATE handicap_bracket_slots
SET is_bye = FALSE
WHERE bracket_type = 'losers'
  AND ronda >= 2
  AND is_bye = TRUE
  AND participant_id IS NULL;

-- ── Pas 2: Reset partides losers L-R2+ incorrectament marcades com a bye ─────
-- Ara que els slots de L-R2+ ja no són is_bye, totes les partides 'bye' sense
-- guanyador real a L-R2+ eren incorrectes (cascada del bug).

UPDATE handicap_matches hm
SET estat = 'pendent',
    guanyador_participant_id = NULL
FROM handicap_bracket_slots s1
WHERE hm.slot1_id = s1.id
  AND s1.bracket_type = 'losers'
  AND s1.ronda >= 2
  AND hm.estat = 'bye'
  AND hm.guanyador_participant_id IS NULL;

-- ── Pas 3: Reset partides losers L-R1 parcialment incorrectes ────────────────
-- Partides on un slot era is_bye però l'altre era pendent (esperava un perdedor
-- real del winners bracket). El generador antic les marcava bye incorrectament.

UPDATE handicap_matches hm
SET estat = 'pendent',
    guanyador_participant_id = NULL
FROM handicap_bracket_slots s1,
     handicap_bracket_slots s2
WHERE hm.slot1_id = s1.id
  AND hm.slot2_id = s2.id
  AND s1.bracket_type = 'losers'
  AND s1.ronda = 1
  AND hm.estat = 'bye'
  AND hm.guanyador_participant_id IS NULL
  AND NOT (s1.is_bye AND s2.is_bye);

-- ── Pas 4: Re-aplicar byes legítims de L-R1 als slots de L-R2 ────────────────
-- Les partides L-R1 on AMBDÓS slots eren genuïnament is_bye (cap jugador real
-- mai va arribar-hi) propagen correctament is_bye al seu winner_slot_dest.
-- Aquesta és la propagació CORRECTA: slot de L-R2 que rep "cap guanyador real".

UPDATE handicap_bracket_slots dest
SET is_bye = TRUE
FROM handicap_matches hm
JOIN handicap_bracket_slots s1 ON hm.slot1_id = s1.id
JOIN handicap_bracket_slots s2 ON hm.slot2_id = s2.id
WHERE dest.id = hm.winner_slot_dest_id
  AND dest.participant_id IS NULL
  AND s1.bracket_type = 'losers'
  AND s1.ronda = 1
  AND hm.estat = 'bye'
  AND hm.guanyador_participant_id IS NULL
  AND s1.is_bye AND s2.is_bye;

-- ── Verificació post-reparació ────────────────────────────────────────────────

-- 1. Partides losers que queden com a bye (han de ser ÚNIVAMENT les L-R1 tot-bye):
SELECT
    s1.ronda AS lr,
    COUNT(*) AS num_bye_matches
FROM handicap_matches hm
JOIN handicap_bracket_slots s1 ON hm.slot1_id = s1.id
WHERE s1.bracket_type = 'losers'
  AND hm.estat = 'bye'
GROUP BY s1.ronda
ORDER BY s1.ronda;

-- 2. Ha de retornar 0 (cap slot is_bye a L-R3+):
SELECT COUNT(*) AS slots_incorrectes_lr3plus
FROM handicap_bracket_slots
WHERE bracket_type = 'losers'
  AND ronda >= 3
  AND is_bye = TRUE;

-- 3. Ha de retornar 0 (cap slot is_bye als parells de L-R2 — reben perdedors del winners):
SELECT COUNT(*) AS slots_incorrectes_lr2_parells
FROM handicap_bracket_slots
WHERE bracket_type = 'losers'
  AND ronda = 2
  AND posicio % 2 = 0
  AND is_bye = TRUE;
