-- Crear taula per esdeveniments del club
CREATE TABLE public.esdeveniments_club (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  titol text NOT NULL,
  descripcio text,
  data_inici timestamp with time zone NOT NULL,
  data_fi timestamp with time zone,
  tipus text NOT NULL DEFAULT 'general', -- 'general', 'torneig', 'social', 'manteniment'
  visible_per_tots boolean NOT NULL DEFAULT true,
  creat_per uuid,
  event_id uuid,
  creat_el timestamp with time zone NOT NULL DEFAULT now(),
  actualitzat_el timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT esdeveniments_club_pkey PRIMARY KEY (id),
  CONSTRAINT esdeveniments_club_creat_per_fkey FOREIGN KEY (creat_per) REFERENCES auth.users(id),
  CONSTRAINT esdeveniments_club_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id)
);

-- Crear índexs per optimitzar consultes
CREATE INDEX idx_esdeveniments_club_data_inici ON public.esdeveniments_club(data_inici);
CREATE INDEX idx_esdeveniments_club_tipus ON public.esdeveniments_club(tipus);
CREATE INDEX idx_esdeveniments_club_event_id ON public.esdeveniments_club(event_id);

-- Configurar RLS (Row Level Security)
ALTER TABLE public.esdeveniments_club ENABLE ROW LEVEL SECURITY;

-- Política per llegir: tots els usuaris autenticats poden veure esdeveniments visibles
CREATE POLICY "Esdeveniments visibles per usuaris autenticats" 
ON public.esdeveniments_club 
FOR SELECT 
TO authenticated 
USING (visible_per_tots = true);

-- Política per llegir: creadors poden veure els seus esdeveniments
CREATE POLICY "Creadors poden veure els seus esdeveniments" 
ON public.esdeveniments_club 
FOR SELECT 
TO authenticated 
USING (creat_per = auth.uid());

-- Política per crear: usuaris autenticats poden crear esdeveniments
CREATE POLICY "Usuaris autenticats poden crear esdeveniments" 
ON public.esdeveniments_club 
FOR INSERT 
TO authenticated 
WITH CHECK (creat_per = auth.uid());

-- Política per actualitzar: només creadors i admins
CREATE POLICY "Creadors poden actualitzar els seus esdeveniments" 
ON public.esdeveniments_club 
FOR UPDATE 
TO authenticated 
USING (creat_per = auth.uid());

-- Política per eliminar: només creadors i admins
CREATE POLICY "Creadors poden eliminar els seus esdeveniments" 
ON public.esdeveniments_club 
FOR DELETE 
TO authenticated 
USING (creat_per = auth.uid());

-- Trigger per actualitzar el camp actualitzat_el
CREATE OR REPLACE FUNCTION update_actualitzat_el_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.actualitzat_el = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER trigger_esdeveniments_club_actualitzat_el
BEFORE UPDATE ON public.esdeveniments_club
FOR EACH ROW EXECUTE PROCEDURE update_actualitzat_el_column();

-- Inserir alguns esdeveniments d'exemple
INSERT INTO public.esdeveniments_club (titol, descripcio, data_inici, data_fi, tipus, visible_per_tots) VALUES
('Torneig de Nadal 2025', 'Torneig especial de final d''any', '2025-12-20 10:00:00+01', '2025-12-20 18:00:00+01', 'torneig', true),
('Manteniment sala', 'Tancament per manteniment de les taules', '2025-10-15 08:00:00+02', '2025-10-15 12:00:00+02', 'manteniment', true),
('Festa de la Primavera', 'Esdeveniment social del club', '2025-04-15 19:00:00+02', '2025-04-15 23:00:00+02', 'social', true);