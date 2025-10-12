-- Taula per emmagatzemar contingut editable de pàgines-- Taula per emmagatzemar contingut editable de pàgines

CREATE TABLE IF NOT EXISTS page_content (CREATE TABLE IF NOT EXISTS page_content (

    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    page_key VARCHAR(100) UNIQUE NOT NULL,    page_key VARCHAR(100) UNIQUE NOT NULL,

    title TEXT,    title TEXT,

    content TEXT,    content TEXT,

    updated_at TIMESTAMPTZ DEFAULT NOW(),    updated_at TIMESTAMPTZ DEFAULT NOW(),

    updated_by UUID REFERENCES auth.users(id),    updated_by UUID REFERENCES auth.users(id),

    created_at TIMESTAMPTZ DEFAULT NOW()    created_at TIMESTAMPTZ DEFAULT NOW()

););



-- Inserir contingut per defecte de la pàgina principal-- Inserir contingut per defecte de la pàgina principal (buit per defecte)

INSERT INTO page_content (page_key, title, content) INSERT INTO page_content (page_key, title, content) 

VALUES (VALUES (

    'home_main',    'home_main',

    'Secció de Billar del Foment Martinenc',    'Secció de Billar del Foment Martinenc',

    '<p>Contingut editable. Utilitza l''editor d''administració per afegir informació sobre la secció de billar.</p>'    '<p>Contingut editable. Utilitza l''editor d''administració per afegir informació sobre la secció de billar.</p>'

))

ON CONFLICT (page_key) DO NOTHING;ON CONFLICT (page_key) DO NOTHING;



-- Inserir horaris per defecte-- Inserir horaris per defecte

INSERT INTO page_content (page_key, title, content) INSERT INTO page_content (page_key, title, content) 

VALUES (VALUES (

    'horaris',    'horaris',

    'Horaris d''obertura',    'Horaris d''obertura',

    '<p><strong>Dilluns, dimecres, dijous, dissabte i diumenge:</strong> 9:00 – 21:00</p>    '<p><strong>Dilluns, dimecres, dijous, dissabte i diumenge:</strong> 9:00 – 21:00</p>

<p><strong>Dimarts i divendres:</strong> 10:30 – 21:30</p><p><strong>Dimarts i divendres:</strong> 10:30 – 21:30</p>

<div style="margin-top: 1rem; padding: 0.5rem; background-color: #dbeafe; border-radius: 0.25rem;"><div style="margin-top: 1rem; padding: 0.5rem; background-color: #dbeafe; border-radius: 0.25rem;">

  <p style="font-size: 0.875rem;">L''horari d''obertura pot canviar en funció dels horaris d''obertura del Bar del Foment.</p>  <p style="font-size: 0.875rem;">L''horari d''obertura pot canviar en funció dels horaris d''obertura del Bar del Foment.</p>

  <p style="margin-top: 0.25rem; font-size: 0.875rem;">L''horari d''atenció al públic del FOMENT és de <strong>DILLUNS A DIVENDRES de 9:00 A 13:00 i de 16:00 A 20:00</strong>.</p>  <p style="margin-top: 0.25rem; font-size: 0.875rem;">L''horari d''atenció al públic del FOMENT és de <strong>DILLUNS A DIVENDRES de 9:00 A 13:00 i de 16:00 A 20:00</strong>.</p>

  <p style="margin-top: 0.25rem; font-size: 0.875rem;">Les seccions poden tenir activitat fora d''aquest horari si el bar està obert, excepte <strong>AGOST i FESTIUS</strong>, quan el FOMENT resta oficialment tancat.</p>  <p style="margin-top: 0.25rem; font-size: 0.875rem;">Les seccions poden tenir activitat fora d''aquest horari si el bar està obert, excepte <strong>AGOST i FESTIUS</strong>, quan el FOMENT resta oficialment tancat.</p>

  <p style="margin-top: 0.25rem; font-size: 0.875rem;">La secció romandrà tancada els dies de <strong>TANCAMENT OFICIAL</strong> del FOMENT.</p>  <p style="margin-top: 0.25rem; font-size: 0.875rem;">La secció romandrà tancada els dies de <strong>TANCAMENT OFICIAL</strong> del FOMENT.</p>

</div>'</div>'

))

ON CONFLICT (page_key) DO NOTHING;ON CONFLICT (page_key) DO NOTHING;



-- Inserir normes obligatòries per defecte-- Inserir normes obligatòries per defecte

INSERT INTO page_content (page_key, title, content) INSERT INTO page_content (page_key, title, content) 

VALUES (VALUES (

    'normes_obligatories',    'normes_obligatories',

    'OBLIGATORI',    'OBLIGATORI',

    '<p>Netejar el billar i les boles abans de començar cada partida amb el material que la Secció posa a disposició de tots els socis.</p>'    '<p>Netejar el billar i les boles abans de començar cada partida amb el material que la Secció posa a disposició de tots els socis.</p>'

))

ON CONFLICT (page_key) DO NOTHING;ON CONFLICT (page_key) DO NOTHING;



-- Inserir prohibicions per defecte-- Inserir prohibicions per defecte

INSERT INTO page_content (page_key, title, content) INSERT INTO page_content (page_key, title, content) 

VALUES (VALUES (

    'prohibicions',    'prohibicions',

    'PROHIBIT',    'PROHIBIT',

    '<ul>    '<ul>

<li>Jugar a fantasia</li><li>Jugar a fantasia</li>

<li>Menjar mentre s''està jugant</li><li>Menjar mentre s''està jugant</li>

<li>Posar begudes sobre cap element del billar</li><li>Posar begudes sobre cap element del billar</li>

</ul>'</ul>'

))

ON CONFLICT (page_key) DO NOTHING;ON CONFLICT (page_key) DO NOTHING;



-- Inserir normes d'inscripció per defecte-- Inserir normes d'inscripció per defecte

INSERT INTO page_content (page_key, title, content) INSERT INTO page_content (page_key, title, content) 

VALUES (VALUES (

    'normes_inscripcio',    'normes_inscripcio',

    'Inscripció a les partides',    'Inscripció a les partides',

    '<ul>    '<ul>

<li>Apunta''t a la pissarra única de <strong>PARTIDES SOCIALS</strong></li><li>Apunta''t a la pissarra única de <strong>PARTIDES SOCIALS</strong></li>

<li>Els companys no cal que s''apuntin; si ho fan, que sigui al costat del primer jugador</li><li>Els companys no cal que s''apuntin; si ho fan, que sigui al costat del primer jugador</li>

</ul>'</ul>'

))

ON CONFLICT (page_key) DO NOTHING;ON CONFLICT (page_key) DO NOTHING;



-- Inserir normes d'assignació per defecte-- Inserir normes d'assignació per defecte

INSERT INTO page_content (page_key, title, content) INSERT INTO page_content (page_key, title, content) 

VALUES (VALUES (

    'normes_assignacio',    'normes_assignacio',

    'Assignació de taula',    'Assignació de taula',

    '<ul>    '<ul>

<li>Quan hi hagi una taula lliure, ratlla el teu nom i juga</li><li>Quan hi hagi una taula lliure, ratlla el teu nom i juga</li>

<li>Si vols una taula concreta ocupada, passa el torn fins que s''alliberi</li><li>Si vols una taula concreta ocupada, passa el torn fins que s''alliberi</li>

</ul>'</ul>'

))

ON CONFLICT (page_key) DO NOTHING;ON CONFLICT (page_key) DO NOTHING;



-- Inserir normes de temps per defecte-- Inserir normes de temps per defecte

INSERT INTO page_content (page_key, title, content) INSERT INTO page_content (page_key, title, content) 

VALUES (VALUES (

    'normes_temps',    'normes_temps',

    'Temps de joc',    'Temps de joc',

    '<ul>    '<ul>

<li><strong>Màxim 1 hora</strong> per partida (sol o en grup)</li><li><strong>Màxim 1 hora</strong> per partida (sol o en grup)</li>

<li><strong>PROHIBIT</strong> posar monedes per allargar el temps, encara que hi hagi taules lliures</li><li><strong>PROHIBIT</strong> posar monedes per allargar el temps, encara que hi hagi taules lliures</li>

</ul>'</ul>'

))

ON CONFLICT (page_key) DO NOTHING;ON CONFLICT (page_key) DO NOTHING;



-- Inserir normes per repetir per defecte-- Inserir normes per repetir per defecte

INSERT INTO page_content (page_key, title, content) INSERT INTO page_content (page_key, title, content) 

VALUES (VALUES (

    'normes_repetir',    'normes_repetir',

    'Tornar a jugar',    'Tornar a jugar',

    '<p>Només pots repetir si no hi ha ningú apuntat i hi ha una taula lliure.</p>'    '<p>Només pots repetir si no hi ha ningú apuntat i hi ha una taula lliure.</p>'

))

ON CONFLICT (page_key) DO NOTHING;ON CONFLICT (page_key) DO NOTHING;



-- Inserir serveis al soci per defecte-- Inserir serveis al soci per defecte

INSERT INTO page_content (page_key, title, content) INSERT INTO page_content (page_key, title, content) 

VALUES (VALUES (

    'serveis_soci',    'serveis_soci',

    'Serveis al Soci',    'Serveis al Soci',

    '<p>La Secció disposa d''una petita botiga d''accessoris com:</p>    '<p>La Secció disposa d''una petita botiga d''accessoris com:</p>

<ul><ul>

<li>Guants</li><li>Guants</li>

<li>Guixos</li><li>Guixos</li>

<li>Manguitos</li><li>Manguitos</li>

<li>Altres accessoris</li><li>Altres accessoris</li>

</ul></ul>

<p style="margin-top: 1rem;">També oferim <strong>servei de canvi de soles</strong> per mantenir els teus tacs en perfecte estat.</p>'<p style="margin-top: 1rem;">També oferim <strong>servei de canvi de soles</strong> per mantenir els teus tacs en perfecte estat.</p>'

))

ON CONFLICT (page_key) DO NOTHING;ON CONFLICT (page_key) DO NOTHING;



-- Habilitar RLS-- Habilitar RLS

ALTER TABLE page_content ENABLE ROW LEVEL SECURITY;ALTER TABLE page_content ENABLE ROW LEVEL SECURITY;



-- Esborrar polítiques existents si ja existeixen-- Esborrar polítiques existents si ja existeixen

DROP POLICY IF EXISTS "Anyone can read page content" ON page_content;DROP POLICY IF EXISTS "Anyone can read page content" ON page_content;

DROP POLICY IF EXISTS "Only admins can update page content" ON page_content;DROP POLICY IF EXISTS "Only admins can update page content" ON page_content;

DROP POLICY IF EXISTS "Only admins can insert page content" ON page_content;DROP POLICY IF EXISTS "Only admins can insert page content" ON page_content;



-- Política: Tothom pot llegir-- Política: Tothom pot llegir

CREATE POLICY "Anyone can read page content"CREATE POLICY "Anyone can read page content"

    ON page_content    ON page_content

    FOR SELECT    FOR SELECT

    USING (true);    USING (true);



-- Política: Usuaris autenticats poden editar (simplificat temporalment)-- Política: Usuaris autenticats poden editar (simplificat temporalment)

CREATE POLICY "Only admins can update page content"CREATE POLICY "Only admins can update page content"

    ON page_content    ON page_content

    FOR UPDATE    FOR UPDATE

    USING (auth.uid() IS NOT NULL);    USING (auth.uid() IS NOT NULL);



-- Política: Usuaris autenticats poden inserir (simplificat temporalment)-- Política: Usuaris autenticats poden inserir (simplificat temporalment)

CREATE POLICY "Only admins can insert page content"CREATE POLICY "Only admins can insert page content"

    ON page_content    ON page_content

    FOR INSERT    FOR INSERT

    WITH CHECK (auth.uid() IS NOT NULL);    WITH CHECK (auth.uid() IS NOT NULL);



-- Crear índex per page_key-- Crear índex per page_key

CREATE INDEX IF NOT EXISTS idx_page_content_page_key ON page_content(page_key);CREATE INDEX IF NOT EXISTS idx_page_content_page_key ON page_content(page_key);



-- Funció per actualitzar updated_at automàticament-- Funció per actualitzar updated_at automàticament

CREATE OR REPLACE FUNCTION update_page_content_updated_at()CREATE OR REPLACE FUNCTION update_page_content_updated_at()

RETURNS TRIGGER AS $$RETURNS TRIGGER AS $$

BEGINBEGIN

    NEW.updated_at = NOW();    NEW.updated_at = NOW();

    RETURN NEW;    RETURN NEW;

END;END;

$$ LANGUAGE plpgsql;$$ LANGUAGE plpgsql;



-- Trigger per actualitzar updated_at-- Trigger per actualitzar updated_at

DROP TRIGGER IF EXISTS update_page_content_updated_at ON page_content;DROP TRIGGER IF EXISTS update_page_content_updated_at ON page_content;

CREATE TRIGGER update_page_content_updated_atCREATE TRIGGER update_page_content_updated_at

    BEFORE UPDATE ON page_content    BEFORE UPDATE ON page_content

    FOR EACH ROW    FOR EACH ROW

    EXECUTE FUNCTION update_page_content_updated_at();    EXECUTE FUNCTION update_page_content_updated_at();

