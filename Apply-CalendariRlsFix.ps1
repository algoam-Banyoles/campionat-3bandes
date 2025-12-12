#!/usr/bin/env pwsh
# Apply the fixed RLS policies for calendari_partides

Write-Host ""
Write-Host "🔧 SOLUCIONANT PROBLEMA DE PERMISOS RLS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Problem: Error 'permission denied for table users'" -ForegroundColor Yellow
Write-Host "Solution: Create helper function to check admin status" -ForegroundColor Green
Write-Host ""

# Load .env
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]*?)\s*=\s*(.*?)\s*$') {
            Set-Item -Path "env:$($matches[1])" -Value $matches[2]
        }
    }
}

if (-not $env:SUPABASE_DB_URL) {
    Write-Host "❌ SUPABASE_DB_URL no trobada a .env" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Variables d'entorn carregades" -ForegroundColor Green
Write-Host ""

# Check psql
$psqlCheck = Get-Command psql -ErrorAction SilentlyContinue
if (-not $psqlCheck) {
    Write-Host "❌ psql no disponible" -ForegroundColor Red
    Write-Host ""
    Write-Host "📋 SOLUCIÓ ALTERNATIVA:" -ForegroundColor Yellow
    Write-Host "1. Ves a https://supabase.com/dashboard" -ForegroundColor White
    Write-Host "2. Selecciona el projecte 'campionat-3bandes'" -ForegroundColor White
    Write-Host "3. SQL Editor → New Query" -ForegroundColor White
    Write-Host "4. Copia i enganxa el contingut de:" -ForegroundColor White
    Write-Host "   fix-calendari-rls-simple.sql" -ForegroundColor Cyan
    Write-Host "5. Executa la query (Run)" -ForegroundColor White
    Write-Host ""
    exit 1
}

Write-Host "✅ psql disponible" -ForegroundColor Green
Write-Host ""

# Prepare URL
$dbUrl = $env:SUPABASE_DB_URL -replace '\?.*$', ''
if ($env:SUPABASE_DB_URL -notmatch 'sslmode=') {
    $dbUrl += "?sslmode=require"
}

Write-Host "🔗 Aplicant fix..." -ForegroundColor Cyan
Write-Host ""

try {
    psql $dbUrl -f "fix-calendari-rls-simple.sql"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "✅ FIX APLICAT CORRECTAMENT!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "🎯 Pròxims passos:" -ForegroundColor Cyan
        Write-Host "  1. Recarrega la pàgina (F5)" -ForegroundColor White
        Write-Host "  2. Prova d'editar un resultat" -ForegroundColor White
        Write-Host "  3. Hauria de funcionar sense errors!" -ForegroundColor White
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "❌ Error aplicant el fix" -ForegroundColor Red
        Write-Host ""
        Write-Host "📋 Solució alternativa (Dashboard):" -ForegroundColor Yellow
        Write-Host "  1. Ves a https://supabase.com/dashboard" -ForegroundColor White
        Write-Host "  2. SQL Editor → copia fix-calendari-rls-simple.sql" -ForegroundColor White
        Write-Host ""
    }
} catch {
    Write-Host "❌ Excepció: $_" -ForegroundColor Red
}
