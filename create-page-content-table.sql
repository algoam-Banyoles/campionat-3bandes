-- ============================================
-- Taula per emmagatzemar contingut editable de pàgines
-- Sistema de gestió de contingut (CMS) per la pàgina d'inici
-- ============================================

CREATE TABLE IF NOT EXISTS page_content (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    page_key VARCHAR(100) UNIQUE NOT NULL,
    title TEXT,
    content TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- Contingut per defecte de totes les seccions
-- ============================================

-- Secció principal
INSERT INTO page_content (page_key, title, content) 
VALUES (
    'home_main',
    'Secció de Billar del Foment Martinenc',
    '<p>Informació general i calendari d''activitats</p>'
)
ON CONFLICT (page_key) DO NOTHING;

-- Horaris d'obertura
INSERT INTO page_content (page_key, title, content) 
VALUES (
    'horaris',
    'Horari d''obertura de la Secció',
    '<p><strong>Dilluns, dimecres, dijous, dissabte i diumenge:</strong> 9:00 – 21:30</p>
<p><strong>Dimarts i divendres:</strong> 10:30 – 21:30</p>
<div style="margin-top: 1rem; padding: 0.5rem; background-color: #dbeafe; border-radius: 0.25rem; font-size: 0.875rem;">
  <p>L''horari d''obertura pot canviar en funció dels horaris d''obertura del Bar del Foment.</p>
  <p style="margin-top: 0.25rem;">L''horari d''atenció al públic del FOMENT és de <strong>DILLUNS A DIVENDRES de 9:00 A 13:00 i de 16:00 A 20:00</strong>.</p>
  <p style="margin-top: 0.25rem;">Les seccions poden tenir activitat fora d''aquest horari si el bar està obert, excepte <strong>AGOST i FESTIUS</strong>, quan el FOMENT resta oficialment tancat.</p>
  <p style="margin-top: 0.25rem;">La secció romandrà tancada els dies de <strong>TANCAMENT OFICIAL</strong> del FOMENT.</p>
</div>'
)
ON CONFLICT (page_key) DO NOTHING;

-- Normes obligatòries
INSERT INTO page_content (page_key, title, content) 
VALUES (
    'normes_obligatories',
    'OBLIGATORI',
    '<p>Netejar el billar i les boles abans de començar cada partida amb el material que la Secció posa a disposició de tots els socis.</p>'
)
ON CONFLICT (page_key) DO NOTHING;

-- Prohibicions
INSERT INTO page_content (page_key, title, content) 
VALUES (
    'prohibicions',
    'PROHIBIT',
    '<ul>
<li>Jugar a fantasia</li>
<li>Menjar mentre s''està jugant</li>
<li>Posar begudes sobre cap element del billar</li>
</ul>'
)
ON CONFLICT (page_key) DO NOTHING;

-- Normes d'inscripció
INSERT INTO page_content (page_key, title, content) 
VALUES (
    'normes_inscripcio',
    'Inscripció a les partides',
    '<ul>
<li>Apunta''t a la pissarra única de <strong>PARTIDES SOCIALS</strong></li>
<li>Els companys no cal que s''apuntin; si ho fan, que sigui al costat del primer jugador</li>
</ul>'
)
ON CONFLICT (page_key) DO NOTHING;

-- Normes d'assignació de taula
INSERT INTO page_content (page_key, title, content) 
VALUES (
    'normes_assignacio',
    'Assignació de taula',
    '<ul>
<li>Quan hi hagi una taula lliure, ratlla el teu nom i juga</li>
<li>Si vols una taula concreta ocupada, passa el torn fins que s''alliberi</li>
</ul>'
)
ON CONFLICT (page_key) DO NOTHING;

-- Normes de temps de joc
INSERT INTO page_content (page_key, title, content) 
VALUES (
    'normes_temps',
    'Temps de joc',
    '<ul>
<li><strong>Màxim 1 hora</strong> per partida (sol o en grup)</li>
<li><strong>PROHIBIT</strong> posar monedes per allargar el temps, encara que hi hagi taules lliures</li>
</ul>'
)
ON CONFLICT (page_key) DO NOTHING;

-- Normes per repetir partida
INSERT INTO page_content (page_key, title, content) 
VALUES (
    'normes_repetir',
    'Tornar a jugar',
    '<p>Només pots repetir si no hi ha ningú apuntat i hi ha una taula lliure.</p>'
)
ON CONFLICT (page_key) DO NOTHING;

-- Serveis al soci (NOVA SECCIÓ)
INSERT INTO page_content (page_key, title, content) 
VALUES (
    'serveis_soci',
    'Serveis al Soci',
    '<p>La Secció disposa d''una petita botiga d''accessoris com:</p>
<ul>
<li>Guants</li>
<li>Guixos</li>
<li>Manguitos</li>
<li>Altres accessoris</li>
</ul>
<p style="margin-top: 1rem;">També oferim <strong>servei de canvi de soles</strong> per mantenir els teus tacs en perfecte estat.</p>'
)
ON CONFLICT (page_key) DO NOTHING;

-- ============================================
-- Row Level Security (RLS)
-- ============================================

ALTER TABLE page_content ENABLE ROW LEVEL SECURITY;

-- Esborrar polítiques existents si ja existeixen
DROP POLICY IF EXISTS "Anyone can read page content" ON page_content;
DROP POLICY IF EXISTS "Only admins can update page content" ON page_content;
DROP POLICY IF EXISTS "Only admins can insert page content" ON page_content;

-- Política de lectura: Tothom pot llegir
CREATE POLICY "Anyone can read page content"
    ON page_content
    FOR SELECT
    USING (true);

-- Política d'edició: Només usuaris autenticats
CREATE POLICY "Only admins can update page content"
    ON page_content
    FOR UPDATE
    USING (auth.uid() IS NOT NULL);

-- Política d'inserció: Només usuaris autenticats
CREATE POLICY "Only admins can insert page content"
    ON page_content
    FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL);

-- ============================================
-- Índexs per optimitzar consultes
-- ============================================

CREATE INDEX IF NOT EXISTS idx_page_content_page_key ON page_content(page_key);

-- ============================================
-- Trigger per actualitzar updated_at automàticament
-- ============================================

CREATE OR REPLACE FUNCTION update_page_content_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_page_content_updated_at ON page_content;

CREATE TRIGGER trigger_update_page_content_updated_at
    BEFORE UPDATE ON page_content
    FOR EACH ROW
    EXECUTE FUNCTION update_page_content_updated_at();
