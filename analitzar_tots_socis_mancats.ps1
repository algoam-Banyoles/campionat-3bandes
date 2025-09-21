# Analitzar tots els socis mancats del script de mitjanes històriques
# Aquest script identificarà TOTS els socis que falten per resoldre el problema definitivament

Write-Host "Analitzant tots els socis mancats del script..."

# Llegir el script i extreure tots els soci_id únics
$contingut = Get-Content "script_cloud_final_complet.sql" -Encoding UTF8
$socisHistorics = @{}
$socisAmbNoms = @{}

foreach ($linia in $contingut) {
    # Buscar línies amb dades històriques que inclouen nom del jugador
    if ($linia -match "VALUES \((\d+), (\d+), '([^']+)', \d+, '([^']+)', ([0-9,\.]+)\)") {
        $soci_id = $matches[1]
        $jugador = $matches[4]
        
        if (-not $socisHistorics.ContainsKey($soci_id)) {
            $socisHistorics[$soci_id] = 0
            $socisAmbNoms[$soci_id] = $jugador
        }
        $socisHistorics[$soci_id]++
    }
    # També buscar línies sense nom del jugador
    elseif ($linia -match "VALUES \((\d+), (\d+), '([^']+)', ([0-9,\.]+)\)") {
        $soci_id = $matches[1]
        
        if (-not $socisHistorics.ContainsKey($soci_id)) {
            $socisHistorics[$soci_id] = 0
        }
        $socisHistorics[$soci_id]++
    }
}

Write-Host "Total socis trobats al script: $($socisHistorics.Count)"
Write-Host ""

# Socis coneguts - exsocis històrics (1-34)
$socisHistoricsConeguts = 1..34

# Socis coneguts del fitxer exsocisconeguts.txt
$socisExconeguts = @()
if (Test-Path "exsocisconeguts.txt") {
    $exsocisConeguts = Get-Content "exsocisconeguts.txt" -Encoding UTF8
    foreach ($linia in $exsocisConeguts) {
        if ($linia.Trim() -eq "") { continue }
        $camps = $linia -split '\t'
        if ($camps.Count -ge 1) {
            $socisExconeguts += [int]$camps[0].Trim()
        }
    }
}

Write-Host "Exsocis coneguts: $($socisExconeguts.Count)"
Write-Host ""

# Socis que sabem que ja existeixen (Juan Hernández Márquez)
$socisJaCorregits = @(8186)

# Trobar socis mancats
$socisMancats = @()
foreach ($soci_id in $socisHistorics.Keys) {
    $id = [int]$soci_id
    if ($id -notin $socisHistoricsConeguts -and 
        $id -notin $socisExconeguts -and 
        $id -notin $socisJaCorregits) {
        
        $nom = "DESCONEGUT"
        if ($socisAmbNoms.ContainsKey($soci_id)) {
            $nom = $socisAmbNoms[$soci_id]
        }
        
        $socisMancats += @{
            'id' = $id
            'registres' = $socisHistorics[$soci_id]
            'nom' = $nom
        }
    }
}

$socisMancats = $socisMancats | Sort-Object { $_.id }

Write-Host "====== SOCIS MANCATS TROBATS ======"
Write-Host "Total socis mancats: $($socisMancats.Count)"
Write-Host ""
Write-Host "ID     | Registres | Nom del Jugador"
Write-Host "-------|-----------|----------------"

foreach ($soci in $socisMancats) {
    $padding = " " * (6 - $soci.id.ToString().Length)
    Write-Host "$($soci.id)$padding | $($soci.registres)        | $($soci.nom)"
}

# Generar script de correcció complet
$correccio = @()
$correccio += "-- ================================================================="
$correccio += "-- CORRECCIÓ COMPLETA: TOTS ELS SOCIS MANCATS"
$correccio += "-- ================================================================="
$correccio += "-- Data: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$correccio += "-- Socis amb dades històriques que no existeixen a la base de dades"
$correccio += "-- "
$correccio += "-- TOTAL SOCIS MANCATS: $($socisMancats.Count)"
$correccio += "-- NOTA: Juan Hernández Márquez (8186) ja està corregit en un altre script"
$correccio += ""
foreach ($soci in $socisMancats) {
    $correccio += "-- • Soci $($soci.id): $($soci.registres) registres - $($soci.nom)"
}
$correccio += "-- ================================================================="
$correccio += ""
$correccio += "BEGIN;"
$correccio += ""
$correccio += "-- Afegir socis mancats (marcats com a socis actius)"
$correccio += "INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES"

$inserts = @()
foreach ($soci in $socisMancats) {
    # Separar nom i cognoms si es pot
    $noms = $soci.nom -split '\s+'
    $primerNom = $noms[0]
    $cognoms = if ($noms.Length -gt 1) { ($noms[1..($noms.Length-1)] -join ' ') } else { "COGNOM_MANCAT" }
    
    $inserts += "($($soci.id), '$primerNom', '$cognoms', NULL, FALSE, NULL)"
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
$correccio += "-- Llistar els socis afegits amb detalls"
$correccio += "SELECT numero_soci, nom, cognoms, 'Afegit per correcció' as notes"
$correccio += "FROM socis WHERE numero_soci IN ("
$correccio += ($socisMancats | ForEach-Object { $_.id }) -join ", "
$correccio += ")"
$correccio += "ORDER BY numero_soci;"
$correccio += ""
$correccio += "COMMIT;"

# Guardar script de correcció
$correccio | Out-File -FilePath "correccio_tots_socis_mancats.sql" -Encoding UTF8

Write-Host ""
Write-Host "====== SCRIPT DE CORRECCIÓ GENERAT ======"
Write-Host "Fitxer: correccio_tots_socis_mancats.sql"
Write-Host "Afegeix $($socisMancats.Count) socis mancats"
Write-Host "Executar ABANS del script principal"
Write-Host "========================================"