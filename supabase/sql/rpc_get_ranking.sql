DROP FUNCTION IF EXISTS public.get_ranking();
CREATE OR REPLACE FUNCTION public.get_ranking()
RETURNS TABLE(
  posicio smallint,
  player_id uuid,
  nom text,
  cognoms text,
  mitjana numeric,
  estat text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT rp.posicio,
         rp.player_id,
         COALESCE(s.nom, p.nom) as nom,
         s.cognoms,
         p.mitjana,
         p.estat::text AS estat
    FROM ranking_positions rp
    JOIN players p ON p.id = rp.player_id
    LEFT JOIN socis s ON s.numero_soci = p.numero_soci
   WHERE rp.event_id = (
          SELECT id
            FROM events
           WHERE actiu IS TRUE
           ORDER BY creat_el DESC
           LIMIT 1
        )
   ORDER BY rp.posicio;
$$;
GRANT EXECUTE ON FUNCTION public.get_ranking() TO authenticated;
