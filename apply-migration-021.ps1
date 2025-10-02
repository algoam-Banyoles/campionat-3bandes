# Script per aplicar la migració 021 - Crear funció get_match_results_public
# Creat: 2025-10-02

Write-Host "🔧 Aplicant migració 021: Crear funció get_match_results_public" -ForegroundColor Cyan

# Verificar SUPABASE_DB_URL
if (-not $env:SUPABASE_DB_URL) {
    Write-Host "❌ Variable SUPABASE_DB_URL no trobada" -ForegroundColor Red
    Write-Host "Estableix-la amb:" -ForegroundColor Yellow
    Write-Host '$env:SUPABASE_DB_URL="postgresql://postgres.qbldqtaqawnahuzlzsjs:Banyoles2026!@aws-1-eu-central-1.pooler.supabase.com:6543/Continu3B?sslmode=require"' -ForegroundColor Gray
    exit 1
}

Write-Host "🔍 Verificant connexió a la base de dades..." -ForegroundColor Yellow
try {
    $testResult = psql $env:SUPABASE_DB_URL -c "SELECT version();" -t 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Connexió fallida"
    }
    Write-Host "✅ Connexió establerta correctament" -ForegroundColor Green
} catch {
    Write-Host "❌ Error de connexió a la base de dades" -ForegroundColor Red
    exit 1
}

Write-Host "🔍 Verificant si la funció get_match_results_public ja existeix..." -ForegroundColor Yellow
$functionExists = psql $env:SUPABASE_DB_URL -c "SELECT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_match_results_public');" -t 2>$null
if ($functionExists -match "t") {
    Write-Host "⚠️  La funció get_match_results_public ja existeix" -ForegroundColor Yellow
    Write-Host "🔄 La recrearem per assegurar-nos que està actualitzada" -ForegroundColor Cyan
} else {
    Write-Host "📝 La funció get_match_results_public no existeix, la crearem" -ForegroundColor Cyan
}

Write-Host "📋 Aplicant migració 021..." -ForegroundColor Yellow
try {
    psql $env:SUPABASE_DB_URL -f "supabase\migrations\021_create_get_match_results_public.sql"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Migració 021 aplicada correctament!" -ForegroundColor Green
    } else {
        throw "Error aplicant migració"
    }
} catch {
    Write-Host "❌ Error aplicant la migració 021" -ForegroundColor Red
    exit 1
}

Write-Host "🧪 Verificant que la funció funciona..." -ForegroundColor Yellow
try {
    # Obtenir un event_id per provar
    $testEventId = psql $env:SUPABASE_DB_URL -c "SELECT id FROM events WHERE actiu = true LIMIT 1;" -t 2>$null
    $testEventId = $testEventId.Trim()
    
    if ($testEventId) {
        Write-Host "🔍 Provant la funció amb event_id: $testEventId" -ForegroundColor Cyan
        $testResult = psql $env:SUPABASE_DB_URL -c "SELECT COUNT(*) FROM get_match_results_public('$testEventId');" -t 2>$null
        Write-Host "✅ La funció retorna $($testResult.Trim()) resultats" -ForegroundColor Green
    } else {
        Write-Host "⚠️  No hi ha events actius per provar, però la funció s'ha creat" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Error provant la funció" -ForegroundColor Red
}

Write-Host "🎉 Migració 021 completada!" -ForegroundColor Green
Write-Host "✨ La funció get_match_results_public està disponible per l'aplicació" -ForegroundColor Cyan