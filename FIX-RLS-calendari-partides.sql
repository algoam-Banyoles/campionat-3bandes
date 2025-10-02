-- ============================================================================
-- FIX: Permetre UPDATE a calendari_partides per ADMINS
-- ============================================================================
-- Executar al Supabase SQL Editor
--
-- Problema: Els admins no poden actualitzar resultats a calendari_partides
-- Solució: Afegir política RLS que permet UPDATE només als emails admin
-- ============================================================================

-- Eliminar la política existent si existeix
DROP POLICY IF EXISTS "Admins can update match results" ON calendari_partides;

-- Crear nova política d'UPDATE per admins
CREATE POLICY "Admins can update match results"
ON calendari_partides
FOR UPDATE
TO authenticated
USING (
  -- Només permetre UPDATE si l'usuari és admin
  auth.jwt()->>'email' IN (
    'admin@campionat3bandes.com',
    'junta@campionat3bandes.com',
    'algoam@gmail.com'
  )
)
WITH CHECK (
  -- Mateix check: només admins
  auth.jwt()->>'email' IN (
    'admin@campionat3bandes.com',
    'junta@campionat3bandes.com',
    'algoam@gmail.com'
  )
);

-- Verificar que la política s'ha creat
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd
FROM pg_policies
WHERE tablename = 'calendari_partides'
AND policyname = 'Admins can update match results';
