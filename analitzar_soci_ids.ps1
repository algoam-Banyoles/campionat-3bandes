# Script per extreure tots els soci_id únics de les mitjanes històriques
# Això ens ajudarà a identificar quins IDs necessitem a la taula socis

Write-Host "Extraient tots els soci_id únics de mitjanes històriques..."

# Llegir fitxer de dades
$dades = Get-Content "mitjanes_historiques_ids_reals.txt" -Encoding UTF8

# Extreure IDs únics (darrera columna)
$idsUnics = @()
$capçalera = $true

foreach ($linia in $dades) {
    if ($capçalera) {
        $capçalera = $false
        continue
    }
    
    $camps = $linia -split '\t'
    if ($camps.Count -ge 6) {
        $soci_id = $camps[5].Trim()
        if ($soci_id -and $soci_id -match '^\d+$') {
            $idsUnics += [int]$soci_id
        }
    }
}

# Ordenar i eliminar duplicats
$idsUnicsOrdenats = $idsUnics | Sort-Object -Unique

Write-Host ""
Write-Host "====== ANÀLISI IDs MITJANES HISTÒRIQUES ======"
Write-Host "Total IDs únics: $($idsUnicsOrdenats.Count)"
Write-Host "ID mínim: $($idsUnicsOrdenats[0])"
Write-Host "ID màxim: $($idsUnicsOrdenats[-1])"

# Separar per rangs
$exsocis = $idsUnicsOrdenats | Where-Object { $_ -le 34 }
$socisActius = $idsUnicsOrdenats | Where-Object { $_ -gt 34 }

Write-Host ""
Write-Host "=== DISTRIBUCIÓ PER RANGS ==="
Write-Host "Exsocis (1-34): $($exsocis.Count)"
Write-Host "Socis actius (35+): $($socisActius.Count)"

if ($exsocis.Count -gt 0) {
    Write-Host "IDs exsocis: $($exsocis -join ', ')"
}

Write-Host ""
Write-Host "=== SOCIS ACTIUS QUE NECESSITEN SER AFEGITS ==="
Write-Host "Total socis actius diferents: $($socisActius.Count)"
Write-Host "Rang: $($socisActius[0]) - $($socisActius[-1])"

# Guardar llista completa per anàlisi
$idsUnicsOrdenats | Out-File -FilePath "llista_tots_soci_ids.txt" -Encoding UTF8

Write-Host ""
Write-Host "Fitxer generat: llista_tots_soci_ids.txt"
Write-Host "=============================================="