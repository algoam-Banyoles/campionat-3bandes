-- Script per crear políticas RLS per a mitjanes_historiques
-- Permet lectura i escriptura per a usuaris autenticats i administradors

-- Activar RLS si no està activat (ja ho està)
ALTER TABLE mitjanes_historiques ENABLE ROW LEVEL SECURITY;

-- Política per permetre lectura a tots els usuaris autenticats
DROP POLICY IF EXISTS "mitjanes_historiques_read_policy" ON mitjanes_historiques;
CREATE POLICY "mitjanes_historiques_read_policy" ON mitjanes_historiques
    FOR SELECT 
    USING (true);

-- Política per permetre escriptura només a administradors
DROP POLICY IF EXISTS "mitjanes_historiques_write_policy" ON mitjanes_historiques;
CREATE POLICY "mitjanes_historiques_write_policy" ON mitjanes_historiques
    FOR ALL 
    USING (
        auth.jwt() ->> 'email' IN (
            SELECT email FROM players WHERE is_admin = true
        )
    );

-- També necessitem permetre l'accés a la taula socis per als joins
ALTER TABLE socis ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "socis_read_policy" ON socis;
CREATE POLICY "socis_read_policy" ON socis
    FOR SELECT 
    USING (true);

-- Verifica que les polítiques s'han creat correctament
SELECT tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename IN ('mitjanes_historiques', 'socis')
ORDER BY tablename, policyname;