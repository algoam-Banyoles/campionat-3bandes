# Analitzar tots els socis mancats del script de mitjanes històriques
# Buscar quins socis tenen dades històriques però no estan als fitxers de socis coneguts

Write-Host "Analitzant socis mancats..."

# Extreure tots els soci_id del script
$contingut = Get-Content "script_cloud_final_complet.sql" -Encoding UTF8
$socisHistorics = @{}

foreach ($linia in $contingut) {
    if ($linia -match "VALUES \((\d+),") {
        $soci_id = $matches[1]
        if (-not $socisHistorics.ContainsKey($soci_id)) {
            $socisHistorics[$soci_id] = 0
        }
        $socisHistorics[$soci_id]++
    }
}

Write-Host "Socis trobats al script: $($socisHistorics.Count)"

# Socis coneguts (exsocis històrics 1-34)
$socisHistoricsConeguts = 1..34

# Socis coneguts del fitxer exsocisconeguts.txt
$socisExconeguts = @()
$exsocisConeguts = Get-Content "exsocisconeguts.txt" -Encoding UTF8
foreach ($linia in $exsocisConeguts) {
    if ($linia.Trim() -eq "") { continue }
    $camps = $linia -split '\t'
    if ($camps.Count -ge 1) {
        $socisExconeguts += [int]$camps[0].Trim()
    }
}

Write-Host "Exsocis coneguts: $($socisExconeguts.Count)"

# Trobar socis mancats
$socisMancats = @()
foreach ($soci_id in $socisHistorics.Keys) {
    $id = [int]$soci_id
    if ($id -notin $socisHistoricsConeguts -and $id -notin $socisExconeguts) {
        $socisMancats += @{
            'id' = $id
            'registres' = $socisHistorics[$soci_id]
        }
    }
}

$socisMancats = $socisMancats | Sort-Object { $_.id }

Write-Host ""
Write-Host "====== SOCIS MANCATS TROBATS ======"
Write-Host "Total socis mancats: $($socisMancats.Count)"
Write-Host ""

foreach ($soci in $socisMancats) {
    Write-Host "Soci $($soci.id): $($soci.registres) registres històrics"
}

# Generar script de correcció per tots els socis mancats
$correccio = @()
$correccio += "-- ================================================================="
$correccio += "-- CORRECCIÓ: AFEGIR SOCIS MANCATS"
$correccio += "-- ================================================================="
$correccio += "-- Data: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$correccio += "-- Socis amb dades històriques que no existeixen a la base de dades"
$correccio += "-- "
$correccio += "-- TOTAL SOCIS MANCATS: $($socisMancats.Count)"
foreach ($soci in $socisMancats) {
    $correccio += "-- • Soci $($soci.id): $($soci.registres) registres històrics"
}
$correccio += "-- ================================================================="
$correccio += ""
$correccio += "BEGIN;"
$correccio += ""
$correccio += "-- Afegir socis mancats"
$correccio += "INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES"

$inserts = @()
foreach ($soci in $socisMancats) {
    $inserts += "($($soci.id), '[MANCAT]', 'SOCI_$($soci.id)', NULL, FALSE, NULL)"
}

$correccio += $inserts -join ",`n"
$correccio += " ON CONFLICT (numero_soci) DO NOTHING;"
$correccio += ""
$correccio += "-- Verificar socis afegits"
$correccio += "SELECT 'Socis mancats afegits:' as status, COUNT(*) as total"
$correccio += "FROM socis WHERE numero_soci IN ("
$correccio += ($socisMancats | ForEach-Object { $_.id }) -join ", "
$correccio += ");"
$correccio += ""
$correccio += "COMMIT;"

# Guardar script de correcció
$correccio | Out-File -FilePath "correccio_socis_mancats.sql" -Encoding UTF8

Write-Host ""
Write-Host "====== SCRIPT DE CORRECCIÓ GENERAT ======"
Write-Host "Fitxer: correccio_socis_mancats.sql"
Write-Host "Afegeix $($socisMancats.Count) socis mancats"
Write-Host "Executar ABANS dels altres scripts"
Write-Host "========================================"