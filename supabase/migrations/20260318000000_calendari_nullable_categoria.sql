-- Les partides del torneig hàndicap no pertanyen a cap categoria social.
-- Relaxem la restricció NOT NULL de categoria_id per permetre-ho.
ALTER TABLE calendari_partides ALTER COLUMN categoria_id DROP NOT NULL;
