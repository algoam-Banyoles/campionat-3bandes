CREATE TABLE public.socis (
  numero_soci integer PRIMARY KEY,
  cognoms text NOT NULL,
  nom text NOT NULL,
  email text UNIQUE NOT NULL
);

ALTER TABLE public.players ADD COLUMN numero_soci integer REFERENCES public.socis(numero_soci);