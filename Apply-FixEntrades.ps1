# Apply-FixEntrades.ps1
# Script per aplicar la correcció del càlcul d'entrades en les classificacions

param(
    [string]$SupabaseUrl = $env:SUPABASE_URL,
    [string]$SupabaseKey = $env:SUPABASE_SERVICE_ROLE_KEY
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Fix Entrades en Classificacions" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "PROBLEMA:" -ForegroundColor Yellow
Write-Host "  Les entrades_totals no es calculaven correctament" -ForegroundColor White
Write-Host "  La funció usava cp.entrades en lloc de camps individuals" -ForegroundColor White
Write-Host ""

Write-Host "SOLUCIÓ:" -ForegroundColor Green
Write-Host "  Utilitzar entrades_jugador1/jugador2 per cada jugador" -ForegroundColor White
Write-Host "  Fallback a cp.entrades per compatibilitat" -ForegroundColor White
Write-Host ""

# Verificar variables d'entorn
if (-not $SupabaseUrl) {
    Write-Host "ERROR: SUPABASE_URL no està definida" -ForegroundColor Red
    Write-Host "Defineix-la amb: `$env:SUPABASE_URL = 'https://your-project.supabase.co'" -ForegroundColor Yellow
    exit 1
}

if (-not $SupabaseKey) {
    Write-Host "ERROR: SUPABASE_SERVICE_ROLE_KEY no està definida" -ForegroundColor Red
    Write-Host "Defineix-la amb: `$env:SUPABASE_SERVICE_ROLE_KEY = 'your-service-role-key'" -ForegroundColor Yellow
    exit 1
}

# Mostrar informació de connexió
Write-Host "Supabase URL: $SupabaseUrl" -ForegroundColor Gray
Write-Host ""

# Confirmar execució
Write-Host "Aquest script aplicarà la migració 20250130000008_fix_entrades_classifications.sql" -ForegroundColor Yellow
Write-Host ""

$confirm = Read-Host "Vols continuar? (S/N)"
if ($confirm -ne 'S' -and $confirm -ne 's') {
    Write-Host "Operació cancel·lada" -ForegroundColor Yellow
    exit 0
}

# Llegir el fitxer SQL
$migrationFile = Join-Path $PSScriptRoot "supabase\migrations\20250130000008_fix_entrades_classifications.sql"

if (-not (Test-Path $migrationFile)) {
    Write-Host "ERROR: No s'ha trobat el fitxer de migració" -ForegroundColor Red
    Write-Host "Path esperat: $migrationFile" -ForegroundColor Red
    exit 1
}

Write-Host "Llegint fitxer de migració..." -ForegroundColor Cyan
$sqlContent = Get-Content $migrationFile -Raw

Write-Host "Executant migració..." -ForegroundColor Cyan

# Intentar executar via psql si està disponible
if (Get-Command psql -ErrorAction SilentlyContinue) {
    Write-Host "Utilitzant psql per executar la migració..." -ForegroundColor Cyan
    
    # Necessitem la DATABASE_URL
    $dbUrl = $env:DATABASE_URL
    if (-not $dbUrl) {
        Write-Host "WARNING: DATABASE_URL no està definida" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Per executar via psql, defineix: `$env:DATABASE_URL = 'postgresql://...' " -ForegroundColor Yellow
        Write-Host ""
        Write-Host "O aplica la migració manualment:" -ForegroundColor Yellow
        Write-Host "1. Ves a https://supabase.com/dashboard" -ForegroundColor White
        Write-Host "2. Selecciona el teu projecte" -ForegroundColor White
        Write-Host "3. Ves a SQL Editor" -ForegroundColor White
        Write-Host "4. Copia el contingut de:" -ForegroundColor White
        Write-Host "   $migrationFile" -ForegroundColor Gray
        Write-Host "5. Enganxa'l a l'editor i executa'l (Run)" -ForegroundColor White
        Write-Host ""
        exit 1
    }
    
    psql $dbUrl -f $migrationFile
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ Migració aplicada amb èxit!" -ForegroundColor Green
    }
    else {
        Write-Host ""
        Write-Host "❌ Error executant la migració" -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host ""
    Write-Host "psql no està disponible. Aplica la migració manualment:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Ves a https://supabase.com/dashboard" -ForegroundColor White
    Write-Host "2. Selecciona el teu projecte" -ForegroundColor White
    Write-Host "3. Ves a SQL Editor" -ForegroundColor White
    Write-Host "4. Copia el contingut de:" -ForegroundColor White
    Write-Host "   $migrationFile" -ForegroundColor Gray
    Write-Host "5. Enganxa'l a l'editor i executa'l (Run)" -ForegroundColor White
    Write-Host ""
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Verificació" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Per verificar que la migració funciona correctament:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Recarrega /campionats-socials?view=active" -ForegroundColor White
Write-Host "2. Ves a la pestanya 📊 Classificació" -ForegroundColor White
Write-Host "3. Comprova que:" -ForegroundColor White
Write-Host "   - Les entrades totals són correctes" -ForegroundColor Gray
Write-Host "   - Les mitjanes són coherents" -ForegroundColor Gray
Write-Host "   - Jugadors amb incompareixença (presentscompten) tenen 0 entrades" -ForegroundColor Gray
Write-Host ""
Write-Host "Consulta FIX_ENTRADES_CLASSIFICATIONS.md per més informació" -ForegroundColor Cyan
Write-Host ""
