# Script per integrar exsocis coneguts amb noms i cognoms reals
# Processar el fitxer exsocisconeguts.txt i generar INSERT statements

Write-Host "Processant exsocis coneguts amb dades reals..."

# Llegir el fitxer d'exsocis coneguts
$exsocisConeguts = Get-Content "exsocisconeguts.txt" -Encoding UTF8

# Processar cada línia
$exsocisProcessats = @()
$duplicats = @{}

foreach ($linia in $exsocisConeguts) {
    if ($linia.Trim() -eq "") { continue }
    
    $camps = $linia -split '\t'
    if ($camps.Count -ge 3) {
        $numero_soci = $camps[0].Trim()
        $nom = $camps[1].Trim()
        $cognoms = $camps[2].Trim()
        
        # Verificar duplicats
        if ($duplicats.ContainsKey($numero_soci)) {
            Write-Host "DUPLICAT detectat: $numero_soci ($nom $cognoms)"
            continue
        }
        
        $duplicats[$numero_soci] = $true
        
        $exsocisProcessats += @{
            numero_soci = [int]$numero_soci
            nom = $nom
            cognoms = $cognoms
        }
    }
}

Write-Host "Exsocis processats: $($exsocisProcessats.Count)"
Write-Host "Duplicats eliminats: $($exsocisConeguts.Count - $exsocisProcessats.Count)"

# Ordenar per numero_soci
$exsocisOrdenats = $exsocisProcessats | Sort-Object { $_.numero_soci }

Write-Host "Rang IDs: $($exsocisOrdenats[0].numero_soci) - $($exsocisOrdenats[-1].numero_soci)"

# Generar script SQL
$sqlScript = @()
$sqlScript += "-- ================================================================="
$sqlScript += "-- SCRIPT: INTEGRAR EXSOCIS CONEGUTS AMB DADES REALS"
$sqlScript += "-- ================================================================="
$sqlScript += "-- Data: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$sqlScript += "-- Total exsocis coneguts: $($exsocisOrdenats.Count)"
$sqlScript += "-- Rang IDs: $($exsocisOrdenats[0].numero_soci) - $($exsocisOrdenats[-1].numero_soci)"
$sqlScript += "-- Aquests exsocis tenen noms i cognoms reals"
$sqlScript += "-- ================================================================="
$sqlScript += ""
$sqlScript += "BEGIN;"
$sqlScript += ""
$sqlScript += "-- Eliminar exsocis coneguts si ja existeixen per evitar duplicats"
$idsAEliminar = ($exsocisOrdenats | ForEach-Object { $_.numero_soci }) -join ','
$sqlScript += "DELETE FROM socis WHERE numero_soci IN ($idsAEliminar);"
$sqlScript += ""
$sqlScript += "-- Inserir exsocis coneguts amb dades reals"

foreach ($exsoci in $exsocisOrdenats) {
    # Escapar cometes simples
    $nomEscaped = $exsoci.nom.Replace("'", "''")
    $cognomsEscaped = $exsoci.cognoms.Replace("'", "''")
    
    $sql = "INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES ($($exsoci.numero_soci), '$nomEscaped', '$cognomsEscaped', NULL, TRUE, '2024-12-31');"
    $sqlScript += $sql
}

$sqlScript += ""
$sqlScript += "-- Verificacions"
$sqlScript += "SELECT COUNT(*) as exsocis_coneguts_inserits FROM socis WHERE numero_soci IN ($idsAEliminar);"
$sqlScript += ""
$sqlScript += "-- Mostrar alguns exsocis inserits"
$sqlScript += "SELECT numero_soci, nom, cognoms, de_baixa FROM socis WHERE numero_soci IN ($idsAEliminar) ORDER BY numero_soci LIMIT 10;"
$sqlScript += ""
$sqlScript += "COMMIT;"

# Guardar script
$sqlScript | Out-File -FilePath "script_exsocis_coneguts.sql" -Encoding UTF8

Write-Host ""
Write-Host "====== SCRIPT EXSOCIS CONEGUTS GENERAT ======"
Write-Host "Fitxer: script_exsocis_coneguts.sql"
Write-Host "Exsocis coneguts: $($exsocisOrdenats.Count)"
Write-Host "=============================================="

# També generar llista de IDs que encara falten
$totsElsIds = Get-Content "llista_tots_soci_ids.txt" | ForEach-Object { [int]$_.Trim() }
$idsExsocisConeguts = $exsocisOrdenats | ForEach-Object { $_.numero_soci }
$idsQueFalten = $totsElsIds | Where-Object { $_ -notin $idsExsocisConeguts -and $_ -gt 34 }

Write-Host ""
Write-Host "=== ANÀLISI DE COBERTURA ==="
Write-Host "Total IDs necessaris: $($totsElsIds.Count)"
Write-Host "Exsocis 1-34: 34"
Write-Host "Exsocis coneguts: $($idsExsocisConeguts.Count)"
Write-Host "IDs que encara falten: $($idsQueFalten.Count)"

if ($idsQueFalten.Count -gt 0) {
    Write-Host "IDs sense dades: $($idsQueFalten -join ', ')"
    $idsQueFalten | Out-File -FilePath "ids_encara_falten.txt" -Encoding UTF8
    Write-Host "Llista guardada a: ids_encara_falten.txt"
}
Write-Host "============================"