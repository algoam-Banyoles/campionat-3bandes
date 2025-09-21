# Script millorat per substituir "Nosoci" amb números de soci
# Gestiona millor els caràcters especials i casos especials
# NOTA: Els números de soci per exsocis comencen amb 00 per evitar conflictes futurs

# Mapping manual de les assignacions (00XX per exsocis no identificats)
$assignacions = @{
    "A. ALUJA" = "0001"
    "A. FERNÁNDEZ" = "0002" 
    "A. MARTÍ" = "0003"
    "ALBARRACIN" = "0004"
    "ALCARAZ" = "0005"
    "BARRIENTOS" = "0006"
    "BARRIERE" = "0007"
    "C. GIRÓ" = "0008"
    "CASBAS" = "0009"
    "DOMÉNECH" = "0010"
    "DONADEU" = "0011"
    "DURAN" = "0012"
    "E. GIRÓ" = "0013"
    "E. LLORENTE" = "0014"
    "ERRA" = "0015"
    "J. LAHOZ" = "0016"
    "J. ROVIROSA" = "0017"
    "JUAN  GÓMEZ" = "0018"
    "M. ALMIRALL" = "0019"
    "M. PALAU" = "0020"
    "M. PRAT" = "0021"
    "MAGRIÑA" = "0022"
    "P. RUIZ" = "0023"
    "PEÑA" = "0024"
    "PUIG" = "0025"
    "REAL" = "0026"
    "RODRÍGUEZ" = "0027"
    "S. BASCÓN" = "0028"
    "SOLANES" = "0029"
    "SOLANS" = "0030"
    "SUÑE" = "0031"
    "SUÑÉ" = "0031"
    "TABERNER" = "0032"
    "TALAVERA" = "0033"
    "VIVAS" = "0034"
}

Write-Host "Assignacions carregades: $($assignacions.Count)"

# Processar el fitxer principal
$outputFile = "mitjanes_historiques_final.txt"
$processedLines = @()
$substitucions = 0

Get-Content "imtjanes.txt" -Encoding UTF8 | ForEach-Object {
    $line = $_
    if ($line -match "Nosoci") {
        # Extreure les parts de la línia
        $parts = $line -split "`t"
        if ($parts.Length -ge 6) {
            $any = $parts[0]
            $modalitat = $parts[1]
            $posicio = $parts[2]
            $jugador = $parts[3]
            $mitjana = $parts[4]
            $idSoci = $parts[5]
            
            # Substituir "Nosoci" amb el número assignat
            if ($assignacions.ContainsKey($jugador)) {
                $nouIdSoci = $assignacions[$jugador]
                $novaLinia = "$any`t$modalitat`t$posicio`t$jugador`t$mitjana`t$nouIdSoci"
                $processedLines += $novaLinia
                $substitucions++
                Write-Host "✓ $jugador -> $nouIdSoci"
            } else {
                Write-Warning "⚠ No trobat: '$jugador'"
                $processedLines += $line
            }
        } else {
            $processedLines += $line
        }
    } else {
        $processedLines += $line
    }
}

# Escriure el fitxer processat
$processedLines | Out-File -FilePath $outputFile -Encoding UTF8
Write-Host ""
Write-Host "====== RESUM ======"
Write-Host "Fitxer generat: $outputFile"
Write-Host "Total línies: $($processedLines.Count)" 
Write-Host "Substitucions: $substitucions"
Write-Host "=================="