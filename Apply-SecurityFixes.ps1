# ============================================
# Apply Security Fixes to Supabase Database
# ============================================
# This script fixes the "Function Search Path Mutable" warnings
# by adding SET search_path = public to all affected functions
# ============================================

Write-Host "`n🔒 APLICANT CORRECCIONS DE SEGURETAT" -ForegroundColor Cyan
Write-Host "====================================`n" -ForegroundColor Cyan

# Check if .env file exists
if (-not (Test-Path ".env")) {
    Write-Host "❌ Error: No s'ha trobat el fitxer .env" -ForegroundColor Red
    Write-Host "   Crea un fitxer .env amb SUPABASE_DB_URL definit" -ForegroundColor Yellow
    Write-Host "   Consulta SUPABASE_CONNECTION.md per més informació`n" -ForegroundColor Gray
    exit 1
}

# Load environment variables from .env
Write-Host "📄 Carregant variables d'entorn..." -ForegroundColor Gray
Get-Content ".env" | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]*)\s*=\s*(.*)$') {
        $name = $matches[1].Trim()
        $value = $matches[2].Trim().Trim('"').Trim("'")
        Set-Item -Path "env:$name" -Value $value
    }
}

$DB_URL = $env:SUPABASE_DB_URL

if (-not $DB_URL) {
    Write-Host "`n❌ Error: SUPABASE_DB_URL no està definit al fitxer .env" -ForegroundColor Red
    Write-Host "   Afegeix la línia al fitxer .env:" -ForegroundColor Yellow
    Write-Host "   SUPABASE_DB_URL=postgresql://postgres.xxxxx:[PASSWORD]@aws-0-eu-central-1.pooler.supabase.com:6543/postgres" -ForegroundColor Gray
    Write-Host "`n   Consulta SUPABASE_CONNECTION.md per més detalls`n" -ForegroundColor Gray
    exit 1
}

# Verify psql is installed
$psqlVersion = psql --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n❌ Error: psql no està instal·lat o no està al PATH" -ForegroundColor Red
    Write-Host "   Instal·la PostgreSQL client tools:" -ForegroundColor Yellow
    Write-Host "   choco install postgresql`n" -ForegroundColor Gray
    exit 1
}

Write-Host "✅ Variables carregades correctament" -ForegroundColor Green
Write-Host "✅ psql trobat: $psqlVersion" -ForegroundColor Green

Write-Host "✅ Variables d'entorn carregades" -ForegroundColor Green
Write-Host "📄 Aplicant: supabase/sql/fix_security_warnings.sql`n" -ForegroundColor Cyan

# Apply the SQL file
try {
    $sqlContent = Get-Content "supabase/sql/fix_security_warnings.sql" -Raw
    
    # Use psql to execute the SQL
    $sqlContent | psql $DB_URL
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✅ CORRECCIONS APLICADES CORRECTAMENT!" -ForegroundColor Green
        Write-Host "`n📋 Funcions actualitzades:" -ForegroundColor Cyan
        Write-Host "   • get_social_league_classifications" -ForegroundColor White
        Write-Host "   • get_head_to_head_results" -ForegroundColor White
        Write-Host "   • get_retired_players" -ForegroundColor White
        Write-Host "   • reactivate_player_in_league" -ForegroundColor White
        Write-Host "   • retire_player_from_league" -ForegroundColor White
        Write-Host "   • update_page_content_updated_at" -ForegroundColor White
        Write-Host "   • registrar_incompareixenca" -ForegroundColor White
        Write-Host "`n🔒 Totes les funcions ara tenen 'SET search_path = public'" -ForegroundColor Green
        Write-Host "   Això prevé atacs d'injecció de schema`n" -ForegroundColor Gray
        
        Write-Host "ℹ️  NOTA: Els altres warnings requereixen accions diferents:" -ForegroundColor Yellow
        Write-Host "   • Leaked Password Protection: Activa-ho al dashboard de Supabase" -ForegroundColor Gray
        Write-Host "     Dashboard > Authentication > Policies > Password" -ForegroundColor Gray
        Write-Host "   • Postgres Version: Actualitza la BD al dashboard de Supabase" -ForegroundColor Gray
        Write-Host "     Dashboard > Settings > Infrastructure > Upgrade`n" -ForegroundColor Gray
    } else {
        Write-Host "`n❌ Error aplicant les correccions" -ForegroundColor Red
        Write-Host "   Revisa els errors anteriors`n" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host "`n❌ Error: $_" -ForegroundColor Red
    exit 1
}
