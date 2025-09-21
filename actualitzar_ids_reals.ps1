# Script per actualitzar les mitjanes històriques amb IDs reals dels exsocis
# Canvia els IDs 00XX pels IDs reals 1-34 que ara tindran a la taula socis

Write-Host "Actualitzant mitjanes històriques amb IDs reals dels exsocis..."

# Mapa de conversió d'IDs
$mapIds = @{
    "0001" = "1"
    "0002" = "2"
    "0003" = "3"
    "0004" = "4"
    "0005" = "5"
    "0006" = "6"
    "0007" = "7"
    "0008" = "8"
    "0009" = "9"
    "0010" = "10"
    "0011" = "11"
    "0012" = "12"
    "0013" = "13"
    "0014" = "14"
    "0015" = "15"
    "0016" = "16"
    "0017" = "17"
    "0018" = "18"
    "0019" = "19"
    "0020" = "20"
    "0021" = "21"
    "0022" = "22"
    "0023" = "23"
    "0024" = "24"
    "0025" = "25"
    "0026" = "26"
    "0027" = "27"
    "0028" = "28"
    "0029" = "29"
    "0030" = "30"
    "0031" = "31"
    "0032" = "32"
    "0033" = "33"
    "0034" = "34"
}

# Llegir el fitxer original
$contingutOriginal = Get-Content "mitjanes_historiques_final.txt" -Encoding UTF8

Write-Host "Fitxer original: $($contingutOriginal.Count) línies"

# Processar cada línia
$contingutActualitzat = @()
$substitucions = 0

foreach ($linia in $contingutOriginal) {
    $liniaActualitzada = $linia
    
    # Buscar i substituir cada ID (al final de la línia)
    foreach ($antic in $mapIds.Keys) {
        if ($linia -match "\t$antic$") {
            $nou = $mapIds[$antic]
            $liniaActualitzada = $liniaActualitzada -replace "\t$antic$", "`t$nou"
            $substitucions++
            Write-Host "Substitució: $antic → $nou"
            break
        }
    }
    
    $contingutActualitzat += $liniaActualitzada
}

# Guardar fitxer actualitzat
$contingutActualitzat | Out-File -FilePath "mitjanes_historiques_ids_reals.txt" -Encoding UTF8

Write-Host ""
Write-Host "====== ACTUALITZACIÓ COMPLETADA ======"
Write-Host "Fitxer generat: mitjanes_historiques_ids_reals.txt"
Write-Host "Total línies: $($contingutActualitzat.Count)"
Write-Host "Substitucions fetes: $substitucions"
Write-Host "=================================="

# Verificar que no queden IDs 00XX
$idsAntics = $contingutActualitzat | Where-Object { $_ -match "\t00\d\d\t" }
if ($idsAntics.Count -eq 0) {
    Write-Host "✅ Cap ID 00XX restant"
} else {
    Write-Host "⚠️  Encara queden $($idsAntics.Count) IDs 00XX"
}

# Mostrar resum d'IDs utilitzats
Write-Host ""
Write-Host "=== RESUM IDs UTILITZATS ==="
$idsUtilitzats = @{}
foreach ($linia in $contingutActualitzat) {
    if ($linia -match "\t(\d+)\t") {
        $id = $matches[1]
        if (-not $idsUtilitzats.ContainsKey($id)) {
            $idsUtilitzats[$id] = 0
        }
        $idsUtilitzats[$id]++
    }
}

$idsOrdenats = $idsUtilitzats.Keys | Sort-Object { [int]$_ }
foreach ($id in $idsOrdenats) {
    if ([int]$id -le 34) {
        Write-Host "ID $id`: $($idsUtilitzats[$id]) registres (exsoci)"
    }
}
Write-Host "============================="