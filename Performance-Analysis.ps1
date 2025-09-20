param(
    [ValidateSet('local', 'cloud', 'both')]
    [string]$Target = 'local',
    [switch]$Detailed,
    [switch]$Suggestions,
    [switch]$ExportReport
)

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Test-DatabaseConnection {
    param([string]$ConnectionString, [string]$Name)
    
    try {
        psql $ConnectionString -c "SELECT 1;" -t 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ ${Name}: Connexió OK" "Green"
            return $true
        } else {
            Write-ColorOutput "❌ ${Name}: Error de connexió" "Red"
            return $false
        }
    } catch {
        Write-ColorOutput "❌ ${Name}: $($_.Exception.Message)" "Red"
        return $false
    }
}

function Get-DatabaseSize {
    param([string]$ConnectionString, [string]$DatabaseName)
    
    Write-ColorOutput "`n📊 === Mida de la Base de Dades - $DatabaseName ===" "Cyan"
    
    $sizeQuery = @"
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as table_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as data_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) as index_size
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
"@
    
    try {
        $result = psql $ConnectionString -c $sizeQuery -t 2>$null
        if ($LASTEXITCODE -eq 0 -and $result) {
            Write-ColorOutput "📈 Mida per taula (ordenat per mida total):" "Yellow"
            $result | ForEach-Object {
                $parts = $_.Split('|')
                if ($parts.Length -ge 5) {
                    $table = $parts[1].Trim()
                    $totalSize = $parts[2].Trim()
                    $dataSize = $parts[3].Trim()
                    $indexSize = $parts[4].Trim()
                    Write-ColorOutput "  📋 $table" "White"
                    Write-ColorOutput "    Total: $totalSize | Dades: $dataSize | Índexs: $indexSize" "Gray"
                }
            }
        } else {
            Write-ColorOutput "⚠️  No es poden obtenir dades de mida" "Yellow"
        }
    } catch {
        Write-ColorOutput "❌ Error obtenint mides: $($_.Exception.Message)" "Red"
    }
}

function Get-IndexUsage {
    param([string]$ConnectionString, [string]$DatabaseName)
    
    Write-ColorOutput "`n🔍 === Ús d'Índexs - $DatabaseName ===" "Cyan"
    
    $indexQuery = @"
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan as scans,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched,
    CASE 
        WHEN idx_scan = 0 THEN '❌ No utilitzat'
        WHEN idx_scan < 100 THEN '⚠️  Poc utilitzat'
        WHEN idx_scan < 1000 THEN '✅ Ús moderat'
        ELSE '🔥 Molt utilitzat'
    END as usage_status
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;
"@
    
    try {
        $result = psql $ConnectionString -c $indexQuery -t 2>$null
        if ($LASTEXITCODE -eq 0 -and $result) {
            Write-ColorOutput "📊 Estadístiques d'índexs:" "Yellow"
            $result | ForEach-Object {
                $parts = $_.Split('|')
                if ($parts.Length -ge 7) {
                    $table = $parts[1].Trim()
                    $index = $parts[2].Trim()
                    $scans = $parts[3].Trim()
                    $status = $parts[6].Trim()
                    Write-ColorOutput "  $status $index ($table) - $scans scans" "White"
                }
            }
        } else {
            Write-ColorOutput "ℹ️  No hi ha estadístiques d'índexs disponibles" "Gray"
        }
    } catch {
        Write-ColorOutput "❌ Error obtenint índexs: $($_.Exception.Message)" "Red"
    }
}

function Get-QueryStats {
    param([string]$ConnectionString, [string]$DatabaseName)
    
    if (-not $Detailed) { return }
    
    Write-ColorOutput "`n⚡ === Estadístiques de Consultes - $DatabaseName ===" "Cyan"
    
    # Primer comprovem si pg_stat_statements està disponible
    $extensionQuery = "SELECT 1 FROM pg_extension WHERE extname = 'pg_stat_statements';"
    
    try {
        $hasExtension = psql $ConnectionString -c $extensionQuery -t 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $hasExtension) {
            Write-ColorOutput "ℹ️  Extensió pg_stat_statements no disponible" "Gray"
            Write-ColorOutput "   (Normal en entorns de desenvolupament local)" "Gray"
            return
        }
        
        $queryStatsQuery = @"
SELECT 
    LEFT(query, 60) as query_snippet,
    calls,
    total_time::numeric(10,2) as total_time_ms,
    mean_time::numeric(10,2) as avg_time_ms,
    CASE 
        WHEN mean_time > 1000 THEN '🔴 Lent'
        WHEN mean_time > 100 THEN '🟡 Moderat'
        ELSE '🟢 Ràpid'
    END as performance
FROM pg_stat_statements 
WHERE query NOT LIKE '%pg_stat_statements%'
ORDER BY total_time DESC 
LIMIT 10;
"@
        
        $result = psql $ConnectionString -c $queryStatsQuery -t 2>$null
        if ($LASTEXITCODE -eq 0 -and $result) {
            Write-ColorOutput "🏃 Top 10 consultes per temps total:" "Yellow"
            $result | ForEach-Object {
                $parts = $_.Split('|')
                if ($parts.Length -ge 5) {
                    $query = $parts[0].Trim()
                    $calls = $parts[1].Trim()
                    $totalTime = $parts[2].Trim()
                    $avgTime = $parts[3].Trim()
                    $performance = $parts[4].Trim()
                    Write-ColorOutput "  $performance $query..." "White"
                    Write-ColorOutput "    Crides: $calls | Temps total: ${totalTime}ms | Mitjana: ${avgTime}ms" "Gray"
                }
            }
        }
    } catch {
        Write-ColorOutput "❌ Error obtenint stats de consultes: $($_.Exception.Message)" "Red"
    }
}

function Get-TableStats {
    param([string]$ConnectionString, [string]$DatabaseName)
    
    Write-ColorOutput "`n📈 === Estadístiques de Taules - $DatabaseName ===" "Cyan"
    
    $tableStatsQuery = @"
SELECT 
    schemaname,
    tablename,
    n_tup_ins as inserts,
    n_tup_upd as updates,
    n_tup_del as deletes,
    n_tup_hot_upd as hot_updates,
    seq_scan as sequential_scans,
    idx_scan as index_scans,
    CASE 
        WHEN idx_scan = 0 AND seq_scan > 0 THEN '⚠️  Només sequential scans'
        WHEN idx_scan > seq_scan THEN '✅ Bon ús d''índexs'
        WHEN seq_scan > idx_scan THEN '🟡 Molts sequential scans'
        ELSE '📊 Estadístiques limitades'
    END as scan_analysis
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY (n_tup_ins + n_tup_upd + n_tup_del) DESC;
"@
    
    try {
        $result = psql $ConnectionString -c $tableStatsQuery -t 2>$null
        if ($LASTEXITCODE -eq 0 -and $result) {
            Write-ColorOutput "📊 Activitat per taula:" "Yellow"
            $result | ForEach-Object {
                $parts = $_.Split('|')
                if ($parts.Length -ge 9) {
                    $table = $parts[1].Trim()
                    $inserts = $parts[2].Trim()
                    $updates = $parts[3].Trim()
                    $deletes = $parts[4].Trim()
                    $seqScans = $parts[6].Trim()
                    $idxScans = $parts[7].Trim()
                    $analysis = $parts[8].Trim()
                    
                    Write-ColorOutput "  📋 $table" "White"
                    Write-ColorOutput "    Ops: +$inserts ~$updates -$deletes | Scans: seq=$seqScans idx=$idxScans" "Gray"
                    Write-ColorOutput "    $analysis" "Gray"
                }
            }
        } else {
            Write-ColorOutput "ℹ️  No hi ha estadístiques de taules disponibles" "Gray"
        }
    } catch {
        Write-ColorOutput "❌ Error obtenint stats de taules: $($_.Exception.Message)" "Red"
    }
}

function Get-PerformanceSuggestions {
    param([string]$ConnectionString, [string]$DatabaseName)
    
    if (-not $Suggestions) { return }
    
    Write-ColorOutput "`n💡 === Suggeriments de Performance - $DatabaseName ===" "Yellow"
    
    # Buscar taules sense primary key
    $noPkQuery = @"
SELECT t.table_name
FROM information_schema.tables t
LEFT JOIN information_schema.table_constraints tc 
    ON t.table_name = tc.table_name 
    AND tc.constraint_type = 'PRIMARY KEY'
WHERE t.table_schema = 'public' 
    AND t.table_type = 'BASE TABLE'
    AND tc.table_name IS NULL;
"@
    
    try {
        $noPkResult = psql $ConnectionString -c $noPkQuery -t 2>$null
        if ($LASTEXITCODE -eq 0 -and $noPkResult) {
            Write-ColorOutput "⚠️  Taules sense PRIMARY KEY:" "Red"
            $noPkResult | ForEach-Object {
                Write-ColorOutput "  • $($_.Trim())" "White"
            }
            Write-ColorOutput "  💡 Considera afegir PRIMARY KEYs per millorar el rendiment" "Yellow"
        }
    } catch {
        # Silenci errors, és només informatiu
    }
    
    # Buscar columnes que podrien necessitar índexs
    Write-ColorOutput "`n🎯 Recomanacions generals:" "Yellow"
    Write-ColorOutput "✅ Revisa consultes que utilitzen WHERE, JOIN, ORDER BY" "White"
    Write-ColorOutput "✅ Considera índexs compostos per consultes complexes" "White"
    Write-ColorOutput "✅ Utilitza EXPLAIN ANALYZE per identificar colls d'ampolla" "White"
    Write-ColorOutput "✅ Configura conexions pool per aplicacions de producció" "White"
    Write-ColorOutput "✅ Monitoritza l'ús de memòria i disc regularment" "White"
}

function New-PerformanceReport {
    param([string]$ReportContent)
    
    if (-not $ExportReport) { return }
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $reportFile = "performance_report_$timestamp.md"
    
    $reportHeader = @"
# Informe de Performance - Campionat 3 Bandes
**Data:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Generat per:** $env:USERNAME

## Resum Executiu

Aquest informe conté una anàlisi completa del rendiment de la base de dades del projecte Campionat 3 Bandes.

## Anàlisi de Performance

"@
    
    $reportHeader + $ReportContent | Out-File -FilePath $reportFile -Encoding UTF8
    Write-ColorOutput "📄 Informe generat: $reportFile" "Green"
}

# Main execution
Write-ColorOutput "⚡ Anàlisi de Performance - Campionat 3 Bandes" "Magenta"
Write-ColorOutput "=============================================" "Magenta"

$reportContent = ""

if ($Target -eq 'local' -or $Target -eq 'both') {
    $localConnection = "postgresql://postgres:postgres@127.0.0.1:54322/postgres"
    if (Test-DatabaseConnection -ConnectionString $localConnection -Name "Base de dades LOCAL") {
        Get-DatabaseSize -ConnectionString $localConnection -DatabaseName "LOCAL"
        Get-IndexUsage -ConnectionString $localConnection -DatabaseName "LOCAL"
        Get-QueryStats -ConnectionString $localConnection -DatabaseName "LOCAL"
        Get-TableStats -ConnectionString $localConnection -DatabaseName "LOCAL"
        Get-PerformanceSuggestions -ConnectionString $localConnection -DatabaseName "LOCAL"
    }
}

if ($Target -eq 'cloud' -or $Target -eq 'both') {
    if ($env:SUPABASE_DB_URL) {
        if (Test-DatabaseConnection -ConnectionString $env:SUPABASE_DB_URL -Name "Base de dades CLOUD") {
            Get-DatabaseSize -ConnectionString $env:SUPABASE_DB_URL -DatabaseName "CLOUD"
            Get-IndexUsage -ConnectionString $env:SUPABASE_DB_URL -DatabaseName "CLOUD"
            Get-QueryStats -ConnectionString $env:SUPABASE_DB_URL -DatabaseName "CLOUD"
            Get-TableStats -ConnectionString $env:SUPABASE_DB_URL -DatabaseName "CLOUD"
            Get-PerformanceSuggestions -ConnectionString $env:SUPABASE_DB_URL -DatabaseName "CLOUD"
        }
    } else {
        Write-ColorOutput "`n⚠️  Variable SUPABASE_DB_URL no configurada" "Yellow"
        Write-ColorOutput "Executa .\Configure-Supabase.ps1 primer" "White"
    }
}

Write-ColorOutput "`n🔧 Opcions adicionals:" "Cyan"
Write-ColorOutput "• Executa amb -Detailed per veure estadístiques de consultes" "White"
Write-ColorOutput "• Utilitza -Suggestions per obtenir recomanacions" "White"
Write-ColorOutput "• Especifica -ExportReport per generar un informe markdown" "White"
Write-ColorOutput "• Utilitza -Target cloud per analitzar només Supabase Cloud" "White"

New-PerformanceReport -ReportContent $reportContent