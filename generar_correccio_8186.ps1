# Script de correcció per afegir soci 8186 mancat
# Aquest soci té 31 registres històrics però no existeix a la base de dades

Write-Host "Afegint soci 8186 mancat..."

$correccio = @()
$correccio += "-- ================================================================="
$correccio += "-- CORRECCIÓ: AFEGIR SOCI 8186 MANCAT"
$correccio += "-- ================================================================="
$correccio += "-- El soci 8186 té 31 registres històrics des de 2014-2024"
$correccio += "-- però no existeix a la taula socis"
$correccio += "-- "
$correccio += "-- S'afegeix com a soci actiu sense determinar si és exsoci"
$correccio += "-- ================================================================="
$correccio += ""
$correccio += "BEGIN;"
$correccio += ""
$correccio += "-- Afegir soci 8186 mancat"
$correccio += "INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) "
$correccio += "VALUES (8186, '[MANCAT]', 'SOCI_8186', NULL, FALSE, NULL) ON CONFLICT (numero_soci) DO NOTHING;"
$correccio += ""
$correccio += "-- Verificar que s'ha afegit"
$correccio += "SELECT numero_soci, nom, cognoms, de_baixa FROM socis WHERE numero_soci = 8186;"
$correccio += ""
$correccio += "COMMIT;"

# Guardar script de correcció
$correccio | Out-File -FilePath "correccio_soci_8186.sql" -Encoding UTF8

Write-Host ""
Write-Host "====== SCRIPT DE CORRECCIÓ GENERAT ======"
Write-Host "Fitxer: correccio_soci_8186.sql"
Write-Host "Afegeix el soci 8186 mancat"
Write-Host "Executar abans del script principal"
Write-Host "========================================"