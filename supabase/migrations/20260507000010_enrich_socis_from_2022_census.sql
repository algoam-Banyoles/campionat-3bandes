-- Enriquiment de la taula socis a partir del cens 2022 de la secció billar
-- (TODOS LOS DATOS BILLAR.xlsx, juliol 2022)
-- NO sobreescriu valors existents — només omple camps NULL

BEGIN;

-- 1) Inserir soci absent: 8138 Cervantes Donenech, Roger
INSERT INTO socis (numero_soci, cognoms, nom, data_naixement, telefon, email, de_baixa)
VALUES (8138, 'Cervantes Donenech', 'Roger', DATE '1985-05-18', '645347167', 'cervi_4@hotmail.com', false)
ON CONFLICT (numero_soci) DO NOTHING;

-- 2) Enriquiment via UPDATE FROM VALUES
WITH cens(n, cogn, nom, naix, tel, email) AS (
  VALUES
    (261, 'Cabre Camps', 'Jordi', DATE '1945-12-20', '617542528', 'jordicabrecamps@gmail.com'),
    (407, 'Fina Pasanau', 'Xavier', DATE '1965-11-01', '934369884', NULL),
    (987, 'Nogues Blanco', 'David', DATE '1962-01-27', '645181048', NULL),
    (1123, 'Lopez Sanchez', 'Angel', DATE '1953-01-28', '934552168', NULL),
    (1381, 'Marin Bellido', 'Salvador', DATE '1963-08-20', '932196852', 'salvadormarin20@yahoo.es'),
    (2377, 'Sanz Mora', 'Joan', DATE '1928-02-28', '934555665', NULL),
    (2543, 'Llauet Amiell', 'Antoni', DATE '1945-05-23', '933478386', NULL),
    (2603, 'Garriga Rostey', 'Claudi', DATE '1937-01-26', '932317120', 'claudigarriga@gmail.com'),
    (2749, 'Carrasco Montes', 'Joan', DATE '1944-06-09', '934552703', 'joancarmon@hotmail.com'),
    (3019, 'Leon Puig', 'Esteve', DATE '1966-07-21', '607333728', 'eslepu@hotmail.com'),
    (3287, 'De La Riva Aguado', 'Jordi', DATE '1975-07-21', '619148046', 'jdelarivaaguado@hotmail.com'),
    (3463, 'Querol Viñals', 'Manuel', DATE '1949-03-28', '640198702', NULL),
    (3780, 'Yepes Martinez', 'Eduard', DATE '1974-02-23', '622353152', 'skakimat@hotmail.com'),
    (5261, 'Del Rio Soler', 'Andreu', DATE '1947-03-28', '648754316', 'andreudelrio@gmail.com'),
    (5818, 'Inocentes Sivilla', 'Vicens', DATE '1961-03-20', '690092694', 'vicenteinocentes@telefonica.net'),
    (6110, 'Comas Ferrer', 'Jaume', DATE '1937-01-24', '934205045', NULL),
    (6203, 'Selga  Sarro', 'Josep', DATE '1937-01-14', '934553979', NULL),
    (6470, 'Roy Sobrevilla', 'Leandro', DATE '1946-12-09', '666423720', NULL),
    (6512, 'Valles Ros', 'Josep', DATE '1951-12-07', '628872653', 'pitujv@gmail.com'),
    (6723, 'Ortiz Martinez', 'Victor', DATE '1993-05-21', '626665582', 'olgamr@telefonica.net'),
    (6726, 'Baraut Baraut', 'Mariano', DATE '1947-09-29', '932323610', NULL),
    (6811, 'Rodriguez Airo', 'Juan Manuel', DATE '1942-06-04', '933094357', NULL),
    (6855, 'Ortiz Romero', 'Jesus', DATE '1955-08-24', '696057512', 'jesusortizromero@telefonica.net'),
    (6897, 'Castillo Juan', 'Arturo', DATE '1938-05-14', '932107948', NULL),
    (7009, 'Martínez García', 'Andrés', DATE '1937-11-21', '932450657', 'andres37mg@hotmail.com'),
    (7026, 'Gonzalez Carvajal', 'Lluis', DATE '1945-10-07', '610753859', 'lugaro@orange.es'),
    (7044, 'Armengol Creus', 'Jaume', DATE '1933-09-28', '658470094', 'jaumearmengol@telefonica.net'),
    (7046, 'Carreño Serra', 'Alfonso', DATE '1959-05-01', '660069608', 'alfonsocarrenyo@gmail.com'),
    (7184, 'Garcia Garcia', 'Alfonso', DATE '1931-01-23', '662046732', NULL),
    (7193, 'Pamplona Peralta', 'Manel', DATE '1944-02-15', '932319329', 'conxita_montoliu@hotmail.es'),
    (7196, 'Fito Ibañez', 'Joan', DATE '1951-07-04', '648806805', 'joanfito@gmail.com'),
    (7226, 'Benito Navarro', 'Jorge', DATE '1971-02-15', '637002154', NULL),
    (7297, 'Ruiz Martinez', 'Angel', DATE '1970-12-02', '659324016', NULL),
    (7308, 'Jarque Sanchez', 'Raül', DATE '1951-02-26', '618359052', 'rauljarque2@hotmail.com'),
    (7439, 'Lopez Zurdo', 'Isidoro', DATE '1953-01-02', '638379447', NULL),
    (7541, 'Ferras Omella', 'Pedro', DATE '1946-11-20', '649439572', NULL),
    (7586, 'Viaplana Lleonart', 'Josep Maria', DATE '1946-10-27', '669816126', 'josepmaria.viaplana@gmail.com'),
    (7602, 'Santos Gonzalez', 'Juan Felix', DATE '1946-05-28', '651061737', NULL),
    (7618, 'Casanova Fregine', 'Pere', DATE '1946-11-22', '610450334', 'p.casanova.f@gmail.com'),
    (7642, 'Bures Valls', 'Ramon', DATE '1940-12-13', '646597457', NULL),
    (7864, 'Ferrer Miquel', 'Josep Mª', DATE '1954-11-09', '606446566', 'jofermi10@yahoo.es'),
    (7909, 'Rodriguez Fernandez', 'Juan', DATE '1958-02-20', '671958410', NULL),
    (7938, 'Cervantes Solsona', 'Rafael', DATE '1962-08-31', '649436956', NULL),
    (7952, 'Escoda Llort', 'Sergi', DATE '1986-07-07', '686367835', 'sergi85kio@gmail.com'),
    (7954, 'Pometti Cos', 'Alberto-Oscar', DATE '1934-01-29', '672670516', 'albpoco@hotmail.com'),
    (7967, 'Sanchez Molera', 'Manuel', DATE '1944-06-10', '626460309', 'manelsan@hotmail.es'),
    (8014, 'Gonzalez Vericat', 'Buenaventura', DATE '1958-03-31', '616767476', NULL),
    (8031, 'Diez Diez', 'Angel', DATE '1943-06-01', '659662959', 'angeldiezdiez2@hotmail.com'),
    (8041, 'Corbalan Juan', 'Domingo', DATE '1941-09-28', '659652043', NULL),
    (8062, 'Grau Cadena', 'Joan', DATE '1954-03-22', '649831293', 'jgc1992c@gmail.com'),
    (8077, 'Boix Gonzalez', 'Agustí', DATE '1951-05-27', '690030267', 'agustiboixgonzalez@gmail.com'),
    (8093, 'Pallarès Casanovas', 'Ramon', DATE '1948-11-17', '629010179', NULL),
    (8102, 'Solergibert Fauría', 'Pere', DATE '1948-03-20', '620160961', 'pere@solergibert.net'),
    (8115, 'Ibañez Forte', 'Jose', DATE '1942-04-10', '655832630', 'jif42@hotmail.es'),
    (8121, 'Mayor Piñol', 'Josep', DATE '1949-06-21', '670977779', 'maypimayor@gmail.com'),
    (8133, 'Rodriguez Lopez', 'Juan', DATE '1958-02-22', '933506021', NULL),
    (8137, 'Muntané Merino', 'Joan Maria', DATE '1985-11-24', '619629989', 'joanma.muntane@gmail.com'),
    (8138, 'Cervantes Donenech', 'Roger', DATE '1985-05-18', '645347167', 'cervi_4@hotmail.com'),
    (8156, 'Gómez Cortés', 'Juan', DATE '1935-05-08', '674294714', '007juanjosegomez@gmail.com'),
    (8181, 'Polls Badia', 'Ricardo', DATE '1952-05-11', '640669944', 'raeltais@gmail.com'),
    (8183, 'Lahoz Troni', 'Enric', DATE '1946-02-19', '610616216', 'enlatro@gmail.com'),
    (8186, 'Hernández Márquez', 'Juan', DATE '1947-03-02', '661274827', NULL),
    (8208, 'Trillo Palma', 'Antonio', DATE '1963-11-06', '670845754', 'antriyo@hotmail.com'),
    (8212, 'Verdugo Martín', 'Francesc', DATE '1949-08-15', '646554065', NULL),
    (8215, 'Herrera Nuñez', 'Rafael', DATE '1942-10-04', '669838356', NULL),
    (8216, 'Pallisa Gonzalez', 'Jose', DATE '1955-12-12', '626923323', 'tekniko07@gmail.com'),
    (8264, 'Díaz Martín', 'Eduard', DATE '1961-06-24', '629284920', 'bluesmartini@hotmail.com'),
    (8280, 'Valles Gallego', 'Miguel', DATE '1926-06-16', '664162593', NULL),
    (8296, 'Saucedo Bascón', 'Jose Antonio', DATE '1963-03-12', '667272427', 'saucedobascon@hotmail.com'),
    (8309, 'Segura Gonzalez', 'Fernando', DATE '1962-10-03', '615975330', 'loobvio.fer@gmail.com'),
    (8310, 'Alvarez Martínez', 'Jose Miguel', DATE '1956-05-24', '628901213', 'correo.miguelalvarez@gmail.com'),
    (8311, 'Hernández Falcó', 'Ignacio', DATE '1954-06-06', '600352301', 'ignaciohernandezfalco@gmail.com'),
    (8335, 'Montaña Perez', 'Joan', DATE '1964-03-25', '653073578', 'joanmont@hotmail.com'),
    (8358, 'Miralles', 'Francisco', DATE '1970-04-29', '696353746', NULL),
    (8364, 'Briones Lorente', 'Miquel', DATE '1951-11-22', '688807257', 'miquelbriones@gmail.com'),
    (8366, 'Millan Sánchez', 'Eduardo', NULL, '659548990', 'eduardomillansanchez@gmail.com'),
    (8373, 'Girbes Gonzalez', 'Vicens', DATE '1949-05-18', '671958058', 'vgirbes@yahoo.es'),
    (8379, 'Martínez Molina', 'Andrés', DATE '1964-11-30', NULL, NULL),
    (8387, 'Gibernau Quintana', 'Joaquim', DATE '1958-01-01', '680419804', NULL),
    (8396, 'Arroyo Durán', 'Juan Luis', DATE '1942-06-03', '686622557', 'juanluis01@gmail.com'),
    (8407, 'Manzano García', 'Marià', NULL, '669904294', 'mariano.manzano@yahoo.es'),
    (8408, 'Casamor Regull', 'José Maria', DATE '1953-12-22', '630059263', NULL),
    (8409, 'Pérez Castillejos', 'Héctor', DATE '1977-08-27', '659867776', NULL),
    (8411, 'Royes Garcia', 'Eduardo', DATE '1961-06-13', '687943931', NULL),
    (8433, 'Curcó Aguarod', 'Enric', DATE '1938-05-03', '647423806', NULL),
    (8436, 'Moreno Barcia', 'Rafael', DATE '1963-01-05', '630427844', NULL),
    (8438, 'Mora Santamaria', 'Angel', NULL, '669392774', NULL),
    (8439, 'Muñoz López', 'Javier', NULL, '609915677', 'xaviml81@gmail.com'),
    (8440, 'Bellido gonzález', 'Ramón', NULL, '679200186', 'jrblld68@gmail.com'),
    (8464, 'Melgarejo Nicolás', 'Antonio', DATE '1942-04-05', '679686064', NULL),
    (8482, 'López Mallach', 'Miguel', DATE '1971-08-10', '629692446', 'miguel.lmfotografia@gmail.com'),
    (8483, 'Ledo Gasia', 'Francesc', DATE '1948-05-22', '607310321', 'francescledo@gmail.com'),
    (8485, 'Alvarez Valencia', 'Pedro', DATE '1942-07-02', '651904893', NULL),
    (8542, 'Bermejo Alias', 'Alfonso', DATE '1956-08-08', '648476941', NULL)
)
UPDATE socis s
SET
  data_naixement = COALESCE(s.data_naixement, c.naix),
  telefon        = COALESCE(s.telefon, c.tel),
  email          = COALESCE(s.email, c.email)
FROM cens c
WHERE s.numero_soci = c.n
  AND (
    (s.data_naixement IS NULL AND c.naix IS NOT NULL)
    OR (s.telefon IS NULL AND c.tel IS NOT NULL)
    OR (s.email IS NULL AND c.email IS NOT NULL)
  );

COMMIT;
