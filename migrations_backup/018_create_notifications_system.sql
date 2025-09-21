-- Crear sistema de notificacions push
-- Migració 018: Sistema complet de notificacions

-- Taula per subscripcions push dels usuaris
CREATE TABLE public.push_subscriptions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  endpoint text NOT NULL,
  p256dh_key text NOT NULL,
  auth_key text NOT NULL,
  user_agent text,
  activa boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT push_subscriptions_pkey PRIMARY KEY (id),
  CONSTRAINT push_subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT push_subscriptions_endpoint_unique UNIQUE (endpoint)
);

-- Taula per preferències de notificacions per usuari
CREATE TABLE public.notification_preferences (
  user_id uuid NOT NULL,
  reptes_nous boolean NOT NULL DEFAULT true,
  caducitat_terminis boolean NOT NULL DEFAULT true,
  recordatoris_partides boolean NOT NULL DEFAULT true,
  hores_abans_recordatori integer NOT NULL DEFAULT 24, -- hores abans de la partida
  minuts_abans_caducitat integer NOT NULL DEFAULT 1440, -- minuts abans que caduqui (24h)
  silenci_nocturn boolean NOT NULL DEFAULT true,
  hora_inici_silenci time NOT NULL DEFAULT '22:00:00',
  hora_fi_silenci time NOT NULL DEFAULT '08:00:00',
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT notification_preferences_pkey PRIMARY KEY (user_id),
  CONSTRAINT notification_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

-- Taula per historial de notificacions enviades
CREATE TABLE public.notification_history (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  tipus text NOT NULL, -- 'repte_nou', 'caducitat_proxima', 'repte_caducat', 'partida_recordatori', 'confirmacio_requerida'
  titol text NOT NULL,
  missatge text NOT NULL,
  enviada_el timestamp with time zone NOT NULL DEFAULT now(),
  llegida_el timestamp with time zone,
  challenge_id uuid,
  event_id uuid,
  payload jsonb,
  success boolean NOT NULL DEFAULT true,
  error_message text,
  CONSTRAINT notification_history_pkey PRIMARY KEY (id),
  CONSTRAINT notification_history_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT notification_history_challenge_id_fkey FOREIGN KEY (challenge_id) REFERENCES public.challenges(id) ON DELETE SET NULL
);

-- Taula per cua de notificacions programades
CREATE TABLE public.scheduled_notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  tipus text NOT NULL,
  scheduled_for timestamp with time zone NOT NULL,
  payload jsonb NOT NULL,
  processed boolean NOT NULL DEFAULT false,
  processed_at timestamp with time zone,
  challenge_id uuid,
  event_id uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT scheduled_notifications_pkey PRIMARY KEY (id),
  CONSTRAINT scheduled_notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT scheduled_notifications_challenge_id_fkey FOREIGN KEY (challenge_id) REFERENCES public.challenges(id) ON DELETE CASCADE
);

-- Crear índexs per optimitzar consultes
CREATE INDEX idx_push_subscriptions_user_id ON public.push_subscriptions(user_id);
CREATE INDEX idx_push_subscriptions_activa ON public.push_subscriptions(activa) WHERE activa = true;
CREATE INDEX idx_notification_history_user_id ON public.notification_history(user_id);
CREATE INDEX idx_notification_history_tipus ON public.notification_history(tipus);
CREATE INDEX idx_notification_history_challenge_id ON public.notification_history(challenge_id);
CREATE INDEX idx_scheduled_notifications_user_id ON public.scheduled_notifications(user_id);
CREATE INDEX idx_scheduled_notifications_scheduled_for ON public.scheduled_notifications(scheduled_for) WHERE processed = false;
CREATE INDEX idx_scheduled_notifications_processed ON public.scheduled_notifications(processed) WHERE processed = false;

-- Configurar RLS (Row Level Security)
ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scheduled_notifications ENABLE ROW LEVEL SECURITY;

-- Polítiques per push_subscriptions
CREATE POLICY "Usuaris poden veure les seves subscripcions" 
ON public.push_subscriptions 
FOR SELECT 
TO authenticated 
USING (user_id = auth.uid());

CREATE POLICY "Usuaris poden crear les seves subscripcions" 
ON public.push_subscriptions 
FOR INSERT 
TO authenticated 
WITH CHECK (user_id = auth.uid());

CREATE POLICY "Usuaris poden actualitzar les seves subscripcions" 
ON public.push_subscriptions 
FOR UPDATE 
TO authenticated 
USING (user_id = auth.uid());

CREATE POLICY "Usuaris poden eliminar les seves subscripcions" 
ON public.push_subscriptions 
FOR DELETE 
TO authenticated 
USING (user_id = auth.uid());

-- Polítiques per notification_preferences
CREATE POLICY "Usuaris poden veure les seves preferències" 
ON public.notification_preferences 
FOR SELECT 
TO authenticated 
USING (user_id = auth.uid());

CREATE POLICY "Usuaris poden crear les seves preferències" 
ON public.notification_preferences 
FOR INSERT 
TO authenticated 
WITH CHECK (user_id = auth.uid());

CREATE POLICY "Usuaris poden actualitzar les seves preferències" 
ON public.notification_preferences 
FOR UPDATE 
TO authenticated 
USING (user_id = auth.uid());

-- Polítiques per notification_history
CREATE POLICY "Usuaris poden veure el seu historial" 
ON public.notification_history 
FOR SELECT 
TO authenticated 
USING (user_id = auth.uid());

-- Polítiques per scheduled_notifications (només per al sistema)
CREATE POLICY "Sistema pot gestionar notificacions programades" 
ON public.scheduled_notifications 
FOR ALL 
TO service_role 
USING (true);

-- Triggers per actualitzar updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER trigger_push_subscriptions_updated_at
BEFORE UPDATE ON public.push_subscriptions
FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

CREATE TRIGGER trigger_notification_preferences_updated_at
BEFORE UPDATE ON public.notification_preferences
FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

-- Funció per crear preferències per defecte quan es crea un usuari
CREATE OR REPLACE FUNCTION create_default_notification_preferences()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.notification_preferences (user_id)
    VALUES (NEW.id);
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger per crear preferències automàticament
CREATE TRIGGER trigger_create_default_notification_preferences
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE PROCEDURE create_default_notification_preferences();

-- Funció per programar notificacions de caducitat de reptes
CREATE OR REPLACE FUNCTION schedule_challenge_expiry_notifications()
RETURNS TRIGGER AS $$
DECLARE
    notification_time timestamp with time zone;
    user_prefs record;
BEGIN
    -- Només per reptes nous (status = 'proposed')
    IF NEW.status = 'proposed' THEN
        -- Obtenir preferències del usuari desafiat
        SELECT * INTO user_prefs 
        FROM public.notification_preferences 
        WHERE user_id = NEW.challenged_id;
        
        IF user_prefs.caducitat_terminis THEN
            -- Calcular quan enviar la notificació (per defecte 24h abans)
            notification_time := NEW.deadline - (user_prefs.minuts_abans_caducitat || ' minutes')::interval;
            
            -- Programar notificació si és en el futur
            IF notification_time > now() THEN
                INSERT INTO public.scheduled_notifications (
                    user_id, 
                    tipus, 
                    scheduled_for, 
                    challenge_id,
                    payload
                ) VALUES (
                    NEW.challenged_id,
                    'caducitat_proxima',
                    notification_time,
                    NEW.id,
                    json_build_object(
                        'challenger_name', (SELECT name FROM profiles WHERE user_id = NEW.challenger_id),
                        'deadline', NEW.deadline,
                        'challenge_id', NEW.id
                    )::jsonb
                );
            END IF;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger per programar notificacions automàticament
CREATE TRIGGER trigger_schedule_challenge_notifications
AFTER INSERT ON public.challenges
FOR EACH ROW EXECUTE PROCEDURE schedule_challenge_expiry_notifications();

-- Inserir dades d'exemple per desenvolupament
DO $$
DECLARE
    user_id_1 uuid;
    user_id_2 uuid;
BEGIN
    -- Obtenir alguns usuaris existents (si n'hi ha)
    SELECT id INTO user_id_1 FROM auth.users LIMIT 1;
    SELECT id INTO user_id_2 FROM auth.users OFFSET 1 LIMIT 1;
    
    -- Només inserir si hi ha usuaris
    IF user_id_1 IS NOT NULL THEN
        INSERT INTO public.notification_preferences (user_id, reptes_nous, caducitat_terminis, recordatoris_partides)
        VALUES (user_id_1, true, true, true)
        ON CONFLICT (user_id) DO NOTHING;
    END IF;
    
    IF user_id_2 IS NOT NULL THEN
        INSERT INTO public.notification_preferences (user_id, reptes_nous, caducitat_terminis, recordatoris_partides)
        VALUES (user_id_2, true, false, true)
        ON CONFLICT (user_id) DO NOTHING;
    END IF;
END $$;