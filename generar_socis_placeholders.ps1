# Script per generar INSERT statements per a tots els soci_id que falten
# Crea placeholders temporals per als socis que apareixen a mitjanes històriques
# però no existeixen a la taula socis

Write-Host "Generant INSERT statements per a socis que falten..."

# Llegir la llista de tots els IDs
$totsElsIds = Get-Content "llista_tots_soci_ids.txt" | ForEach-Object { [int]$_.Trim() }

# Filtrar només els IDs > 34 (els exsocis 1-34 ja els tenim)
$socisQueFalten = $totsElsIds | Where-Object { $_ -gt 34 }

Write-Host "IDs a afegir: $($socisQueFalten.Count)"
Write-Host "Rang: $($socisQueFalten[0]) - $($socisQueFalten[-1])"

# Generar script SQL
$sqlScript = @()
$sqlScript += "-- ================================================================="
$sqlScript += "-- SCRIPT: AFEGIR SOCIS QUE FALTEN (PLACEHOLDERS)"
$sqlScript += "-- ================================================================="
$sqlScript += "-- Total socis a afegir: $($socisQueFalten.Count)"
$sqlScript += "-- Aquests són placeholders temporals per socis que apareixen"
$sqlScript += "-- a mitjanes històriques però no existeixen a la taula socis"
$sqlScript += "-- Es poden actualitzar posteriorment amb dades reals"
$sqlScript += "-- ================================================================="
$sqlScript += ""
$sqlScript += "BEGIN;"
$sqlScript += ""

foreach ($id in $socisQueFalten) {
    # Crear nom temporal basat en l'ID
    $nomTemp = "SOCI_$id"
    $cognomsTemp = "DESCONEGUT"
    
    $sql = "INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES ($id, '$nomTemp', '$cognomsTemp', NULL, FALSE, NULL);"
    $sqlScript += $sql
}

$sqlScript += ""
$sqlScript += "-- Verificar inserció"
$sqlScript += "SELECT COUNT(*) as socis_afegits FROM socis WHERE numero_soci > 34;"
$sqlScript += ""
$sqlScript += "COMMIT;"
$sqlScript += ""
$sqlScript += "-- ================================================================="
$sqlScript += "-- NOTA: Aquests són placeholders temporals"
$sqlScript += "-- Actualitza amb dades reals quan estiguin disponibles:"
$sqlScript += "-- UPDATE socis SET nom = 'NOM_REAL', cognoms = 'COGNOMS_REALS' WHERE numero_soci = [ID];"
$sqlScript += "-- ================================================================="

# Guardar script
$sqlScript | Out-File -FilePath "script_afegir_socis_placeholders.sql" -Encoding UTF8

Write-Host ""
Write-Host "====== SCRIPT GENERAT ======"
Write-Host "Fitxer: script_afegir_socis_placeholders.sql"
Write-Host "Socis a afegir: $($socisQueFalten.Count)"
Write-Host "Aquest script crea placeholders temporals"
Write-Host "=================================="

# També crear un script combinat que faci tot d'una vegada
$scriptCombinat = @()
$scriptCombinat += "-- ================================================================="
$scriptCombinat += "-- SCRIPT COMBINAT: EXSOCIS + SOCIS PLACEHOLDERS + MITJANES"
$scriptCombinat += "-- ================================================================="
$scriptCombinat += "-- STEP 1: Afegir exsocis (1-34)"
$scriptCombinat += "-- STEP 2: Afegir socis placeholders (35+)"
$scriptCombinat += "-- STEP 3: Carregar mitjanes històriques"
$scriptCombinat += "-- ================================================================="
$scriptCombinat += ""

# Afegir contingut del primer script (exsocis)
$contingutExsocis = Get-Content "script_cloud_integracio_exsocis.sql" -Encoding UTF8
$scriptCombinat += $contingutExsocis
$scriptCombinat += ""
$scriptCombinat += "-- ================================================================="
$scriptCombinat += "-- STEP 2: AFEGIR SOCIS QUE FALTEN"
$scriptCombinat += "-- ================================================================="
$scriptCombinat += ""

# Afegir els placeholders (sense BEGIN/COMMIT perquè ja estem en una transacció)
foreach ($id in $socisQueFalten) {
    $nomTemp = "SOCI_$id"
    $cognomsTemp = "DESCONEGUT"
    $sql = "INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES ($id, '$nomTemp', '$cognomsTemp', NULL, FALSE, NULL);"
    $scriptCombinat += $sql
}

$scriptCombinat += ""
$scriptCombinat += "-- Verificar que tots els socis necessaris estan a la taula"
$scriptCombinat += "SELECT COUNT(*) as total_socis FROM socis;"
$scriptCombinat += ""

$scriptCombinat | Out-File -FilePath "script_complet_amb_placeholders.sql" -Encoding UTF8

Write-Host "Script combinat: script_complet_amb_placeholders.sql"
Write-Host "=================================="