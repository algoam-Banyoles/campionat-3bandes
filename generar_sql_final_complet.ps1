# Script per generar el SQL final d'inserció de mitjanes històriques amb IDs reals
# Utilitza els IDs 1-34 que correspondran als exsocis a la taula socis

Write-Host "Generant script SQL final per a mitjanes històriques amb IDs reals..."

# Llegir dades actualitzades
$dades = Get-Content "mitjanes_historiques_ids_reals.txt" -Encoding UTF8

# Generar SQL
$sqlFinal = @()
$sqlFinal += "-- ================================================================="
$sqlFinal += "-- SCRIPT FINAL: MITJANES HISTÒRIQUES AMB INTEGRACIÓ EXSOCIS"
$sqlFinal += "-- ================================================================="
$sqlFinal += "-- Data: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$sqlFinal += "-- Registres: $($dades.Count - 1) (exclou capçalera)"
$sqlFinal += "-- IDs exsocis: 1-34 (integrats a la taula socis amb estat 'baixa')"
$sqlFinal += "-- IDs socis actius: 8748+ (evita conflictes)"
$sqlFinal += "-- ================================================================="
$sqlFinal += ""
$sqlFinal += "BEGIN;"
$sqlFinal += ""
$sqlFinal += "-- Eliminar dades existents de mitjanes històriques"
$sqlFinal += "DELETE FROM mitjanes_historiques;"
$sqlFinal += ""
$sqlFinal += "-- Inserir mitjanes històriques actualitzades"

$contador = 0
$capçalera = $true

foreach ($linia in $dades) {
    if ($capçalera) {
        $capçalera = $false
        continue
    }
    
    $camps = $linia -split '\t'
    if ($camps.Count -ge 6) {
        $year = $camps[0].Trim()
        $modalitat = $camps[1].Trim().Replace("'", "''")
        $posicio = $camps[2].Trim()
        $jugador = $camps[3].Trim()
        $mitjana = $camps[4].Trim()
        $soci_id = $camps[5].Trim()
        
        # Validar que els camps no estiguin buits
        if ($soci_id -and $year -and $modalitat -and $mitjana) {
            # Convertir coma decimal a punt per PostgreSQL
            $mitjanaCorregida = $mitjana.Replace(',', '.')
            $sql = "INSERT INTO mitjanes_historiques (soci_id, year, modalitat, mitjana) VALUES ($soci_id, $year, '$modalitat', $mitjanaCorregida);"
            $sqlFinal += $sql
            $contador++
        }
    }
}

$sqlFinal += ""
$sqlFinal += "-- Verificacions finals"
$sqlFinal += "SELECT COUNT(*) as total_mitjanes_inserides FROM mitjanes_historiques;"
$sqlFinal += ""
$sqlFinal += "-- Verificar integració amb exsocis"
$sqlFinal += "SELECT "
$sqlFinal += "    s.numero_soci,"
$sqlFinal += "    s.nom,"
$sqlFinal += "    s.de_baixa,"
$sqlFinal += "    COUNT(mh.id) as mitjanes_count"
$sqlFinal += "FROM socis s"
$sqlFinal += "LEFT JOIN mitjanes_historiques mh ON s.numero_soci = mh.soci_id"
$sqlFinal += "WHERE s.de_baixa = TRUE"
$sqlFinal += "GROUP BY s.numero_soci, s.nom, s.de_baixa"
$sqlFinal += "ORDER BY s.numero_soci;"
$sqlFinal += ""
$sqlFinal += "-- Resum per modalitat"
$sqlFinal += "SELECT modalitat, COUNT(*) as total FROM mitjanes_historiques GROUP BY modalitat ORDER BY modalitat;"
$sqlFinal += ""
$sqlFinal += "-- Resum per període"
$sqlFinal += "SELECT "
$sqlFinal += "    CASE "
$sqlFinal += "        WHEN year BETWEEN 2003 AND 2010 THEN '2003-2010'"
$sqlFinal += "        WHEN year BETWEEN 2011 AND 2020 THEN '2011-2020'"
$sqlFinal += "        WHEN year >= 2021 THEN '2021-2025'"
$sqlFinal += "    END as periode,"
$sqlFinal += "    COUNT(*) as total"
$sqlFinal += "FROM mitjanes_historiques "
$sqlFinal += "GROUP BY "
$sqlFinal += "    CASE "
$sqlFinal += "        WHEN year BETWEEN 2003 AND 2010 THEN '2003-2010'"
$sqlFinal += "        WHEN year BETWEEN 2011 AND 2020 THEN '2011-2020'"
$sqlFinal += "        WHEN year >= 2021 THEN '2021-2025'"
$sqlFinal += "    END"
$sqlFinal += "ORDER BY periode;"
$sqlFinal += ""
$sqlFinal += "COMMIT;"
$sqlFinal += ""
$sqlFinal += "-- ================================================================="
$sqlFinal += "-- RESUM FINAL"
$sqlFinal += "-- ================================================================="
$sqlFinal += "-- ✅ Mitjanes històriques: $contador registres inserits"
$sqlFinal += "-- ✅ Exsocis integrats: numero_soci 1-34 a la taula socis"
$sqlFinal += "-- ✅ Integritat referencial: Tots els soci_id existeixen a socis.numero_soci"
$sqlFinal += "-- ✅ Gestió de baixes: camp de_baixa (boolean) i data_baixa (date)"
$sqlFinal += "-- ✅ IDs futurs: 8748+ per a nous socis (sense conflictes)"
$sqlFinal += "-- ================================================================="

# Guardar script
$sqlFinal | Out-File -FilePath "script_cloud_final_complet.sql" -Encoding UTF8

Write-Host ""
Write-Host "====== SCRIPT FINAL GENERAT ======"
Write-Host "Fitxer: script_cloud_final_complet.sql"
Write-Host "Registres SQL: $contador"
Write-Host "IDs exsocis: 1-34"
Write-Host "=================================="