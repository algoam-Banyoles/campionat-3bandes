# Apply-FixIncompareixencesClassificacions.ps1
# Script per aplicar la correcció de les regles d'incompareixences

param(
    [string]$SupabaseUrl = $env:SUPABASE_URL,
    [string]$SupabaseKey = $env:SUPABASE_SERVICE_ROLE_KEY
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Fix Incompareixences i Classificacions" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
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
Write-Host "Aquest script aplicarà la migració 20250130000007_fix_incompareixences_classificacions.sql" -ForegroundColor Yellow
Write-Host ""
Write-Host "Canvis que s'aplicaran:" -ForegroundColor Yellow
Write-Host "  - Actualitza funció registrar_incompareixenca" -ForegroundColor White
Write-Host "  - Jugador PRESENT: 0 caramboles, 0 entrades" -ForegroundColor White
Write-Host "  - Jugador ABSENT: 0 caramboles, max_entrades categoria" -ForegroundColor White
Write-Host ""

$confirm = Read-Host "Vols continuar? (S/N)"
if ($confirm -ne 'S' -and $confirm -ne 's') {
    Write-Host "Operació cancel·lada" -ForegroundColor Yellow
    exit 0
}

# Llegir el fitxer SQL
$migrationFile = Join-Path $PSScriptRoot "supabase\migrations\20250130000007_fix_incompareixences_classificacions.sql"

if (-not (Test-Path $migrationFile)) {
    Write-Host "ERROR: No s'ha trobat el fitxer de migració" -ForegroundColor Red
    Write-Host "Path esperat: $migrationFile" -ForegroundColor Red
    exit 1
}

Write-Host "Llegint fitxer de migració..." -ForegroundColor Cyan
$sqlContent = Get-Content $migrationFile -Raw

# Executar la migració via API REST
Write-Host "Executant migració..." -ForegroundColor Cyan

$headers = @{
    "apikey" = $SupabaseKey
    "Authorization" = "Bearer $SupabaseKey"
    "Content-Type" = "application/json"
}

$body = @{
    query = $sqlContent
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$SupabaseUrl/rest/v1/rpc/exec" -Method Post -Headers $headers -Body $body -ErrorAction Stop
    Write-Host "Migració aplicada amb èxit!" -ForegroundColor Green
    Write-Host ""
}
catch {
    # Si el endpoint exec no existeix, intentar amb l'editor SQL directament
    Write-Host "Intent alternatiu: executant SQL directament..." -ForegroundColor Yellow
    
    try {
        # Intentar executar via psql si està disponible
        if (Get-Command psql -ErrorAction SilentlyContinue) {
            Write-Host "Utilitzant psql per executar la migració..." -ForegroundColor Cyan
            
            # Necessitem la DATABASE_URL
            $dbUrl = $env:DATABASE_URL
            if (-not $dbUrl) {
                Write-Host "WARNING: DATABASE_URL no està definida" -ForegroundColor Yellow
                Write-Host "Per executar via psql, defineix: `$env:DATABASE_URL = 'postgresql://...' " -ForegroundColor Yellow
                throw "DATABASE_URL no disponible"
            }
            
            psql $dbUrl -f $migrationFile
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Migració aplicada amb èxit via psql!" -ForegroundColor Green
            }
            else {
                throw "Error executant psql"
            }
        }
        else {
            throw "psql no està disponible"
        }
    }
    catch {
        Write-Host ""
        Write-Host "No s'ha pogut aplicar la migració automàticament" -ForegroundColor Red
        Write-Host ""
        Write-Host "Per aplicar-la manualment:" -ForegroundColor Yellow
        Write-Host "1. Ves a https://supabase.com/dashboard" -ForegroundColor White
        Write-Host "2. Selecciona el teu projecte" -ForegroundColor White
        Write-Host "3. Ves a SQL Editor" -ForegroundColor White
        Write-Host "4. Copia el contingut de:" -ForegroundColor White
        Write-Host "   $migrationFile" -ForegroundColor Gray
        Write-Host "5. Enganxa'l a l'editor i executa'l (Run)" -ForegroundColor White
        Write-Host ""
        exit 1
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Verificació" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Per verificar que la migració s'ha aplicat correctament:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Registra una incompareixença de prova" -ForegroundColor White
Write-Host "2. Comprova les classificacions" -ForegroundColor White
Write-Host "3. Verifica que:" -ForegroundColor White
Write-Host "   - El jugador present manté la seva mitjana" -ForegroundColor Gray
Write-Host "   - El jugador absent té mitjana molt baixa" -ForegroundColor Gray
Write-Host "   - Els punts són correctes (2 vs 0)" -ForegroundColor Gray
Write-Host ""
Write-Host "Consulta RESUM_FIX_INCOMPAREIXENCES.md per més informació" -ForegroundColor Cyan
Write-Host ""
