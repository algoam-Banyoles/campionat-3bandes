# Script per generar un script SQL complet que soluciona el problema de foreign keys
# Inclou: exsocis 1-34, exsocis coneguts, i placeholders per IDs que falten

Write-Host "Generant script SQL complet per solucionar foreign key constraints..."

# Llegir IDs que encara falten
$idsQueFalten = Get-Content "ids_encara_falten.txt" | ForEach-Object { [int]$_.Trim() }

Write-Host "IDs que necessiten placeholders: $($idsQueFalten.Count)"

# Generar script complet
$scriptComplet = @()
$scriptComplet += "-- ================================================================="
$scriptComplet += "-- SCRIPT COMPLET: SOLUCIÓ DEFINITIVA FOREIGN KEYS"
$scriptComplet += "-- ================================================================="
$scriptComplet += "-- Data: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$scriptComplet += "-- Objectiu: Afegir tots els socis necessaris per a mitjanes històriques"
$scriptComplet += "-- "
$scriptComplet += "-- COBERTURA:"
$scriptComplet += "-- • Exsocis 1-34: amb dades històriques estimades"
$scriptComplet += "-- • Exsocis coneguts: 48 amb noms i cognoms reals"
$scriptComplet += "-- • Placeholders: $($idsQueFalten.Count) socis sense dades conegudes"
$scriptComplet += "-- ================================================================="
$scriptComplet += ""
$scriptComplet += "BEGIN;"
$scriptComplet += ""

# STEP 1: Afegir contingut del script d'exsocis 1-34
$scriptComplet += "-- ================================================================="
$scriptComplet += "-- STEP 1: EXSOCIS HISTÒRICS (IDs 1-34)"
$scriptComplet += "-- ================================================================="
$contingutExsocis = Get-Content "script_cloud_integracio_exsocis.sql" -Encoding UTF8
$dentroTransaccio = $false
foreach ($linia in $contingutExsocis) {
    if ($linia -match "^BEGIN;") {
        $dentroTransaccio = $true
        continue
    }
    if ($linia -match "^COMMIT;") {
        $dentroTransaccio = $false
        continue
    }
    if ($dentroTransaccio) {
        $scriptComplet += $linia
    }
}

$scriptComplet += ""

# STEP 2: Afegir exsocis coneguts
$scriptComplet += "-- ================================================================="
$scriptComplet += "-- STEP 2: EXSOCIS CONEGUTS AMB DADES REALS"
$scriptComplet += "-- ================================================================="
$contingutConeguts = Get-Content "script_exsocis_coneguts.sql" -Encoding UTF8
$dentroTransaccio = $false
foreach ($linia in $contingutConeguts) {
    if ($linia -match "^BEGIN;") {
        $dentroTransaccio = $true
        continue
    }
    if ($linia -match "^COMMIT;") {
        $dentroTransaccio = $false
        continue
    }
    if ($dentroTransaccio) {
        $scriptComplet += $linia
    }
}

$scriptComplet += ""

# STEP 3: Afegir placeholders per IDs que falten
$scriptComplet += "-- ================================================================="
$scriptComplet += "-- STEP 3: PLACEHOLDERS PER SOCIS DESCONEGUTS"
$scriptComplet += "-- ================================================================="
$scriptComplet += "-- Aquests són socis que apareixen a mitjanes històriques però"
$scriptComplet += "-- no tenim les seves dades. Es creen com a placeholders."
$scriptComplet += ""

foreach ($id in $idsQueFalten) {
    $nomTemp = "SOCI_$id"
    $cognomsTemp = "DESCONEGUT"
    $sql = "INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES ($id, '$nomTemp', '$cognomsTemp', NULL, FALSE, NULL);"
    $scriptComplet += $sql
}

$scriptComplet += ""

# STEP 4: Verificacions finals
$scriptComplet += "-- ================================================================="
$scriptComplet += "-- STEP 4: VERIFICACIONS FINALS"
$scriptComplet += "-- ================================================================="
$scriptComplet += ""
$scriptComplet += "-- Comptar tots els socis per categoria"
$scriptComplet += "SELECT "
$scriptComplet += "    CASE "
$scriptComplet += "        WHEN numero_soci BETWEEN 1 AND 34 THEN 'Exsocis històrics'"
$scriptComplet += "        WHEN nom NOT LIKE 'SOCI_%' AND de_baixa = TRUE THEN 'Exsocis coneguts'"
$scriptComplet += "        WHEN nom LIKE 'SOCI_%' THEN 'Placeholders'"
$scriptComplet += "        ELSE 'Socis actius'"
$scriptComplet += "    END as categoria,"
$scriptComplet += "    COUNT(*) as total"
$scriptComplet += "FROM socis "
$scriptComplet += "GROUP BY "
$scriptComplet += "    CASE "
$scriptComplet += "        WHEN numero_soci BETWEEN 1 AND 34 THEN 'Exsocis històrics'"
$scriptComplet += "        WHEN nom NOT LIKE 'SOCI_%' AND de_baixa = TRUE THEN 'Exsocis coneguts'"
$scriptComplet += "        WHEN nom LIKE 'SOCI_%' THEN 'Placeholders'"
$scriptComplet += "        ELSE 'Socis actius'"
$scriptComplet += "    END"
$scriptComplet += "ORDER BY categoria;"
$scriptComplet += ""
$scriptComplet += "-- Verificar que no hi ha cap ID orfe a mitjanes històriques"
$scriptComplet += "SELECT COUNT(*) as ids_orfes "
$scriptComplet += "FROM mitjanes_historiques mh "
$scriptComplet += "LEFT JOIN socis s ON mh.soci_id = s.numero_soci "
$scriptComplet += "WHERE s.numero_soci IS NULL;"
$scriptComplet += ""
$scriptComplet += "COMMIT;"
$scriptComplet += ""
$scriptComplet += "-- ================================================================="
$scriptComplet += "-- RESULTAT FINAL ESPERAT:"
$scriptComplet += "-- • Total socis: $($34 + 48 + $idsQueFalten.Count)"
$scriptComplet += "-- • Exsocis històrics: 34"
$scriptComplet += "-- • Exsocis coneguts: 48"
$scriptComplet += "-- • Placeholders: $($idsQueFalten.Count)"
$scriptComplet += "-- • IDs orfes: 0"
$scriptComplet += "-- ================================================================="

# Guardar script complet
$scriptComplet | Out-File -FilePath "script_solucio_completa.sql" -Encoding UTF8

Write-Host ""
Write-Host "====== SCRIPT SOLUCIÓ COMPLETA GENERAT ======"
Write-Host "Fitxer: script_solucio_completa.sql"
Write-Host "Exsocis històrics: 34"
Write-Host "Exsocis coneguts: 48"
Write-Host "Placeholders: $($idsQueFalten.Count)"
Write-Host "Total socis: $($34 + 48 + $idsQueFalten.Count)"
Write-Host "=============================================="
Write-Host ""
Write-Host "ORDRE D'EXECUCIÓ RECOMANAT:"
Write-Host "1. script_solucio_completa.sql  ← PRIMER (afegeix tots els socis)"
Write-Host "2. script_cloud_final_complet.sql ← SEGON (carrega mitjanes històriques)"
Write-Host "=============================================="