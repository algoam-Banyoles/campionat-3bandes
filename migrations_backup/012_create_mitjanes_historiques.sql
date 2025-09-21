-- Crear taula mitjanes_historiques
CREATE TABLE IF NOT EXISTS mitjanes_historiques (
    id SERIAL PRIMARY KEY,
    soci_id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    modalitat VARCHAR(20) NOT NULL,
    mitjana DECIMAL(5,3) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(soci_id, year, modalitat)
);

-- Crear índexs per millor rendiment
CREATE INDEX IF NOT EXISTS idx_mitjanes_historiques_soci_id ON mitjanes_historiques(soci_id);
CREATE INDEX IF NOT EXISTS idx_mitjanes_historiques_year ON mitjanes_historiques(year);
CREATE INDEX IF NOT EXISTS idx_mitjanes_historiques_modalitat ON mitjanes_historiques(modalitat);

-- Habilitar RLS
ALTER TABLE mitjanes_historiques ENABLE ROW LEVEL SECURITY;

-- Política per permetre lectura a tots els usuaris autenticats
CREATE POLICY "Mitjanes històriques són públiques" ON mitjanes_historiques
FOR SELECT TO authenticated, anon
USING (true);