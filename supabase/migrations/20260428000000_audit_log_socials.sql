-- =====================================================
-- AUDIT LOG per a accions admin sobre campionats socials
-- =====================================================
--
-- Crea una taula `audit_log_socials` que captura canvis significatius
-- a `inscripcions` (categoria, estat) i a `events` (estat_competicio,
-- calendari publicat, actiu) per facilitar auditoria.
--
-- ⚠️ REVISAR ABANS D'APLICAR:
--  - Els triggers escriuen amb `auth.uid()` per registrar l'autor.
--  - Si la BD no té una columna `email` als usuaris d'auth, fes el
--    join a `socis` per email per resoldre la identitat (ja contemplat).
--  - El RLS només permet SELECT als admins.
--

-- 1. Taula
CREATE TABLE IF NOT EXISTS public.audit_log_socials (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- Qui ha fet l'acció (uid d'auth + email resolt si és possible)
  actor_user_id UUID,
  actor_email TEXT,
  -- Què ha passat (categoria oberta per facilitar consultes)
  action TEXT NOT NULL,
  -- Sobre quina entitat
  entity_type TEXT NOT NULL CHECK (entity_type IN ('inscripcio', 'event')),
  entity_id TEXT NOT NULL,
  -- Context addicional (event_id si l'entitat és diferent d'event)
  event_id UUID,
  -- Snapshots per a debugging / desfés
  before_data JSONB,
  after_data JSONB,
  -- Notes opcionals (qui, què, etc.)
  notes TEXT
);

CREATE INDEX IF NOT EXISTS audit_log_socials_event_idx
  ON public.audit_log_socials (event_id, created_at DESC);
CREATE INDEX IF NOT EXISTS audit_log_socials_actor_idx
  ON public.audit_log_socials (actor_email, created_at DESC);
CREATE INDEX IF NOT EXISTS audit_log_socials_entity_idx
  ON public.audit_log_socials (entity_type, entity_id, created_at DESC);

COMMENT ON TABLE public.audit_log_socials IS
  'Registre d''accions admin sobre campionats socials (inscripcions i events).';

-- 2. RLS
ALTER TABLE public.audit_log_socials ENABLE ROW LEVEL SECURITY;

-- Només admins poden llegir el registre
CREATE POLICY "audit_log_socials_admin_select"
  ON public.audit_log_socials
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.admins a
      WHERE a.email = (SELECT email FROM auth.users WHERE id = auth.uid())
    )
  );

-- INSERT només via triggers (revoke per a clients normals)
REVOKE INSERT, UPDATE, DELETE ON public.audit_log_socials FROM authenticated, anon;

-- 3. Helper per resoldre email a partir de l'usuari actiu
CREATE OR REPLACE FUNCTION public._audit_actor_email()
  RETURNS TEXT
  LANGUAGE sql
  SECURITY DEFINER
  SET search_path = public, auth
AS $$
  SELECT email FROM auth.users WHERE id = auth.uid();
$$;

-- 4. Trigger per inscripcions
CREATE OR REPLACE FUNCTION public._audit_inscripcions_trigger()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public
AS $$
DECLARE
  v_action TEXT;
  v_actor_email TEXT;
BEGIN
  v_actor_email := public._audit_actor_email();

  IF TG_OP = 'INSERT' THEN
    v_action := 'inscripcio.created';
    INSERT INTO public.audit_log_socials
      (actor_user_id, actor_email, action, entity_type, entity_id, event_id, after_data)
    VALUES
      (auth.uid(), v_actor_email, v_action, 'inscripcio', NEW.id::text, NEW.event_id, to_jsonb(NEW));
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    v_action := 'inscripcio.deleted';
    INSERT INTO public.audit_log_socials
      (actor_user_id, actor_email, action, entity_type, entity_id, event_id, before_data)
    VALUES
      (auth.uid(), v_actor_email, v_action, 'inscripcio', OLD.id::text, OLD.event_id, to_jsonb(OLD));
    RETURN OLD;
  ELSIF TG_OP = 'UPDATE' THEN
    -- Detectar el tipus de canvi més específic
    IF NEW.categoria_assignada_id IS DISTINCT FROM OLD.categoria_assignada_id THEN
      v_action := 'inscripcio.category_changed';
    ELSIF NEW.estat_jugador IS DISTINCT FROM OLD.estat_jugador THEN
      v_action := CASE WHEN NEW.estat_jugador = 'retirat' THEN 'inscripcio.withdrawn' ELSE 'inscripcio.reinstated' END;
    ELSIF NEW.eliminat_per_incompareixences IS DISTINCT FROM OLD.eliminat_per_incompareixences AND NEW.eliminat_per_incompareixences THEN
      v_action := 'inscripcio.disqualified';
    ELSIF NEW.confirmat IS DISTINCT FROM OLD.confirmat OR NEW.pagat IS DISTINCT FROM OLD.pagat THEN
      v_action := 'inscripcio.status_changed';
    ELSE
      v_action := 'inscripcio.updated';
    END IF;

    INSERT INTO public.audit_log_socials
      (actor_user_id, actor_email, action, entity_type, entity_id, event_id, before_data, after_data)
    VALUES
      (auth.uid(), v_actor_email, v_action, 'inscripcio', NEW.id::text, NEW.event_id, to_jsonb(OLD), to_jsonb(NEW));
    RETURN NEW;
  END IF;

  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS audit_inscripcions ON public.inscripcions;
CREATE TRIGGER audit_inscripcions
  AFTER INSERT OR UPDATE OR DELETE ON public.inscripcions
  FOR EACH ROW EXECUTE FUNCTION public._audit_inscripcions_trigger();

-- 5. Trigger per events (només UPDATE — els INSERT són rars i no
--    crítics; els DELETE típicament no es fan)
CREATE OR REPLACE FUNCTION public._audit_events_trigger()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public
AS $$
DECLARE
  v_action TEXT;
  v_actor_email TEXT;
BEGIN
  v_actor_email := public._audit_actor_email();

  IF NEW.estat_competicio IS DISTINCT FROM OLD.estat_competicio THEN
    v_action := 'event.estat_changed';
  ELSIF NEW.calendari_publicat IS DISTINCT FROM OLD.calendari_publicat AND NEW.calendari_publicat THEN
    v_action := 'event.calendari_published';
  ELSIF NEW.actiu IS DISTINCT FROM OLD.actiu THEN
    v_action := CASE WHEN NEW.actiu THEN 'event.activated' ELSE 'event.deactivated' END;
  ELSE
    -- Canvis menors no s'auditen per evitar soroll
    RETURN NEW;
  END IF;

  INSERT INTO public.audit_log_socials
    (actor_user_id, actor_email, action, entity_type, entity_id, event_id, before_data, after_data)
  VALUES
    (auth.uid(), v_actor_email, v_action, 'event', NEW.id::text, NEW.id, to_jsonb(OLD), to_jsonb(NEW));

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS audit_events ON public.events;
CREATE TRIGGER audit_events
  AFTER UPDATE ON public.events
  FOR EACH ROW EXECUTE FUNCTION public._audit_events_trigger();

-- 6. Permisos d'execució del helper
GRANT EXECUTE ON FUNCTION public._audit_actor_email() TO authenticated;
