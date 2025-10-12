--
-- Schema de la base de dades Supabase
-- Generat automàticament: 12/10/2025 15:46:58
--

-- NOTA: Aquest schema és una reconstrucció basada en les taules accessibles.
-- Per obtenir l'schema complet amb tipus exactes, constraints i índexs,
-- utilitza: supabase db dump -f schema-cloud.sql

-- ============================================
-- TAULA: socis
-- ============================================


CREATE TABLE IF NOT EXISTS public.socis (
  numero_soci INTEGER PRIMARY KEY,
  cognoms TEXT NOT NULL,
  nom TEXT NOT NULL,
  email TEXT,
  de_baixa BOOLEAN DEFAULT false,
  data_baixa DATE
);

-- Índexs
CREATE INDEX IF NOT EXISTS idx_socis_cognoms ON public.socis(cognoms);
CREATE INDEX IF NOT EXISTS idx_socis_email ON public.socis(email);
CREATE INDEX IF NOT EXISTS idx_socis_baixa ON public.socis(de_baixa) WHERE de_baixa = false;

-- RLS
ALTER TABLE public.socis ENABLE ROW LEVEL SECURITY;

CREATE POLICY "socis_select_all" ON public.socis
  FOR SELECT USING (true);

CREATE POLICY "socis_update_admin" ON public.socis
  FOR UPDATE USING (auth.uid() IS NOT NULL);


-- ============================================
-- TAULA: calendari_partides
-- ============================================


CREATE TABLE IF NOT EXISTS public.calendari_partides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id TEXT,
  categoria_id TEXT,
  jugador1_id INTEGER REFERENCES public.socis(numero_soci),
  jugador2_id INTEGER REFERENCES public.socis(numero_soci),
  data_programada DATE,
  hora_inici TIME,
  taula_assignada INTEGER,
  estat TEXT DEFAULT 'programada',
  validat_per INTEGER REFERENCES public.socis(numero_soci),
  data_validacio TIMESTAMPTZ,
  observacions_junta TEXT,
  data_canvi_solicitada DATE,
  motiu_canvi TEXT,
  aprovat_canvi_per INTEGER REFERENCES public.socis(numero_soci),
  data_aprovacio_canvi TIMESTAMPTZ,
  match_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  caramboles_jugador1 INTEGER,
  caramboles_jugador2 INTEGER,
  entrades INTEGER,
  data_joc DATE
);

-- Índexs
CREATE INDEX IF NOT EXISTS idx_calendari_jugador1 ON public.calendari_partides(jugador1_id);
CREATE INDEX IF NOT EXISTS idx_calendari_jugador2 ON public.calendari_partides(jugador2_id);
CREATE INDEX IF NOT EXISTS idx_calendari_data ON public.calendari_partides(data_programada);
CREATE INDEX IF NOT EXISTS idx_calendari_estat ON public.calendari_partides(estat);
CREATE INDEX IF NOT EXISTS idx_calendari_event ON public.calendari_partides(event_id);

-- RLS
ALTER TABLE public.calendari_partides ENABLE ROW LEVEL SECURITY;

CREATE POLICY "calendari_select_all" ON public.calendari_partides
  FOR SELECT USING (true);

CREATE POLICY "calendari_insert_auth" ON public.calendari_partides
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "calendari_update_auth" ON public.calendari_partides
  FOR UPDATE USING (auth.uid() IS NOT NULL);


-- ============================================
-- TAULA: mitjanes_historiques
-- ============================================


CREATE TABLE IF NOT EXISTS public.mitjanes_historiques (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  soci_id INTEGER REFERENCES public.socis(numero_soci),
  year INTEGER NOT NULL,
  modalitat TEXT NOT NULL,
  mitjana NUMERIC(5,3),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índexs
CREATE UNIQUE INDEX IF NOT EXISTS idx_mitjanes_unique ON public.mitjanes_historiques(soci_id, year, modalitat);
CREATE INDEX IF NOT EXISTS idx_mitjanes_year ON public.mitjanes_historiques(year);

-- RLS
ALTER TABLE public.mitjanes_historiques ENABLE ROW LEVEL SECURITY;

CREATE POLICY "mitjanes_select_all" ON public.mitjanes_historiques
  FOR SELECT USING (true);


-- ============================================
-- TAULA: esdeveniments_club
-- ============================================


CREATE TABLE IF NOT EXISTS public.esdeveniments_club (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id TEXT UNIQUE NOT NULL,
  titol TEXT NOT NULL,
  descripcio TEXT,
  data_inici TIMESTAMPTZ NOT NULL,
  data_fi TIMESTAMPTZ,
  tipus TEXT NOT NULL, -- 'campionat-social', 'torneig', 'activitat'
  subtipus TEXT,
  estat TEXT DEFAULT 'programat', -- 'programat', 'en-curs', 'finalitzat', 'cancel·lat'
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índexs
CREATE INDEX IF NOT EXISTS idx_esdeveniments_event_id ON public.esdeveniments_club(event_id);
CREATE INDEX IF NOT EXISTS idx_esdeveniments_data ON public.esdeveniments_club(data_inici);
CREATE INDEX IF NOT EXISTS idx_esdeveniments_tipus ON public.esdeveniments_club(tipus);

-- RLS
ALTER TABLE public.esdeveniments_club ENABLE ROW LEVEL SECURITY;

CREATE POLICY "esdeveniments_select_all" ON public.esdeveniments_club
  FOR SELECT USING (true);

CREATE POLICY "esdeveniments_insert_auth" ON public.esdeveniments_club
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "esdeveniments_update_auth" ON public.esdeveniments_club
  FOR UPDATE USING (auth.uid() IS NOT NULL);


-- ============================================
-- TAULA: page_content
-- ============================================


CREATE TABLE IF NOT EXISTS public.page_content (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  page_key VARCHAR(100) UNIQUE NOT NULL,
  title TEXT,
  content TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  updated_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índexs
CREATE UNIQUE INDEX IF NOT EXISTS idx_page_content_key ON public.page_content(page_key);

-- RLS
ALTER TABLE public.page_content ENABLE ROW LEVEL SECURITY;

CREATE POLICY "page_content_select_all" ON public.page_content
  FOR SELECT USING (true);

CREATE POLICY "page_content_update_auth" ON public.page_content
  FOR UPDATE USING (auth.uid() IS NOT NULL);

CREATE POLICY "page_content_insert_auth" ON public.page_content
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Trigger per actualitzar updated_at
CREATE OR REPLACE FUNCTION update_page_content_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_page_content_updated_at
  BEFORE UPDATE ON public.page_content
  FOR EACH ROW
  EXECUTE FUNCTION update_page_content_updated_at();


-- ============================================
-- VISTES
-- ============================================


-- Vista: v_player_badges
-- Calcula els badges/estadístiques dels jugadors
CREATE OR REPLACE VIEW public.v_player_badges AS
SELECT 
  s.numero_soci,
  s.cognoms,
  s.nom,
  s.de_baixa,
  COUNT(DISTINCT cp.id) as total_partides,
  SUM(CASE WHEN cp.estat = 'validada' THEN 1 ELSE 0 END) as partides_jugades,
  AVG(CASE 
    WHEN cp.jugador1_id = s.numero_soci THEN cp.caramboles_jugador1
    WHEN cp.jugador2_id = s.numero_soci THEN cp.caramboles_jugador2
  END) as mitjana_caramboles
FROM public.socis s
LEFT JOIN public.calendari_partides cp ON (
  s.numero_soci = cp.jugador1_id OR s.numero_soci = cp.jugador2_id
)
GROUP BY s.numero_soci, s.cognoms, s.nom, s.de_baixa;


-- ============================================
-- FUNCIONS
-- ============================================


-- Funció: get_real_classifications
-- Retorna les classificacions del campionat continu
CREATE OR REPLACE FUNCTION public.get_real_classifications(league_id_param TEXT DEFAULT NULL)
RETURNS TABLE (
  rank INTEGER,
  soci_id INTEGER,
  nom_complet TEXT,
  partides_jugades BIGINT,
  victories BIGINT,
  derrotes BIGINT,
  empats BIGINT,
  caramboles_totals BIGINT,
  mitjana_caramboles NUMERIC,
  total_entrades BIGINT,
  mitjana_general NUMERIC,
  punts INTEGER,
  retirat BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  WITH player_stats AS (
    SELECT 
      s.numero_soci as soci_id,
      CONCAT(UPPER(LEFT(s.nom, 1)), '. ', s.cognoms) as nom_complet,
      COUNT(cp.id) as partides_jugades,
      SUM(CASE 
        WHEN (cp.jugador1_id = s.numero_soci AND cp.caramboles_jugador1 > cp.caramboles_jugador2)
          OR (cp.jugador2_id = s.numero_soci AND cp.caramboles_jugador2 > cp.caramboles_jugador1)
        THEN 1 ELSE 0 
      END) as victories,
      SUM(CASE 
        WHEN (cp.jugador1_id = s.numero_soci AND cp.caramboles_jugador1 < cp.caramboles_jugador2)
          OR (cp.jugador2_id = s.numero_soci AND cp.caramboles_jugador2 < cp.caramboles_jugador1)
        THEN 1 ELSE 0 
      END) as derrotes,
      SUM(CASE 
        WHEN cp.caramboles_jugador1 = cp.caramboles_jugador2
        THEN 1 ELSE 0 
      END) as empats,
      SUM(CASE 
        WHEN cp.jugador1_id = s.numero_soci THEN cp.caramboles_jugador1
        WHEN cp.jugador2_id = s.numero_soci THEN cp.caramboles_jugador2
        ELSE 0
      END) as caramboles_totals,
      ROUND(AVG(CASE 
        WHEN cp.jugador1_id = s.numero_soci THEN cp.caramboles_jugador1
        WHEN cp.jugador2_id = s.numero_soci THEN cp.caramboles_jugador2
      END), 3) as mitjana_caramboles,
      SUM(cp.entrades) as total_entrades,
      COALESCE(mh.mitjana, 0) as mitjana_general,
      s.de_baixa as retirat
    FROM public.socis s
    LEFT JOIN public.calendari_partides cp ON (
      (s.numero_soci = cp.jugador1_id OR s.numero_soci = cp.jugador2_id)
      AND cp.estat = 'validada'
      AND (league_id_param IS NULL OR cp.event_id = league_id_param)
    )
    LEFT JOIN public.mitjanes_historiques mh ON (
      s.numero_soci = mh.soci_id 
      AND mh.year = EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER
      AND mh.modalitat = '3bandes'
    )
    GROUP BY s.numero_soci, s.nom, s.cognoms, s.de_baixa, mh.mitjana
    HAVING COUNT(cp.id) > 0
  )
  SELECT 
    ROW_NUMBER() OVER (
      ORDER BY 
        ps.retirat ASC,
        (ps.victories * 3 + ps.empats) DESC,
        ps.mitjana_caramboles DESC
    )::INTEGER as rank,
    ps.soci_id,
    ps.nom_complet,
    ps.partides_jugades,
    ps.victories,
    ps.derrotes,
    ps.empats,
    ps.caramboles_totals,
    ps.mitjana_caramboles,
    ps.total_entrades,
    ps.mitjana_general,
    (ps.victories * 3 + ps.empats)::INTEGER as punts,
    ps.retirat
  FROM player_stats ps;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Funció: get_social_league_classifications
-- Retorna les classificacions d'una lliga social específica
CREATE OR REPLACE FUNCTION public.get_social_league_classifications(league_id_param TEXT)
RETURNS TABLE (
  rank INTEGER,
  soci_id INTEGER,
  nom_complet TEXT,
  partides_jugades BIGINT,
  victories BIGINT,
  derrotes BIGINT,
  empats BIGINT,
  punts INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT * FROM public.get_real_classifications(league_id_param);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Funció: get_match_results
-- Retorna els resultats de les partides per un jugador
CREATE OR REPLACE FUNCTION public.get_match_results(player_id INTEGER)
RETURNS TABLE (
  match_id UUID,
  data_joc DATE,
  rival_id INTEGER,
  rival_nom TEXT,
  caramboles_propis INTEGER,
  caramboles_rival INTEGER,
  entrades INTEGER,
  resultat TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    cp.id as match_id,
    cp.data_joc,
    CASE 
      WHEN cp.jugador1_id = player_id THEN cp.jugador2_id
      ELSE cp.jugador1_id
    END as rival_id,
    CASE 
      WHEN cp.jugador1_id = player_id THEN CONCAT(s2.nom, ' ', s2.cognoms)
      ELSE CONCAT(s1.nom, ' ', s1.cognoms)
    END as rival_nom,
    CASE 
      WHEN cp.jugador1_id = player_id THEN cp.caramboles_jugador1
      ELSE cp.caramboles_jugador2
    END as caramboles_propis,
    CASE 
      WHEN cp.jugador1_id = player_id THEN cp.caramboles_jugador2
      ELSE cp.caramboles_jugador1
    END as caramboles_rival,
    cp.entrades,
    CASE 
      WHEN (cp.jugador1_id = player_id AND cp.caramboles_jugador1 > cp.caramboles_jugador2)
        OR (cp.jugador2_id = player_id AND cp.caramboles_jugador2 > cp.caramboles_jugador1)
      THEN 'victoria'
      WHEN cp.caramboles_jugador1 = cp.caramboles_jugador2
      THEN 'empat'
      ELSE 'derrota'
    END as resultat
  FROM public.calendari_partides cp
  LEFT JOIN public.socis s1 ON cp.jugador1_id = s1.numero_soci
  LEFT JOIN public.socis s2 ON cp.jugador2_id = s2.numero_soci
  WHERE (cp.jugador1_id = player_id OR cp.jugador2_id = player_id)
    AND cp.estat = 'validada'
  ORDER BY cp.data_joc DESC;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;


-- ============================================
-- COMENTARIS FINALS
-- ============================================


-- Aquest schema ha estat generat automàticament.
-- 
-- TAULES PRINCIPALS:
--   - socis: Jugadors del club
--   - calendari_partides: Partides programades i jugades
--   - mitjanes_historiques: Mitjanes històriques per any
--   - esdeveniments_club: Esdeveniments del calendari
--   - page_content: Contingut editable de les pàgines
--
-- FUNCIONS PRINCIPALS:
--   - get_real_classifications(): Classificació del campionat continu
--   - get_social_league_classifications(league_id): Classificació d'una lliga social
--   - get_match_results(player_id): Resultats d'un jugador
--
-- Per aplicar aquest schema a una base de dades nova:
--   psql -h HOST -U USER -d DATABASE -f schema-cloud.sql
--
-- Per actualitzar l'schema existent, revisa els canvis i aplica'ls manualment.
