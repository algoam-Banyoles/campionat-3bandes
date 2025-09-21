-- Script per assegurar que la taula socis té els camps necessaris
-- Executar abans de inserir els exsocis

-- Verificar/crear camp 'estat' si no existeix
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'socis' AND column_name = 'estat'
    ) THEN
        ALTER TABLE socis ADD COLUMN estat VARCHAR(20) DEFAULT 'actiu';
    END IF;
END $$;

-- Verificar/crear camp 'data_baixa' si no existeix  
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'socis' AND column_name = 'data_baixa'
    ) THEN
        ALTER TABLE socis ADD COLUMN data_baixa DATE NULL;
    END IF;
END $$;

-- Verificar/crear camp 'observacions' si no existeix
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'socis' AND column_name = 'observacions'
    ) THEN
        ALTER TABLE socis ADD COLUMN observacions TEXT NULL;
    END IF;
END $$;

-- Crear índex per millorar consultes per estat
CREATE INDEX IF NOT EXISTS idx_socis_estat ON socis(estat);

-- Mostrar esquema actual de la taula socis
SELECT column_name, data_type, is_nullable, column_default 
FROM information_schema.columns 
WHERE table_name = 'socis' 
ORDER BY ordinal_position;
