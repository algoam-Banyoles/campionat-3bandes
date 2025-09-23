# Test simple de migració
Write-Host "Provant migració senzilla..." -ForegroundColor Yellow

# Verificar SUPABASE_DB_URL
if (-not $env:SUPABASE_DB_URL) {
    Write-Host "SUPABASE_DB_URL no definida. Establir manualment:" -ForegroundColor Red
    Write-Host '$env:SUPABASE_DB_URL="postgresql://postgres.qbldqtaqawnahuzlzsjs:Banyoles2026!@aws-1-eu-central-1.pooler.supabase.com:6543/Continu3B?sslmode=require"' -ForegroundColor Gray
    exit 1
}

Write-Host "Aplicant test migration..." -ForegroundColor Green
psql $env:SUPABASE_DB_URL -f "test-migration-007.sql"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Test migration OK" -ForegroundColor Green
} else {
    Write-Host "❌ Error en test migration" -ForegroundColor Red
}