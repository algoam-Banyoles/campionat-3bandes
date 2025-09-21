# Script simplificat - només exsocis (els socis actius ja existeixen)
# Genera script SQL només amb els exsocis necessaris

Write-Host "Generant script simplificat - només exsocis..."

# Generar script només amb exsocis
$scriptSimplificat = @()
$scriptSimplificat += "-- ================================================================="
$scriptSimplificat += "-- SCRIPT SIMPLIFICAT: NOMÉS EXSOCIS"
$scriptSimplificat += "-- ================================================================="
$scriptSimplificat += "-- Data: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$scriptSimplificat += "-- Objectiu: Afegir només els exsocis necessaris"
$scriptSimplificat += "-- Els socis actius ja existeixen a la base de dades"
$scriptSimplificat += "-- "
$scriptSimplificat += "-- COBERTURA:"
$scriptSimplificat += "-- • Exsocis històrics (1-34): 34 socis"
$scriptSimplificat += "-- • Exsocis coneguts: 48 socis"
$scriptSimplificat += "-- • Socis actius: ja existeixen a la BD"
$scriptSimplificat += "-- ================================================================="
$scriptSimplificat += ""
$scriptSimplificat += "BEGIN;"
$scriptSimplificat += ""

# STEP 1: Afegir exsocis històrics (1-34)
$scriptSimplificat += "-- ================================================================="
$scriptSimplificat += "-- STEP 1: EXSOCIS HISTÒRICS (IDs 1-34)"
$scriptSimplificat += "-- ================================================================="
$scriptSimplificat += ""
$scriptSimplificat += "-- Afegir camp 'de_baixa' si no existeix"
$scriptSimplificat += "DO `$`$"
$scriptSimplificat += "BEGIN"
$scriptSimplificat += "    IF NOT EXISTS ("
$scriptSimplificat += "        SELECT 1 FROM information_schema.columns "
$scriptSimplificat += "        WHERE table_name = 'socis' AND column_name = 'de_baixa'"
$scriptSimplificat += "    ) THEN"
$scriptSimplificat += "        ALTER TABLE socis ADD COLUMN de_baixa BOOLEAN DEFAULT FALSE;"
$scriptSimplificat += "        RAISE NOTICE 'Camp de_baixa afegit a la taula socis';"
$scriptSimplificat += "    END IF;"
$scriptSimplificat += "END `$`$;"
$scriptSimplificat += ""
$scriptSimplificat += "-- Afegir camp 'data_baixa' si no existeix"
$scriptSimplificat += "DO `$`$"
$scriptSimplificat += "BEGIN"
$scriptSimplificat += "    IF NOT EXISTS ("
$scriptSimplificat += "        SELECT 1 FROM information_schema.columns "
$scriptSimplificat += "        WHERE table_name = 'socis' AND column_name = 'data_baixa'"
$scriptSimplificat += "    ) THEN"
$scriptSimplificat += "        ALTER TABLE socis ADD COLUMN data_baixa DATE NULL;"
$scriptSimplificat += "        RAISE NOTICE 'Camp data_baixa afegit a la taula socis';"
$scriptSimplificat += "    END IF;"
$scriptSimplificat += "END `$`$;"
$scriptSimplificat += ""
$scriptSimplificat += "-- Crear índex per millorar consultes"
$scriptSimplificat += "CREATE INDEX IF NOT EXISTS idx_socis_de_baixa ON socis(de_baixa);"
$scriptSimplificat += ""
$scriptSimplificat += "-- Eliminar exsocis 1-34 si ja existeixen"
$scriptSimplificat += "DELETE FROM socis WHERE numero_soci BETWEEN 1 AND 34;"
$scriptSimplificat += ""
$scriptSimplificat += "-- Inserir exsocis històrics"
$scriptSimplificat += "INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES"
$scriptSimplificat += "(1, 'A.', 'ALUJA', NULL, TRUE, '2011-12-31'),"
$scriptSimplificat += "(2, 'A.', 'FERNÁNDEZ', NULL, TRUE, '2024-12-31'),"
$scriptSimplificat += "(3, 'A.', 'MARTÍ', NULL, TRUE, '2009-12-31'),"
$scriptSimplificat += "(4, '[EXSOCI]', 'ALBARRACIN', NULL, TRUE, '2009-12-31'),"
$scriptSimplificat += "(5, '[EXSOCI]', 'ALCARAZ', NULL, TRUE, '2008-12-31'),"
$scriptSimplificat += "(6, '[EXSOCI]', 'BARRIENTOS', NULL, TRUE, '2009-12-31'),"
$scriptSimplificat += "(7, '[EXSOCI]', 'BARRIERE', NULL, TRUE, '2004-12-31'),"
$scriptSimplificat += "(8, 'C.', 'GIRÓ', NULL, TRUE, '2012-12-31'),"
$scriptSimplificat += "(9, '[EXSOCI]', 'CASBAS', NULL, TRUE, '2004-12-31'),"
$scriptSimplificat += "(10, '[EXSOCI]', 'DOMÉNECH', NULL, TRUE, '2017-12-31'),"
$scriptSimplificat += "(11, '[EXSOCI]', 'DONADEU', NULL, TRUE, '2003-12-31'),"
$scriptSimplificat += "(12, '[EXSOCI]', 'DURAN', NULL, TRUE, '2009-12-31'),"
$scriptSimplificat += "(13, 'E.', 'GIRÓ', NULL, TRUE, '2012-12-31'),"
$scriptSimplificat += "(14, 'E.', 'LLORENTE', NULL, TRUE, '2021-12-31'),"
$scriptSimplificat += "(15, '[EXSOCI]', 'ERRA', NULL, TRUE, '2008-12-31'),"
$scriptSimplificat += "(16, 'J.', 'LAHOZ', NULL, TRUE, '2017-12-31'),"
$scriptSimplificat += "(17, 'J.', 'ROVIROSA', NULL, TRUE, '2011-12-31'),"
$scriptSimplificat += "(18, 'JUAN', 'GÓMEZ', NULL, TRUE, '2018-12-31'),"
$scriptSimplificat += "(19, 'M.', 'ALMIRALL', NULL, TRUE, '2011-12-31'),"
$scriptSimplificat += "(20, 'M.', 'PALAU', NULL, TRUE, '2011-12-31'),"
$scriptSimplificat += "(21, 'M.', 'PRAT', NULL, TRUE, '2012-12-31'),"
$scriptSimplificat += "(22, '[EXSOCI]', 'MAGRIÑA', NULL, TRUE, '2003-12-31'),"
$scriptSimplificat += "(23, 'P.', 'RUIZ', NULL, TRUE, '2023-12-31'),"
$scriptSimplificat += "(24, '[EXSOCI]', 'PEÑA', NULL, TRUE, '2006-12-31'),"
$scriptSimplificat += "(25, '[EXSOCI]', 'PUIG', NULL, TRUE, '2007-12-31'),"
$scriptSimplificat += "(26, '[EXSOCI]', 'REAL', NULL, TRUE, '2007-12-31'),"
$scriptSimplificat += "(27, '[EXSOCI]', 'RODRÍGUEZ', NULL, TRUE, '2009-12-31'),"
$scriptSimplificat += "(28, 'S.', 'BASCÓN', NULL, TRUE, '2020-12-31'),"
$scriptSimplificat += "(29, '[EXSOCI]', 'SOLANES', NULL, TRUE, '2009-12-31'),"
$scriptSimplificat += "(30, '[EXSOCI]', 'SOLANS', NULL, TRUE, '2008-12-31'),"
$scriptSimplificat += "(31, '[EXSOCI]', 'SUÑE', NULL, TRUE, '2008-12-31'),"
$scriptSimplificat += "(32, '[EXSOCI]', 'TABERNER', NULL, TRUE, '2005-12-31'),"
$scriptSimplificat += "(33, '[EXSOCI]', 'TALAVERA', NULL, TRUE, '2004-12-31'),"
$scriptSimplificat += "(34, '[EXSOCI]', 'VIVAS', NULL, TRUE, '2009-12-31');"
$scriptSimplificat += ""

# STEP 2: Afegir exsocis coneguts
$scriptSimplificat += "-- ================================================================="
$scriptSimplificat += "-- STEP 2: EXSOCIS CONEGUTS AMB DADES REALS"
$scriptSimplificat += "-- ================================================================="

# Llegir exsocis coneguts
$exsocisConeguts = Get-Content "exsocisconeguts.txt" -Encoding UTF8
$duplicats = @{}

foreach ($linia in $exsocisConeguts) {
    if ($linia.Trim() -eq "") { continue }
    
    $camps = $linia -split '\t'
    if ($camps.Count -ge 3) {
        $numero_soci = $camps[0].Trim()
        $nom = $camps[1].Trim().Replace("'", "''")
        $cognoms = $camps[2].Trim().Replace("'", "''")
        
        # Evitar duplicats
        if ($duplicats.ContainsKey($numero_soci)) { continue }
        $duplicats[$numero_soci] = $true
        
        $sql = "INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES ($numero_soci, '$nom', '$cognoms', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;"
        $scriptSimplificat += $sql
    }
}

$scriptSimplificat += ""
$scriptSimplificat += "-- ================================================================="
$scriptSimplificat += "-- VERIFICACIONS FINALS"
$scriptSimplificat += "-- ================================================================="
$scriptSimplificat += ""
$scriptSimplificat += "-- Comptar exsocis afegits"
$scriptSimplificat += "SELECT "
$scriptSimplificat += "    CASE "
$scriptSimplificat += "        WHEN numero_soci BETWEEN 1 AND 34 THEN 'Exsocis històrics'"
$scriptSimplificat += "        WHEN de_baixa = TRUE THEN 'Exsocis coneguts'"
$scriptSimplificat += "        ELSE 'Socis actius'"
$scriptSimplificat += "    END as categoria,"
$scriptSimplificat += "    COUNT(*) as total"
$scriptSimplificat += "FROM socis "
$scriptSimplificat += "GROUP BY categoria"
$scriptSimplificat += "ORDER BY categoria;"
$scriptSimplificat += ""
$scriptSimplificat += "COMMIT;"

# Guardar script simplificat
$scriptSimplificat | Out-File -FilePath "script_final_simplificat.sql" -Encoding UTF8

Write-Host ""
Write-Host "====== SCRIPT SIMPLIFICAT GENERAT ======"
Write-Host "Fitxer: script_final_simplificat.sql"
Write-Host "Només afegeix exsocis (els socis actius ja existeixen)"
Write-Host "Exsocis històrics: 34"
Write-Host "Exsocis coneguts: 48"
Write-Host "========================================"