-- Fase 5b — Refactor `players` → `socis` (pas 2/3)
--
-- Context: a Fase 5a vam refactoritzar tot el codi perquè el nom i email d'un
-- jugador es llegissin SEMPRE des de `socis` via JOIN niat
-- (`players(socis(nom, cognoms, email))`). Les columnes `players.nom` i
-- `players.email` ja no són la font de veritat: hi ha 100% de noms divergents
-- entre `players.nom` i `socis.nom` per pure formatat.
--
-- Aquesta migració:
--   1. Fa NULLABLE les columnes `players.nom` i `players.email` perquè el codi
--      pugui crear nous players sense duplicar dades.
--   2. NO esborra les columnes encara — això es farà a una migració posterior
--      després d'un període de monitoring sense errors a producció.
--   3. NO toca cap dada existent — els valors actuals queden tal com estan.

ALTER TABLE players
  ALTER COLUMN nom DROP NOT NULL;

ALTER TABLE players
  ALTER COLUMN email DROP NOT NULL;
