# Script per aplicar Migració 019: Fix Security Definer Views
# Executa la migració i verifica que les vistes ja no tinguin SECURITY DEFINER

param(
    [switch]$Force,
    [switch]$TestOnly
)

Write-Host "=== MIGRACIÓ 019: FIX SECURITY DEFINER VIEWS ===" -ForegroundColor Green
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

# 2. Verificar estat actual de les vistes
Write-Host ""
Write-Host "2. Verificant estat actual de les vistes..." -ForegroundColor Yellow

$viewsWithDefiner = @()
$viewsToCheck = @("v_analisi_calendari", "v_promocions_candidates", "v_player_badges")

foreach ($view in $viewsToCheck) {
    # Check if view exists and has SECURITY DEFINER
    $definerCheck = psql $env:SUPABASE_DB_URL -c "SELECT COUNT(*) FROM pg_views WHERE viewname = '$view' AND definition LIKE '%SECURITY DEFINER%';" -t 2>$null
    $hasDefiner = $definerCheck.Trim()

    if ($hasDefiner -eq "1") {
        $viewsWithDefiner += $view
        Write-Host "⚠️  Vista '$view' té SECURITY DEFINER" -ForegroundColor Yellow
    } else {
        Write-Host "✅ Vista '$view' no té SECURITY DEFINER" -ForegroundColor Green
    }
}

if ($viewsWithDefiner.Count -eq 0 -and -not $Force) {
    Write-Host ""
    Write-Host "ℹ️  Totes les vistes ja compleixen amb les polítiques de seguretat" -ForegroundColor Cyan
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
    Write-Host "3. Aplicant migració 019..." -ForegroundColor Yellow

    try {
        psql $env:SUPABASE_DB_URL -f "supabase\migrations\019_fix_security_definer_views.sql"
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

# 4. Verificar que les vistes ja no tinguin SECURITY DEFINER
Write-Host ""
Write-Host "4. Verificant que les vistes ja no tinguin SECURITY DEFINER..." -ForegroundColor Yellow

$allViewsFixed = $true
foreach ($view in $viewsToCheck) {
    $definerCheck = psql $env:SUPABASE_DB_URL -c "SELECT COUNT(*) FROM pg_views WHERE viewname = '$view' AND definition LIKE '%SECURITY DEFINER%';" -t 2>$null
    $hasDefiner = $definerCheck.Trim()

    if ($hasDefiner -eq "0") {
        Write-Host "✅ Vista '$view' corregida (sense SECURITY DEFINER)" -ForegroundColor Green
    } else {
        Write-Host "❌ Vista '$view' encara té SECURITY DEFINER" -ForegroundColor Red
        $allViewsFixed = $false
    }
}

# 5. Verificar que les vistes existeixen i funcionen
Write-Host ""
Write-Host "5. Verificant que les vistes existeixen i funcionen..." -ForegroundColor Yellow

foreach ($view in $viewsToCheck) {
    $viewExists = psql $env:SUPABASE_DB_URL -c "SELECT EXISTS (SELECT 1 FROM information_schema.views WHERE table_name = '$view');" -t 2>$null
    if ($viewExists.Trim() -eq "t") {
        # Try to select from the view (basic functionality test)
        $canSelect = psql $env:SUPABASE_DB_URL -c "SELECT COUNT(*) FROM $view LIMIT 1;" -t 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Vista '$view' existeix i funciona" -ForegroundColor Green
        } else {
            Write-Host "❌ Vista '$view' existeix però no funciona" -ForegroundColor Red
            $allViewsFixed = $false
        }
    } else {
        Write-Host "❌ Vista '$view' NO trobada" -ForegroundColor Red
        $allViewsFixed = $false
    }
}

# 6. Resultat final
Write-Host ""
Write-Host "=== RESULTAT FINAL ===" -ForegroundColor Green

if ($allViewsFixed) {
    Write-Host "✅ Migració 019 completada exitosament" -ForegroundColor Green
    Write-Host ""
    Write-Host "Pròxims passos:" -ForegroundColor Cyan
    Write-Host "1. Executar 'supabase db lint' per verificar que els errors de seguretat han desaparegut" -ForegroundColor Gray
    Write-Host "2. Provar l'aplicació per assegurar que les vistes funcionen correctament" -ForegroundColor Gray
    Write-Host "3. Considerar aplicar les migracions 020 i 021 si hi ha més errors de lint" -ForegroundColor Gray
} else {
    Write-Host "❌ Problemes detectats en la migració" -ForegroundColor Red
    Write-Host "Revisa els errors anteriors i torna a executar amb -Force si cal" -ForegroundColor Gray
    exit 1
}

Write-Host ""