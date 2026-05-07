-- Performance: drop d'índexs duplicats i creació d'índexs covering per a FKs.
--
-- Detall:
--   * Quan dues definicions són idèntiques, mantenim el UNIQUE/PK i deixem
--     anar el genèric (que és redundant).
--   * Per a parelles de no-unique idèntiques, mantenim el de nom més
--     consistent amb la convenció del repo (`idx_*`).
--   * Afegim CREATE INDEX IF NOT EXISTS per a les FKs sense covering, en
--     concurrent quan és possible (no, en migració). Volem operacions
--     ràpides; les taules són petites, no cal CONCURRENTLY.

----------------------------------------------------------------------
-- A) Drop d'índexs duplicats
----------------------------------------------------------------------
DROP INDEX IF EXISTS public.idx_categories_ordre;                              -- conserva categories_ordre_unique
DROP INDEX IF EXISTS public.idx_classificacions_categoria;                     -- conserva classificacions_posicio_categoria_unique
DROP INDEX IF EXISTS public.idx_initial_ranking_event;                         -- conserva initial_ranking_pkey
-- mitjanes_historiques: l'índex està suportat per un UNIQUE constraint —
-- cal eliminar el constraint perquè drop l'índex.
ALTER TABLE public.mitjanes_historiques
  DROP CONSTRAINT IF EXISTS mitjanes_historiques_soci_year_modalitat_key;
DROP INDEX IF EXISTS public.idx_page_content_page_key;                         -- conserva page_content_page_key_key
DROP INDEX IF EXISTS public.idx_rp_event_pos;                                  -- conserva ranking_positions_pkey
DROP INDEX IF EXISTS public.waiting_list_event_ordre_idx;                      -- conserva idx_waiting_list_event_ordre
DROP INDEX IF EXISTS public.ix_waiting_ordre;                                  -- conserva idx_waiting_ordre

----------------------------------------------------------------------
-- B) Índexs covering per a foreign keys sense índex
----------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_calendari_partides_aprovat_canvi_per
  ON public.calendari_partides(aprovat_canvi_per);
CREATE INDEX IF NOT EXISTS idx_calendari_partides_categoria_id
  ON public.calendari_partides(categoria_id);
CREATE INDEX IF NOT EXISTS idx_calendari_partides_match_id
  ON public.calendari_partides(match_id);
CREATE INDEX IF NOT EXISTS idx_calendari_partides_validat_per
  ON public.calendari_partides(validat_per);
CREATE INDEX IF NOT EXISTS idx_challenges_event_id
  ON public.challenges(event_id);
CREATE INDEX IF NOT EXISTS idx_classificacions_event_id
  ON public.classificacions(event_id);
CREATE INDEX IF NOT EXISTS idx_esdeveniments_club_creat_per
  ON public.esdeveniments_club(creat_per);
CREATE INDEX IF NOT EXISTS idx_handicap_bracket_slots_source_match
  ON public.handicap_bracket_slots(source_match_id);
CREATE INDEX IF NOT EXISTS idx_handicap_matches_guanyador_participant
  ON public.handicap_matches(guanyador_participant_id);
CREATE INDEX IF NOT EXISTS idx_handicap_matches_loser_slot_dest
  ON public.handicap_matches(loser_slot_dest_id);
CREATE INDEX IF NOT EXISTS idx_handicap_matches_winner_slot_dest
  ON public.handicap_matches(winner_slot_dest_id);
CREATE INDEX IF NOT EXISTS idx_history_position_changes_ref_challenge
  ON public.history_position_changes(ref_challenge);
CREATE INDEX IF NOT EXISTS idx_inscripcions_categoria_assignada
  ON public.inscripcions(categoria_assignada_id);
CREATE INDEX IF NOT EXISTS idx_matches_categoria_id
  ON public.matches(categoria_id);
CREATE INDEX IF NOT EXISTS idx_notes_user_id
  ON public.notes(user_id);
CREATE INDEX IF NOT EXISTS idx_page_content_updated_by
  ON public.page_content(updated_by);
CREATE INDEX IF NOT EXISTS idx_penalties_challenge_id
  ON public.penalties(challenge_id);
CREATE INDEX IF NOT EXISTS idx_penalties_event_id
  ON public.penalties(event_id);
CREATE INDEX IF NOT EXISTS idx_scheduled_notifications_challenge_id
  ON public.scheduled_notifications(challenge_id);
