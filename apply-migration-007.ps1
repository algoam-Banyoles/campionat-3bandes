# Script per aplicar Migració 007: Campionats Socials
# Executa la migració i verifica l'estat de la base de dades

param(
    [switch]$Force,
    [switch]$TestOnly
)

Write-Host "=== MIGRACIÓ 007: CAMPIONATS SOCIALS ===" -ForegroundColor Green
Write-Host ""

# 1. Verificar connexió BD
Write-Host "1. Verificant connexió a la base de dades..." -ForegroundColor Yellow

if (-not $env:SUPABASE_DB_URL) {
    Write-Host "❌ Variable SUPABASE_DB_URL no trobada" -ForegroundColor Red
    Write-Host "Configurar amb: .\Configure-Supabase.ps1" -ForegroundColor Gray
    exit 1
}

# Test de connexió
try {
    $testResult = psql $env:SUPABASE_DB_URL -c "SELECT version();" -t 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Connexió exitosa" -ForegroundColor Green
    } else {
        throw "Error de connexió"
    }
} catch {
    Write-Host "❌ No es pot connectar a la base de dades" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}

# 2. Verificar si la migració ja s'ha aplicat
Write-Host ""
Write-Host "2. Verificant estat de la migració..." -ForegroundColor Yellow

$checkMigration = psql $env:SUPABASE_DB_URL -c "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'categories');" -t 2>$null
$migrationExists = $checkMigration.Trim()

if ($migrationExists -eq "t" -and -not $Force) {
    Write-Host "⚠️  La migració 007 sembla que ja s'ha aplicat (taula 'categories' existeix)" -ForegroundColor Yellow
    if (-not $TestOnly) {
        $confirm = Read-Host "Vols continuar igualment? (y/N)"
        if ($confirm -ne "y" -and $confirm -ne "Y") {
            Write-Host "Operació cancel·lada" -ForegroundColor Gray
            exit 0
        }
    }
}

# 3. Aplicar migració (si no és test-only)
if (-not $TestOnly) {
    Write-Host ""
    Write-Host "3. Aplicant migració 007..." -ForegroundColor Yellow

    try {
        psql $env:SUPABASE_DB_URL -f "supabase\migrations\007_lligues_socials.sql"
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Migració aplicada correctament" -ForegroundColor Green
        } else {
            throw "Error en aplicar migració"
        }
    } catch {
        Write-Host "❌ Error aplicant la migració" -ForegroundColor Red
        Write-Host "Error: $_" -ForegroundColor Red
        exit 1
    }
}

# 4. Verificar taules creades
Write-Host ""
Write-Host "4. Verificant taules creades..." -ForegroundColor Yellow

$expectedTables = @(
    "categories",
    "inscripcions",
    "configuracio_calendari",
    "calendari_partides",
    "classificacions"
)

$allTablesExist = $true
foreach ($table in $expectedTables) {
    $exists = psql $env:SUPABASE_DB_URL -c "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = '$table');" -t 2>$null
    if ($exists.Trim() -eq "t") {
        Write-Host "✅ Taula '$table' creada" -ForegroundColor Green
    } else {
        Write-Host "❌ Taula '$table' NO trobada" -ForegroundColor Red
        $allTablesExist = $false
    }
}

# 5. Verificar columnes afegides a events
Write-Host ""
Write-Host "5. Verificant columnes afegides a 'events'..." -ForegroundColor Yellow

$expectedColumns = @(
    "modalitat",
    "tipus_competicio",
    "estat_competicio",
    "data_inici",
    "data_fi"
)

foreach ($column in $expectedColumns) {
    $exists = psql $env:SUPABASE_DB_URL -c "SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'events' AND column_name = '$column');" -t 2>$null
    if ($exists.Trim() -eq "t") {
        Write-Host "✅ Columna 'events.$column' afegida" -ForegroundColor Green
    } else {
        Write-Host "❌ Columna 'events.$column' NO trobada" -ForegroundColor Red
        $allTablesExist = $false
    }
}

# 6. Verificar vista creada
Write-Host ""
Write-Host "6. Verificant vista 'v_analisi_calendari'..." -ForegroundColor Yellow

$viewExists = psql $env:SUPABASE_DB_URL -c "SELECT EXISTS (SELECT 1 FROM information_schema.views WHERE table_name = 'v_analisi_calendari');" -t 2>$null
if ($viewExists.Trim() -eq "t") {
    Write-Host "✅ Vista 'v_analisi_calendari' creada" -ForegroundColor Green
} else {
    Write-Host "❌ Vista 'v_analisi_calendari' NO trobada" -ForegroundColor Red
    $allTablesExist = $false
}

# 7. Resultat final
Write-Host ""
Write-Host "=== RESULTAT FINAL ===" -ForegroundColor Green

if ($allTablesExist) {
    Write-Host "✅ Migració 007 completada exitosament" -ForegroundColor Green
    Write-Host ""
    Write-Host "Pròxims passos:" -ForegroundColor Cyan
    Write-Host "1. Executar 'npm run dev' per provar la interfície" -ForegroundColor Gray
    Write-Host "2. Accedir com algoam@gmail.com per veure 'Campionats Socials [DEV]'" -ForegroundColor Gray
    Write-Host "3. Importar dades històriques Excel" -ForegroundColor Gray
} else {
    Write-Host "❌ Problemes detectats en la migració" -ForegroundColor Red
    Write-Host "Revisa els errors anteriors i torna a executar amb -Force si cal" -ForegroundColor Gray
    exit 1
}

Write-Host ""