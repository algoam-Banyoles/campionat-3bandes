-- Classificacions completes 2013-2014 (3 BANDES) i 2014-2015 (BANDA, LLIURE)
-- Font: Foment Barris/Foment 201X/*.xlsm (Lluís González)

-- 1) Afegir columnes entrades i serie_major a classificacions (preserva dades originals)
ALTER TABLE classificacions ADD COLUMN IF NOT EXISTS entrades integer;
ALTER TABLE classificacions ADD COLUMN IF NOT EXISTS serie_major integer;
ALTER TABLE classificacions ADD COLUMN IF NOT EXISTS millor_mitjana numeric;

-- 2) Crear events i categories i classificacions en una transacció
DO $$
DECLARE
  v_event_id uuid;
  v_cat_id uuid;
BEGIN
  -- Event: Campionat Social 3 Bandes 2013-2014
  INSERT INTO events (nom, tipus_competicio, temporada, estat_competicio, actiu, data_inici, data_fi)
  VALUES ('Campionat Social 3 Bandes', 'lliga_social', '2013-2014', 'finalitzat', false, DATE '2013-09-01', DATE '2014-07-31')
  RETURNING id INTO v_event_id;

  -- Categoria 1a 3 BANDES 2013-2014
  INSERT INTO categories (event_id, nom, ordre_categoria, distancia_caramboles)
  VALUES (v_event_id, '1a Categoria', 1, 20)
  RETURNING id INTO v_cat_id;
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 5655, 1, 18, 201, 481, 0.417, 1.25, 7);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7026, 2, 16, 188, 494, 0.38, 0.606, 4);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 3019, 3, 14, 192, 446, 0.43, 0.689, 5);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 407, 4, 14, 163, 549, 0.296, 0.408, 3);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7602, 5, 12, 183, 504, 0.363, 0.5, 4);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 6897, 6, 10, 161, 485, 0.331, 0.74, 5);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 6953, 7, 10, 156, 498, 0.313, 0.487, 4);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 6203, 8, 9, 158, 490, 0.322, 0.689, 5);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7193, 9, 9, 158, 510, 0.309, 0.714, 4);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 5935, 10, 9, 135, 519, 0.26, 0.476, 4);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7640, 11, 6, 160, 509, 0.314, 0.444, 3);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 6844, 12, 5, 134, 495, 0.27, 0.476, 6);

  -- Categoria 2a 3 BANDES 2013-2014
  INSERT INTO categories (event_id, nom, ordre_categoria, distancia_caramboles)
  VALUES (v_event_id, '2a Categoria', 2, 15)
  RETURNING id INTO v_cat_id;
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7431, 1, 26, 208, 596, 0.348, 0.576, 4);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7439, 2, 22, 189, 644, 0.293, 0.468, 5);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 6110, 3, 21, 191, 675, 0.282, 0.483, 5);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7408, 4, 21, 189, 676, 0.279, 0.483, 4);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7618, 5, 18, 175, 672, 0.26, 0.483, 5);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 3049, 6, 17, 168, 688, 0.244, 0.365, 3);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7807, 7, 17, 162, 682, 0.237, 0.535, 6);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 4995, 8, 16, 168, 687, 0.244, 0.357, 4);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7189, 9, 12, 161, 713, 0.225, 0.348, 4);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, NULL, 10, 12, 153, 686, 0.223, 0.333, 4);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7190, 11, 12, 155, 721, 0.214, 0.34, 4);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7308, 12, 11, 141, 703, 0.20056899004267426, 0.365, 3);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 5818, 13, 10, 146, 700, 0.208, 0.333, 3);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 6811, 14, 9, 147, 727, 0.202, 0.416, 3);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 1908, 15, 9, 143, 707, 0.202, 0.34, 5);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7543, 16, 7, 111, 695, 0.159, 0.28, 3);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 8732, 17, 0, 0, 0, NULL, NULL, NULL);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 6685, 18, 0, 0, 0, NULL, NULL, NULL);

  -- Categoria 3a 3 BANDES 2013-2014
  INSERT INTO categories (event_id, nom, ordre_categoria, distancia_caramboles)
  VALUES (v_event_id, '3a Categoria', 3, 10)
  RETURNING id INTO v_cat_id;
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7139, 1, 18, 85, 392, 0.216, 0.625, 3);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 1381, 2, 16, 74, 444, 0.166, 0.4, 3);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7909, 3, 13, 76, 487, 0.156, 0.232, 3);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7009, 4, 12, 78, 380, 0.205, 0.461, 2);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7417, 5, 12, 65, 437, 0.148, 0.769, 3);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7586, 6, 10, 72, 449, 0.16, 0.263, 4);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7196, 7, 10, 66, 449, 0.146, 0.227, 3);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 2749, 8, 7, 48, 443, 0.108, 0.18, 2);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7279, 9, 6, 52, 488, 0.106, 0.18, 2);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 3463, 10, 5, 41, 485, 0.084, 0.14, 2);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 6855, 11, 1, 22, 466, 0.047, 0.1, 1);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7044, 12, 0, 0, 0, NULL, NULL, NULL);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, NULL, 13, 0, 0, 0, NULL, NULL, NULL);

  -- Event: Campionat Social Banda 2014-2015
  INSERT INTO events (nom, tipus_competicio, temporada, estat_competicio, actiu, data_inici, data_fi)
  VALUES ('Campionat Social Banda', 'lliga_social', '2014-2015', 'finalitzat', false, DATE '2014-09-01', DATE '2015-07-31')
  RETURNING id INTO v_event_id;

  -- Categoria 1a BANDA 2014-2015
  INSERT INTO categories (event_id, nom, ordre_categoria, distancia_caramboles)
  VALUES (v_event_id, '1a Categoria', 1, 50)
  RETURNING id INTO v_cat_id;
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7602, 1, 12, 240, 174, 1.379, 2.105, 10);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7408, 2, 8, 204, 246, 0.829, 1.052, 6);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7640, 3, 6, 208, 174, 1.195, 1.379, 9);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 5655, 4, 6, 211, 218, 0.967, 1.6, 7);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 3019, 5, 6, 217, 228, 0.951, 1.176, 6);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7937, 6, 2, 146, 256, 0.57, 0.718, 6);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7954, 7, 2, 98, 222, 0.441, 0.538, 5);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7927, 8, 0, 0, 0, NULL, NULL, NULL);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 6203, 9, 0, 0, 0, NULL, NULL, NULL);

  -- Categoria 2a BANDA 2014-2015
  INSERT INTO categories (event_id, nom, ordre_categoria, distancia_caramboles)
  VALUES (v_event_id, '2a Categoria', 2, 40)
  RETURNING id INTO v_cat_id;
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 407, 1, 14, 232, 290, 0.8, 1.0, 7);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 6953, 2, 11, 217, 269, 0.806, 1.071, 7);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 6110, 3, 9, 223, 279, 0.799, 0.937, 5);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 6811, 4, 8, 214, 281, 0.761, 1.0, 13);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7193, 5, 8, 207, 273, 0.758, 1.111, 7);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7439, 6, 8, 212, 286, 0.741, 0.967, 6);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 6685, 7, 8, 183, 300, 0.61, 1.071, 6);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7618, 8, 6, 205, 309, 0.663, 1.304, 8);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 6897, 9, 0, 191, 289, 0.66, 0.777, 6);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 3049, 10, 0, 0, 0, NULL, NULL, NULL);

  -- Categoria 3a BANDA 2014-2015
  INSERT INTO categories (event_id, nom, ordre_categoria, distancia_caramboles)
  VALUES (v_event_id, '3a Categoria', 3, 30)
  RETURNING id INTO v_cat_id;

  -- Event: Campionat Social Lliure 2014-2015
  INSERT INTO events (nom, tipus_competicio, temporada, estat_competicio, actiu, data_inici, data_fi)
  VALUES ('Campionat Social Lliure', 'lliga_social', '2014-2015', 'finalitzat', false, DATE '2014-09-01', DATE '2015-07-31')
  RETURNING id INTO v_event_id;

  -- Categoria 1a LLIURE 2014-2015
  INSERT INTO categories (event_id, nom, ordre_categoria, distancia_caramboles)
  VALUES (v_event_id, '1a Categoria', 1, 60)
  RETURNING id INTO v_cat_id;
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7602, 1, 14, 692, 354, 1.9548022598870056, 3.26, 19);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 3019, 2, 14, 629, 407, 1.5454545454545454, 2.419, 14);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7640, 3, 12, 649, 362, 1.792817679558011, 3.409, 21);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 5655, 4, 10, 619, 373, 1.6595174262734584, 2.343, 14);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 6110, 5, 10, 639, 424, 1.5070754716981132, 2.586, 14);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7937, 6, 0, 380, 442, 0.8597285067873304, 1.06, 7);

  -- Categoria 2a LLIURE 2014-2015
  INSERT INTO categories (event_id, nom, ordre_categoria, distancia_caramboles)
  VALUES (v_event_id, '2a Categoria', 2, 50)
  RETURNING id INTO v_cat_id;
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7967, 1, 16, 525, 455, 1.153, 1.612, 13);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7439, 2, 16, 508, 443, 1.146, 1.515, 9);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 6844, 3, 16, 508, 476, 1.067, 1.393, 8);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 6811, 4, 13, 490, 450, 1.088, 1.515, 9);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 6953, 5, 12, 511, 472, 1.082, 1.47, 8);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 4995, 6, 11, 491, 480, 1.022, 1.47, 11);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 6897, 7, 10, 472, 487, 0.969, 1.47, 9);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7193, 8, 10, 424, 464, 0.913, 1.351, 6);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7807, 9, 8, 457, 496, 0.921, 1.19, 8);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 407, 10, 8, 455, 512, 0.888, 1.162, 7);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7618, 11, 6, 461, 443, 1.04, 1.219, 10);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 6685, 12, 6, 385, 480, 0.802, 1.282, 11);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7408, 13, 0, 0, 0, NULL, NULL, NULL);

  -- Categoria 3a LLIURE 2014-2015
  INSERT INTO categories (event_id, nom, ordre_categoria, distancia_caramboles)
  VALUES (v_event_id, '3a Categoria', 3, 40)
  RETURNING id INTO v_cat_id;
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7938, 1, 24, 518, 499, 1.038, 1.481, 11);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7009, 2, 22, 464, 588, 0.789, 1.111, 8);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7308, 3, 18, 470, 558, 0.842, 1.29, 8);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7139, 4, 18, 451, 600, 0.751, 1.176, 7);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7909, 5, 18, 448, 612, 0.732, 1.161, 8);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 1908, 6, 17, 418, 584, 0.715, 1.081, 7);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7196, 7, 14, 398, 551, 0.722, 1.176, 8);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 2749, 8, 11, 419, 623, 0.672, 0.923, 8);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 5261, 9, 10, 346, 639, 0.541, 0.66, 7);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7543, 10, 9, 347, 576, 0.602, 0.888, 7);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 1381, 11, 8, 374, 593, 0.63, 1.0, 7);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 3463, 12, 8, 286, 615, 0.465, 0.666, 4);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 7952, 13, 2, 231, 571, 0.404, 0.7, 6);
  INSERT INTO classificacions (event_id, categoria_id, soci_numero, posicio, punts, caramboles_favor, entrades, mitjana_particular, millor_mitjana, serie_major) VALUES (v_event_id, v_cat_id, 6855, 14, 1, 185, 583, 0.317, 0.5, 5);

END $$;