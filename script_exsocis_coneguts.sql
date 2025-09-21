-- =================================================================
-- SCRIPT: INTEGRAR EXSOCIS CONEGUTS AMB DADES REALS
-- =================================================================
-- Data: 2025-09-21 12:47:58
-- Total exsocis coneguts: 48
-- Rang IDs: 263 - 8582
-- Aquests exsocis tenen noms i cognoms reals
-- =================================================================

BEGIN;

-- Eliminar exsocis coneguts si ja existeixen per evitar duplicats
DELETE FROM socis WHERE numero_soci IN (263,987,1381,1908,1988,2377,2548,3049,4073,4166,5261,5655,5935,6332,6550,6670,6685,6728,6844,6953,7009,7010,7026,7139,7148,7150,7184,7189,7190,7193,7279,7408,7417,7431,7543,7640,7642,7807,7937,7952,7954,8031,8093,8102,8185,8229,8310,8582);

-- Inserir exsocis coneguts amb dades reals
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (263, 'Ramon', 'Colom Codina', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (987, 'David', 'Nogues Blanco', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (1381, 'Salvador', 'Marin Bellido', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (1908, 'Francesc', 'Tares Millan', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (1988, 'Carles', 'Vidal Pons', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (2377, 'Joan', 'Sanz Mora', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (2548, 'Josep', 'Mir Bellmunt', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (3049, 'Jordi', 'Selgas Catala', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (4073, 'Jaume', 'Griñó Borbón', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (4166, 'Miquel', 'Gimeno Hernández', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (5261, 'Andreu', 'Del Rio Soler', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (5655, 'Josep', 'Gelabert Von-Weber', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (5935, 'Ricard', 'Grau Menal', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (6332, 'Josep', 'Fernández Biarnau', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (6550, 'Joan', 'Montero Perez', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (6670, 'Joan', 'Quevedo Roig', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (6685, 'Pau', 'Serra Balaguer', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (6728, 'Miquel', 'Farré Quintana', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (6844, 'Gabriel', 'Gimenez Garcia', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (6953, 'Juan', 'Hernandez Marquez', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7009, 'Andres', 'Martinez Garcia', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7010, 'Felipe', 'Gomez Gimenez', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7026, 'Lluis', 'Gonzalez Carvajal', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7139, 'Mario', 'Ebri Martinez', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7148, 'Isaac', 'Gomez Gimenez', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7150, 'Jesus', 'Perez Garcia', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7184, 'Alfonso', 'Garcia Garcia', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7189, 'Josep Ma', 'Soms Grau', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7190, 'Francisco', 'Barcia Lora', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7193, 'Manel', 'Pamplona Peralta', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7279, 'Pascual', 'Ballester Diaz', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7408, 'Albertyo', 'Porta Alesanco', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7417, 'Salvador', 'Barris Oms', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7431, 'Eduardo', 'Rodriguez Rios', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7543, 'Manel', 'Bruquetas Vall', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7640, 'Hammer', 'Kladivo Vladislav', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7642, 'Ramon', 'Bures Valls', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7807, 'Alfons', 'Campillo Gallego', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7937, 'Josep Ma', 'Val Aina', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7952, 'Sergi', 'Escoda Llort', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7954, 'Alberto-Oscar', 'Pometti Cos', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8031, 'Angel', 'Diez Diez', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8093, 'Ramon', 'Pallarès Casanovas', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8102, 'Pere', 'Solergibert Fauría', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8185, 'Oscar', 'Ramirez Torres', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8229, 'Francisco', 'Torrecillas Ramirez', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8310, 'Jose Miguel', 'Alvarez Martínez', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8582, 'Jose', 'Royes Lapeña', NULL, TRUE, '2024-12-31');

-- Verificacions
SELECT COUNT(*) as exsocis_coneguts_inserits FROM socis WHERE numero_soci IN (263,987,1381,1908,1988,2377,2548,3049,4073,4166,5261,5655,5935,6332,6550,6670,6685,6728,6844,6953,7009,7010,7026,7139,7148,7150,7184,7189,7190,7193,7279,7408,7417,7431,7543,7640,7642,7807,7937,7952,7954,8031,8093,8102,8185,8229,8310,8582);

-- Mostrar alguns exsocis inserits
SELECT numero_soci, nom, cognoms, de_baixa FROM socis WHERE numero_soci IN (263,987,1381,1908,1988,2377,2548,3049,4073,4166,5261,5655,5935,6332,6550,6670,6685,6728,6844,6953,7009,7010,7026,7139,7148,7150,7184,7189,7190,7193,7279,7408,7417,7431,7543,7640,7642,7807,7937,7952,7954,8031,8093,8102,8185,8229,8310,8582) ORDER BY numero_soci LIMIT 10;

COMMIT;
