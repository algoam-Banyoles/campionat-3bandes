-- Crear taula per enllaços multimedia
CREATE TABLE IF NOT EXISTS multimedia_links (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  tipus TEXT NOT NULL,
  club TEXT NOT NULL,
  billar TEXT DEFAULT '',
  enllac TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índexs per millorar el rendiment
CREATE INDEX IF NOT EXISTS idx_multimedia_tipus ON multimedia_links(tipus);
CREATE INDEX IF NOT EXISTS idx_multimedia_club ON multimedia_links(club);

-- RLS policies: tothom pot llegir, només admins poden modificar
ALTER TABLE multimedia_links ENABLE ROW LEVEL SECURITY;

-- Policy per llegir: tothom pot veure els enllaços
CREATE POLICY "multimedia_links_select_all" ON multimedia_links
  FOR SELECT
  USING (true);

-- Policy per inserir: només usuaris autenticats
CREATE POLICY "multimedia_links_insert_auth" ON multimedia_links
  FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- Policy per actualitzar: només usuaris autenticats
CREATE POLICY "multimedia_links_update_auth" ON multimedia_links
  FOR UPDATE
  USING (auth.uid() IS NOT NULL)
  WITH CHECK (auth.uid() IS NOT NULL);

-- Policy per eliminar: només usuaris autenticats
CREATE POLICY "multimedia_links_delete_auth" ON multimedia_links
  FOR DELETE
  USING (auth.uid() IS NOT NULL);

-- Funció per actualitzar updated_at
CREATE OR REPLACE FUNCTION update_multimedia_links_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger per actualitzar updated_at automàticament
CREATE TRIGGER update_multimedia_links_updated_at
  BEFORE UPDATE ON multimedia_links
  FOR EACH ROW
  EXECUTE FUNCTION update_multimedia_links_updated_at();
