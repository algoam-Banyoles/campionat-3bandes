DROP FUNCTION IF EXISTS public.get_waiting_list();
CREATE OR REPLACE FUNCTION public.get_waiting_list()
RETURNS TABLE(
  ordre integer,
  nom text,
  data_inscripcio timestamptz,
  player_id uuid
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT w.ordre,
         p.nom,
         w.data_inscripcio,
         w.player_id
    FROM waiting_list w
    JOIN players p ON p.id = w.player_id
   WHERE w.event_id = (
          SELECT id
            FROM events
           WHERE actiu IS TRUE
           ORDER BY creat_el DESC
           LIMIT 1
        )
   ORDER BY w.ordre;
$$;
GRANT EXECUTE ON FUNCTION public.get_waiting_list() TO authenticated;
