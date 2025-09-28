-- Crear taula per emmagatzemar el calendari de partides de lligues socials
CREATE TABLE calendari_partides (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  categoria_id UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  jugador1_id INTEGER NOT NULL REFERENCES socis(numero),
  jugador2_id INTEGER NOT NULL REFERENCES socis(numero),
  data_programada TIMESTAMP NOT NULL,
  hora_inici TEXT NOT NULL,
  taula_assignada INTEGER NOT NULL,
  estat TEXT NOT NULL DEFAULT 'generat' CHECK (estat IN ('generat', 'confirmat', 'jugat', 'cancel·lat')),
  resultat_jugador1 INTEGER,
  resultat_jugador2 INTEGER,
  guanyador_id INTEGER REFERENCES socis(numero),
  observacions TEXT,
  creat_el TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  actualitzat_el TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Crear taula per la configuració del calendari
CREATE TABLE configuracio_calendari (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE UNIQUE,
  dies_setmana TEXT[] NOT NULL DEFAULT ARRAY['dl', 'dt', 'dc', 'dj', 'dv'],
  hores_disponibles TEXT[] NOT NULL DEFAULT ARRAY['18:00', '19:00'],
  taules_per_slot INTEGER NOT NULL DEFAULT 3,
  max_partides_per_setmana INTEGER NOT NULL DEFAULT 2,
  max_partides_per_dia INTEGER NOT NULL DEFAULT 1,
  dies_festius DATE[] DEFAULT ARRAY[]::DATE[],
  creat_el TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  actualitzat_el TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índexs per optimitzar consultes
CREATE INDEX idx_calendari_partides_event_id ON calendari_partides(event_id);
CREATE INDEX idx_calendari_partides_categoria_id ON calendari_partides(categoria_id);
CREATE INDEX idx_calendari_partides_data ON calendari_partides(data_programada);
CREATE INDEX idx_calendari_partides_jugadors ON calendari_partides(jugador1_id, jugador2_id);

-- RLS (Row Level Security)
ALTER TABLE calendari_partides ENABLE ROW LEVEL SECURITY;
ALTER TABLE configuracio_calendari ENABLE ROW LEVEL SECURITY;

-- Policies per calendari_partides
CREATE POLICY "Calendari visible per tots els usuaris autenticats" ON calendari_partides
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Només admins poden gestionar calendari" ON calendari_partides
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM user_roles ur
            WHERE ur.email = auth.email()
            AND ur.role = 'admin'
            AND ur.active = true
        )
    );

-- Policies per configuracio_calendari
CREATE POLICY "Configuració visible per tots els usuaris autenticats" ON configuracio_calendari
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Només admins poden gestionar configuració calendari" ON configuracio_calendari
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM user_roles ur
            WHERE ur.email = auth.email()
            AND ur.role = 'admin'
            AND ur.active = true
        )
    );

-- Trigger per actualitzar timestamp
CREATE TRIGGER update_calendari_partides_timestamp
    BEFORE UPDATE ON calendari_partides
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_configuracio_calendari_timestamp
    BEFORE UPDATE ON configuracio_calendari
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();