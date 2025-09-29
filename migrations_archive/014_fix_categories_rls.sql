-- Migració 014: Corregir polítiques RLS per categories
-- Permet als admins crear/modificar categories

BEGIN;

-- Eliminar política existent (si existeix)
DROP POLICY IF EXISTS "Només admins poden gestionar campionats socials" ON categories;

-- Crear polítiques més específiques
CREATE POLICY "Admins poden crear categories"
    ON categories FOR INSERT TO authenticated
    WITH CHECK (EXISTS (SELECT 1 FROM admins WHERE email = auth.jwt() ->> 'email'));

CREATE POLICY "Admins poden modificar categories"
    ON categories FOR UPDATE TO authenticated
    USING (EXISTS (SELECT 1 FROM admins WHERE email = auth.jwt() ->> 'email'));

CREATE POLICY "Admins poden eliminar categories"
    ON categories FOR DELETE TO authenticated
    USING (EXISTS (SELECT 1 FROM admins WHERE email = auth.jwt() ->> 'email'));

-- Verificar que la política SELECT ja existeix (hauria d'existir de la migració anterior)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'categories'
        AND policyname = 'Usuaris autenticats poden veure categories'
    ) THEN
        CREATE POLICY "Usuaris autenticats poden veure categories"
            ON categories FOR SELECT TO authenticated USING (true);
    END IF;
END
$$;

COMMIT;