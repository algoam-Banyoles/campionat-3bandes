-- Permet que anons vegin classificacions (són dades públiques d'un campionat).
-- La informació ja es mostra a la web sense autenticació via RPC SECURITY DEFINER,
-- però afegir la policy fa coherent l'accés directe (ex: via API PostgREST).

DROP POLICY IF EXISTS "Classificacions publicament llegibles" ON public.classificacions;

CREATE POLICY "Classificacions publicament llegibles"
ON public.classificacions
FOR SELECT
TO anon, authenticated
USING (true);
