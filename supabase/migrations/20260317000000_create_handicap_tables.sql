-- ============================================================================
-- Migració: Creació de taules per al mòdul de torneig hàndicap
-- Data: 2026-03-17
-- Descripció: Crea les 4 taules principals per gestionar torneigs d'eliminació
--   doble (bracket guanyadors + bracket perdedors + gran final) amb sistema
--   de puntuació configurable (distància o percentatge).
-- ============================================================================

-- ============================================================================
-- TAULA 1: handicap_config
-- Configuració del torneig hàndicap (1 per event).
-- Defineix el sistema de puntuació, les distàncies per grup de nivell,
-- i els horaris extra opcionals.
-- ============================================================================

CREATE TABLE public.handicap_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  sistema_puntuacio TEXT NOT NULL,
  limit_entrades SMALLINT,
  distancies_per_categoria JSONB NOT NULL,
  -- Exemple distancies_per_categoria:
  --   [{"nom": "1a", "distancia": 20}, {"nom": "2a", "distancia": 15}, {"nom": "resta", "distancia": 10}]
  horaris_extra JSONB,
  -- Exemple horaris_extra:
  --   {"franja": "17:00", "dies": ["dl", "dt"]}
  --   Franges addicionals fora dels horaris estàndard 18h/19h dl-dv
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Només pot haver-hi un config per event
  CONSTRAINT handicap_config_event_unique UNIQUE (event_id),

  -- Sistema de puntuació: 'distancia' (sense límit d'entrades) o 'percentatge' (amb límit)
  CONSTRAINT handicap_config_sistema_check
    CHECK (sistema_puntuacio IN ('distancia', 'percentatge')),

  -- Coherència: percentatge requereix limit_entrades, distancia no
  CONSTRAINT handicap_config_limit_entrades_check
    CHECK (
      (sistema_puntuacio = 'distancia' AND limit_entrades IS NULL)
      OR
      (sistema_puntuacio = 'percentatge' AND limit_entrades IS NOT NULL)
    )
);

COMMENT ON TABLE public.handicap_config IS
  'Configuració del torneig hàndicap. Un registre per event.';
COMMENT ON COLUMN public.handicap_config.sistema_puntuacio IS
  'distancia: guanya qui arriba primer a la seva distància. percentatge: guanya qui fa més % de caramboles/distància dins el límit d''entrades.';
COMMENT ON COLUMN public.handicap_config.distancies_per_categoria IS
  'JSON array amb els grups de distància. Ex: [{"nom":"1a","distancia":20},{"nom":"2a","distancia":15}]';
COMMENT ON COLUMN public.handicap_config.horaris_extra IS
  'Configuració de franges horàries extra. Ex: {"franja":"17:00","dies":["dl","dt"]}';


-- ============================================================================
-- TAULA 2: handicap_participants
-- Jugadors inscrits al torneig hàndicap.
-- Cada jugador té una distància assignada segons el seu nivell i un seed
-- que l'admin introdueix manualment durant el sorteig presencial.
-- NO reutilitzem inscripcions perquè el flux és diferent: distància individual,
-- seed manual, sense categories formals.
-- ============================================================================

CREATE TABLE public.handicap_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  player_id UUID NOT NULL REFERENCES public.players(id) ON DELETE CASCADE,
  distancia SMALLINT NOT NULL,
  seed SMALLINT,
  -- Disponibilitat: format compatible amb inscripcions.preferencies_dies/hores
  preferencies_dies TEXT[],
  preferencies_hores TEXT[],
  restriccions_especials TEXT,
  eliminat BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Un jugador no es pot inscriure dues vegades al mateix torneig
  CONSTRAINT handicap_participants_event_player_unique
    UNIQUE (event_id, player_id),

  -- La distància ha de ser positiva
  CONSTRAINT handicap_participants_distancia_check
    CHECK (distancia > 0)
);

COMMENT ON TABLE public.handicap_participants IS
  'Jugadors inscrits al torneig hàndicap amb la seva distància objectiu i seed de sorteig.';
COMMENT ON COLUMN public.handicap_participants.distancia IS
  'Caramboles objectiu del jugador (ex: 20, 15, 10 segons nivell).';
COMMENT ON COLUMN public.handicap_participants.seed IS
  'Posició al sorteig, introduïda manualment per l''admin durant el sorteig presencial.';
COMMENT ON COLUMN public.handicap_participants.eliminat IS
  'True quan el jugador perd al bracket de perdedors i queda fora del torneig.';

-- Índexos per handicap_participants
CREATE INDEX idx_handicap_participants_event ON public.handicap_participants (event_id);
CREATE INDEX idx_handicap_participants_player ON public.handicap_participants (player_id);


-- ============================================================================
-- TAULA 3: handicap_bracket_slots
-- Estructura del quadre d'eliminació doble.
-- Cada slot representa una posició dins d'una ronda d'un bracket.
-- El participant_id es va omplint a mesura que avancen les eliminatòries.
-- ============================================================================

CREATE TABLE public.handicap_bracket_slots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  bracket_type TEXT NOT NULL,
  ronda SMALLINT NOT NULL,
  posicio SMALLINT NOT NULL,
  participant_id UUID REFERENCES public.handicap_participants(id) ON DELETE CASCADE,
  is_bye BOOLEAN NOT NULL DEFAULT false,
  -- source_match_id: d'on prové el jugador que ocupa aquest slot.
  -- NULL per slots de la primera ronda (provenen del sorteig).
  -- SET NULL si s'esborra el match (traçabilitat no crítica).
  source_match_id UUID,
  -- FK definida més avall (referència circular amb handicap_matches)
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Unicitat: no pot haver-hi dos slots a la mateixa posició
  CONSTRAINT handicap_bracket_slots_unique
    UNIQUE (event_id, bracket_type, ronda, posicio),

  -- Tipus de bracket vàlids
  -- 'winners': bracket principal de guanyadors
  -- 'losers': bracket de perdedors (segona oportunitat)
  -- 'grand_final': final i possible reset match
  CONSTRAINT handicap_bracket_slots_type_check
    CHECK (bracket_type IN ('winners', 'losers', 'grand_final')),

  -- Ronda ha de ser >= 1
  CONSTRAINT handicap_bracket_slots_ronda_check
    CHECK (ronda >= 1),

  -- Posició ha de ser >= 1
  CONSTRAINT handicap_bracket_slots_posicio_check
    CHECK (posicio >= 1)
);

COMMENT ON TABLE public.handicap_bracket_slots IS
  'Estructura del quadre d''eliminació doble. Cada slot és una posició dins d''una ronda d''un bracket.';
COMMENT ON COLUMN public.handicap_bracket_slots.bracket_type IS
  'winners: bracket principal. losers: bracket de perdedors. grand_final: final (ronda 1) i reset match (ronda 2).';
COMMENT ON COLUMN public.handicap_bracket_slots.participant_id IS
  'NULL fins que es coneix el jugador (per rondes posteriors a la primera, s''omple quan es juga el match anterior).';
COMMENT ON COLUMN public.handicap_bracket_slots.source_match_id IS
  'Referència al match que va determinar el jugador d''aquest slot. NULL per slots de R1 (sorteig).';

-- Índexos per handicap_bracket_slots
CREATE INDEX idx_handicap_bracket_slots_event_type_ronda
  ON public.handicap_bracket_slots (event_id, bracket_type, ronda);
CREATE INDEX idx_handicap_bracket_slots_participant
  ON public.handicap_bracket_slots (participant_id);


-- ============================================================================
-- TAULA 4: handicap_matches
-- Partides del torneig hàndicap.
-- Cada match linka dos bracket_slots i opcionalment una partida programada
-- a calendari_partides (per data/hora/taula i resultats de caramboles).
--
-- CONVENCIÓ SLOT1/SLOT2:
--   - slot1_id correspon a distancia_jugador1 i, quan es linki a calendari_partides,
--     a jugador1_id de la partida programada.
--   - slot2_id correspon a distancia_jugador2 i a jugador2_id de calendari_partides.
--   - A la primera ronda del bracket de guanyadors: slot1 = seed inferior (millor
--     posició, ex: seed 1), slot2 = seed superior (ex: seed 16).
--
-- WALKOVER:
--   Quan estat='walkover', el rival que es presenta es tracta com a guanyador.
--   La propagació als bracket_slots és idèntica al cas 'jugada': el guanyador
--   avança a winner_slot_dest_id i el perdedor cau a loser_slot_dest_id.
--   La diferència és que no hi ha resultat de caramboles a calendari_partides
--   (caramboles_jugador1/2 queden NULL).
--
-- BYE:
--   Quan estat='bye', no hi ha partida real. distancia_jugador1 i
--   distancia_jugador2 seran NULL. El jugador amb bye avança directament
--   al winner_slot_dest_id.
-- ============================================================================

CREATE TABLE public.handicap_matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  -- Referència a calendari_partides per data/hora/taula/resultats.
  -- NULL fins que la partida es programa. SET NULL si s'esborra la programació.
  calendari_partida_id UUID REFERENCES public.calendari_partides(id) ON DELETE SET NULL,
  slot1_id UUID NOT NULL REFERENCES public.handicap_bracket_slots(id) ON DELETE CASCADE,
  slot2_id UUID NOT NULL REFERENCES public.handicap_bracket_slots(id) ON DELETE CASCADE,
  -- Destí del guanyador: el bracket_slot on avançarà.
  -- NULL per la final definitiva (no hi ha ronda següent).
  winner_slot_dest_id UUID REFERENCES public.handicap_bracket_slots(id) ON DELETE SET NULL,
  -- Destí del perdedor: el bracket_slot al bracket de perdedors.
  -- NULL al bracket de perdedors (el perdedor queda eliminat)
  -- i a la gran final.
  loser_slot_dest_id UUID REFERENCES public.handicap_bracket_slots(id) ON DELETE SET NULL,
  -- Snapshot de la distància de cada jugador en el moment del match.
  -- NULLABLE: en un match de bye no hi ha segon jugador (ni partida real),
  -- per tant les distàncies seran NULL quan estat='bye'.
  distancia_jugador1 SMALLINT,
  distancia_jugador2 SMALLINT,
  guanyador_participant_id UUID REFERENCES public.handicap_participants(id) ON DELETE SET NULL,
  estat TEXT NOT NULL DEFAULT 'pendent',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Estats vàlids del match
  CONSTRAINT handicap_matches_estat_check
    CHECK (estat IN ('pendent', 'programada', 'jugada', 'bye', 'walkover'))
);

COMMENT ON TABLE public.handicap_matches IS
  'Partides del torneig hàndicap. Linka dos bracket_slots i opcionalment una partida a calendari_partides.';
COMMENT ON COLUMN public.handicap_matches.calendari_partida_id IS
  'FK a calendari_partides. NULL fins programació. Conté data, hora, taula i resultats de caramboles.';
COMMENT ON COLUMN public.handicap_matches.distancia_jugador1 IS
  'Snapshot de la distància del jugador al slot1 en el moment del match. NULL per byes.';
COMMENT ON COLUMN public.handicap_matches.distancia_jugador2 IS
  'Snapshot de la distància del jugador al slot2 en el moment del match. NULL per byes.';
COMMENT ON COLUMN public.handicap_matches.guanyador_participant_id IS
  'Participant guanyador. NULL fins que es juga. En cas de bye, és el participant que avança.';

-- Índexos per handicap_matches
CREATE INDEX idx_handicap_matches_event ON public.handicap_matches (event_id);
CREATE INDEX idx_handicap_matches_calendari ON public.handicap_matches (calendari_partida_id);
CREATE INDEX idx_handicap_matches_slot1 ON public.handicap_matches (slot1_id);
CREATE INDEX idx_handicap_matches_slot2 ON public.handicap_matches (slot2_id);
CREATE INDEX idx_handicap_matches_estat ON public.handicap_matches (estat);


-- ============================================================================
-- FK circular: handicap_bracket_slots.source_match_id → handicap_matches(id)
-- Definida aquí perquè handicap_matches es crea després de bracket_slots.
-- ON DELETE SET NULL: si s'esborra el match, el slot no s'esborra (traçabilitat).
-- ============================================================================

ALTER TABLE public.handicap_bracket_slots
  ADD CONSTRAINT handicap_bracket_slots_source_match_fk
  FOREIGN KEY (source_match_id)
  REFERENCES public.handicap_matches(id)
  ON DELETE SET NULL;


-- ============================================================================
-- ROW LEVEL SECURITY
-- Patró idèntic a les taules existents:
--   SELECT: tothom (true) — dades de torneigs visibles per anon i authenticated
--   INSERT/UPDATE/DELETE: només usuaris autenticats (auth.uid() IS NOT NULL)
-- ============================================================================

-- handicap_config
ALTER TABLE public.handicap_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "handicap_config_select_all" ON public.handicap_config
  FOR SELECT USING (true);

CREATE POLICY "handicap_config_insert_auth" ON public.handicap_config
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "handicap_config_update_auth" ON public.handicap_config
  FOR UPDATE USING (auth.uid() IS NOT NULL);

CREATE POLICY "handicap_config_delete_auth" ON public.handicap_config
  FOR DELETE USING (auth.uid() IS NOT NULL);

-- handicap_participants
ALTER TABLE public.handicap_participants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "handicap_participants_select_all" ON public.handicap_participants
  FOR SELECT USING (true);

CREATE POLICY "handicap_participants_insert_auth" ON public.handicap_participants
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "handicap_participants_update_auth" ON public.handicap_participants
  FOR UPDATE USING (auth.uid() IS NOT NULL);

CREATE POLICY "handicap_participants_delete_auth" ON public.handicap_participants
  FOR DELETE USING (auth.uid() IS NOT NULL);

-- handicap_bracket_slots
ALTER TABLE public.handicap_bracket_slots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "handicap_bracket_slots_select_all" ON public.handicap_bracket_slots
  FOR SELECT USING (true);

CREATE POLICY "handicap_bracket_slots_insert_auth" ON public.handicap_bracket_slots
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "handicap_bracket_slots_update_auth" ON public.handicap_bracket_slots
  FOR UPDATE USING (auth.uid() IS NOT NULL);

CREATE POLICY "handicap_bracket_slots_delete_auth" ON public.handicap_bracket_slots
  FOR DELETE USING (auth.uid() IS NOT NULL);

-- handicap_matches
ALTER TABLE public.handicap_matches ENABLE ROW LEVEL SECURITY;

CREATE POLICY "handicap_matches_select_all" ON public.handicap_matches
  FOR SELECT USING (true);

CREATE POLICY "handicap_matches_insert_auth" ON public.handicap_matches
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "handicap_matches_update_auth" ON public.handicap_matches
  FOR UPDATE USING (auth.uid() IS NOT NULL);

CREATE POLICY "handicap_matches_delete_auth" ON public.handicap_matches
  FOR DELETE USING (auth.uid() IS NOT NULL);


-- ============================================================================
-- RESUM DE LA MIGRACIÓ
-- ============================================================================
--
-- Taules creades:
--
-- 1. handicap_config
--    - Configuració del torneig (1 per event)
--    - Sistema de puntuació: 'distancia' o 'percentatge'
--    - Distàncies per categoria en JSONB
--    - Horaris extra opcionals en JSONB
--
-- 2. handicap_participants
--    - Jugadors inscrits amb distància i seed
--    - UNIQUE (event_id, player_id)
--    - Flag 'eliminat' per marcar jugadors fora del torneig
--
-- 3. handicap_bracket_slots
--    - Estructura del quadre d'eliminació doble
--    - Brackets: winners, losers, grand_final
--    - UNIQUE (event_id, bracket_type, ronda, posicio)
--    - participant_id nullable (s'omple progressivament)
--
-- 4. handicap_matches
--    - Partides del torneig, linkades a calendari_partides via FK
--    - Snapshot de distàncies (nullable per byes)
--    - Estats: pendent, programada, jugada, bye, walkover
--    - Convenció: slot1=jugador1 (seed inferior a R1), slot2=jugador2
--    - Walkover es propaga idènticament a una victòria
--
-- Foreign keys:
--    - Totes ON DELETE CASCADE excepte:
--      · calendari_partida_id → ON DELETE SET NULL
--      · source_match_id → ON DELETE SET NULL
--      · winner_slot_dest_id → ON DELETE SET NULL
--      · loser_slot_dest_id → ON DELETE SET NULL
--      · guanyador_participant_id → ON DELETE SET NULL
--
-- RLS: SELECT per tothom, INSERT/UPDATE/DELETE per authenticated
--
-- NO es modifica cap taula existent.
-- NO es creen funcions RPC (vindran a fases posteriors).
-- ============================================================================
