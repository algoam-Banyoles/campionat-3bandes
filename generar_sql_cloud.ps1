# Script per generar SQL d'inserció per al cloud
# Processa el fitxer mitjanes_historiques_final.txt amb assignacions correctes

Write-Host "Generant script SQL per al cloud..."

# Llegir fitxer processat
$content = Get-Content "mitjanes_historiques_final.txt" -Encoding UTF8

# Filtrar només les línies de dades (saltar capçalera)
$dataLines = $content | Where-Object { $_ -notmatch "^Any\s+Modalitat" }

$sqlInserts = @()
$contador = 0

foreach ($line in $dataLines) {
    if ($line.Trim() -ne "" -and $line -match "\t") {
        $parts = $line -split "`t"
        if ($parts.Length -ge 6) {
            $any = $parts[0].Trim()
            $modalitat = $parts[1].Trim()
            $posicio = $parts[2].Trim()
            $jugador = $parts[3].Trim()
            $mitjana = $parts[4].Trim()
            $sociId = $parts[5].Trim()
            
            # Convertir modalitat a format normalitzat
            $modalitat = $modalitat.Replace("3 BANDES", "3 BANDES").Replace("BANDA", "BANDA").Replace("LLIURE", "LLIURE")
            
            # Escape cometes simples en el nom del jugador
            $jugadorEscaped = $jugador.Replace("'", "''")
            
            # Generar INSERT
            $sql = "INSERT INTO mitjanes_historiques (soci_id, year, modalitat, posicio, jugador, mitjana) VALUES ($sociId, $any, '$modalitat', $posicio, '$jugadorEscaped', $mitjana);"
            $sqlInserts += $sql
            $contador++
            
            if ($contador % 100 -eq 0) {
                Write-Host "Processats $contador registres..."
            }
        }
    }
}

# Crear script SQL complet
$scriptCompleto = @"
-- Script d'inserció de mitjanes històriques al cloud
-- Generat automàticament amb assignacions correctes de soci_id
-- Data: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
-- Total registres: $contador

BEGIN;

-- Eliminar dades existents per evitar duplicats
DELETE FROM mitjanes_historiques WHERE year BETWEEN 2003 AND 2025;

-- Inserir dades processades
$($sqlInserts -join "`n")

-- Verificar càrrega
SELECT 
    COUNT(*) as total_registres,
    MIN(year) as any_minim,
    MAX(year) as any_maxim,
    COUNT(DISTINCT modalitat) as modalitats,
    COUNT(DISTINCT soci_id) as socis_diferents
FROM mitjanes_historiques;

COMMIT;
"@

# Guardar script
$scriptCompleto | Out-File -FilePath "script_cloud_mitjanes_historiques.sql" -Encoding UTF8

Write-Host ""
Write-Host "====== SCRIPT SQL GENERAT ======"
Write-Host "Fitxer: script_cloud_mitjanes_historiques.sql"
Write-Host "Total INSERT statements: $contador"
Write-Host "Exsocis amb ID 00XX: $($sqlInserts | Where-Object { $_ -match "VALUES \(0\d" } | Measure-Object | Select-Object -ExpandProperty Count)"
Write-Host "================================="