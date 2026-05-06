-- Allow anonymous users to see unprogrammed matches (pendent_programar) in published calendars
-- Previous policy only showed 'validat', 'confirmat', 'jugada', 'jugat'
-- Now includes 'pendent_programar' for visibility

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
      AND calendari_partides.estat = ANY (ARRAY['validat', 'confirmat', 'jugada', 'jugat', 'pendent_programar'])
  )
);
