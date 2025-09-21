# Script per substituir "Nosoci" amb els nous números de soci
# Processa el fitxer imtjanes.txt i genera mitjanes_historiques_processades.txt

# Llegir el fitxer d'assignacions
$assignacions = @{}
Get-Content "assignacio_nous_socis.txt" | Where-Object { $_ -match " -> " } | ForEach-Object {
    $parts = $_ -split " -> "
    $nom = $parts[0].Trim()
    $soci = $parts[1].Trim()
    $assignacions[$nom] = $soci
}

Write-Host "Assignacions carregades: $($assignacions.Count)"

# Processar el fitxer principal
$outputFile = "mitjanes_historiques_processades.txt"
$processedLines = @()

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
                Write-Host "Substituït: $jugador -> $nouIdSoci"
            } else {
                Write-Warning "No s'ha trobat assignació per: $jugador"
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
Write-Host "Fitxer processat generat: $outputFile"
Write-Host "Total línies processades: $($processedLines.Count)"