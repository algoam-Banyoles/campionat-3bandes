# Script per substituir Nosoci amb numeros 00XX per exsocis
# Evita problemes amb caracters especials

Write-Host "Processant fitxer mitjanes historiques..."

# Llegir fitxer original
$content = Get-Content "imtjanes.txt" -Encoding UTF8

# Comptadors
$substitucions = 0
$noTrobats = 0

# Processar linia per linia
$result = @()
foreach ($line in $content) {
    if ($line -match "Nosoci") {
        $parts = $line -split "`t"
        if ($parts.Length -ge 6) {
            $jugador = $parts[3]
            
            # Assignar numero segons el nom
            $nouNumero = ""
            switch ($jugador) {
                "A. ALUJA" { $nouNumero = "0001" }
                "A. FERNANDEZ" { $nouNumero = "0002" }
                { $_ -match "A\. FERN.*NDEZ" } { $nouNumero = "0002" }
                "A. MARTI" { $nouNumero = "0003" }
                { $_ -match "A\. MART.*" } { $nouNumero = "0003" }
                "ALBARRACIN" { $nouNumero = "0004" }
                "ALCARAZ" { $nouNumero = "0005" }
                "BARRIENTOS" { $nouNumero = "0006" }
                "BARRIERE" { $nouNumero = "0007" }
                "C. GIRO" { $nouNumero = "0008" }
                { $_ -match "C\. GIR.*" } { $nouNumero = "0008" }
                "CASBAS" { $nouNumero = "0009" }
                "DOMENECH" { $nouNumero = "0010" }
                { $_ -match "DOM.*NECH" } { $nouNumero = "0010" }
                "DONADEU" { $nouNumero = "0011" }
                "DURAN" { $nouNumero = "0012" }
                "E. GIRO" { $nouNumero = "0013" }
                { $_ -match "E\. GIR.*" } { $nouNumero = "0013" }
                "E. LLORENTE" { $nouNumero = "0014" }
                "ERRA" { $nouNumero = "0015" }
                "J. LAHOZ" { $nouNumero = "0016" }
                "J. ROVIROSA" { $nouNumero = "0017" }
                "JUAN  GOMEZ" { $nouNumero = "0018" }
                { $_ -match "JUAN.*G.*MEZ" } { $nouNumero = "0018" }
                "M. ALMIRALL" { $nouNumero = "0019" }
                "M. PALAU" { $nouNumero = "0020" }
                "M. PRAT" { $nouNumero = "0021" }
                "MAGRINA" { $nouNumero = "0022" }
                { $_ -match "MAGRI.*A" } { $nouNumero = "0022" }
                "P. RUIZ" { $nouNumero = "0023" }
                "PENA" { $nouNumero = "0024" }
                { $_ -match "PE.*A" } { $nouNumero = "0024" }
                "PUIG" { $nouNumero = "0025" }
                "REAL" { $nouNumero = "0026" }
                "RODRIGUEZ" { $nouNumero = "0027" }
                { $_ -match "RODR.*GUEZ" } { $nouNumero = "0027" }
                "S. BASCON" { $nouNumero = "0028" }
                { $_ -match "S\. BASC.*N" } { $nouNumero = "0028" }
                "SOLANES" { $nouNumero = "0029" }
                "SOLANS" { $nouNumero = "0030" }
                "SUNE" { $nouNumero = "0031" }
                { $_ -match "SU.*E" } { $nouNumero = "0031" }
                "TABERNER" { $nouNumero = "0032" }
                "TALAVERA" { $nouNumero = "0033" }
                "VIVAS" { $nouNumero = "0034" }
                default { 
                    Write-Warning "No assignat: '$jugador'"
                    $noTrobats++
                }
            }
            
            if ($nouNumero -ne "") {
                # Substituir
                $novaLinia = "$($parts[0])`t$($parts[1])`t$($parts[2])`t$($parts[3])`t$($parts[4])`t$nouNumero"
                $result += $novaLinia
                $substitucions++
                Write-Host "  $jugador -> $nouNumero"
            } else {
                $result += $line
            }
        } else {
            $result += $line
        }
    } else {
        $result += $line
    }
}

# Guardar resultat
$result | Out-File -FilePath "mitjanes_historiques_final.txt" -Encoding UTF8

Write-Host ""
Write-Host "====== RESUM ======"
Write-Host "Fitxer generat: mitjanes_historiques_final.txt"
Write-Host "Total linies: $($result.Count)" 
Write-Host "Substitucions: $substitucions"
Write-Host "No trobats: $noTrobats"
Write-Host "=================="