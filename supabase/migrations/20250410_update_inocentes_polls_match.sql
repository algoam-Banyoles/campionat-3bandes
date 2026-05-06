-- Update Inocentes vs Polls match to "pendent_programar"
-- Match ID: 892f8de0-7f93-40c9-9da7-fa9fda092586

UPDATE public.calendari_partides
SET estat = 'pendent_programar'
WHERE id = '892f8de0-7f93-40c9-9da7-fa9fda092586';

-- Verify the update
SELECT id, jugador1_soci_numero, jugador2_soci_numero, estat, data_programada
FROM public.calendari_partides
WHERE id = '892f8de0-7f93-40c9-9da7-fa9fda092586';
