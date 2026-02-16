-- Afegir camp per marcar si el calendari d'un esdeveniment està publicat
ALTER TABLE events ADD COLUMN IF NOT EXISTS calendari_publicat BOOLEAN DEFAULT FALSE;

-- Crear índex per optimitzar les consultes
CREATE INDEX IF NOT EXISTS idx_events_calendari_publicat ON events(calendari_publicat);