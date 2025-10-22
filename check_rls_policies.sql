-- Verificar les polítiques RLS actuals per esdeveniments_club
SELECT
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'esdeveniments_club'
ORDER BY policyname;
