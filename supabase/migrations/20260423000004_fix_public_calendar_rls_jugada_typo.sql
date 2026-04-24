-- Fix: la policy pública de calendari_partides feia servir l'estat 'jugat' (typo)
-- que no existeix: les partides jugades tenen estat 'jugada'. Això bloquejava als
-- anònims (no-autenticats) la visualització de partides amb resultat, i el modal
-- de PlayerResultsModal retornava 0 files quan s'obria sense sessió.

DROP POLICY IF EXISTS "Public access to published calendar matches" ON public.calendari_partides;

CREATE POLICY "Public access to published calendar matches"
ON public.calendari_partides
FOR SELECT
TO public
USING (
  EXISTS (
    SELECT 1 FROM events e
    WHERE e.id = calendari_partides.event_id
      AND e.calendari_publicat = true
      AND calendari_partides.estat = ANY (ARRAY['validat', 'confirmat', 'jugada', 'jugat'])
  )
);
