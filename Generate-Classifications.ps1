# Script per generar classificacions finals d'un campionat
# Usage: .\Generate-Classifications.ps1 -EventId "event-uuid"

param(
    [Parameter(Mandatory=$false)]
    [string]$EventId = "8a81a82e-96c9-4c49-9fbe-b492394462ac",  # Campionat Social 3 Bandes 2025-2026
    
    [Parameter(Mandatory=$false)]
    [switch]$ApplyMigration = $false
)

$ErrorActionPreference = "Stop"

# Configuració Supabase
$supabaseUrl = "https://qbldqtaqawnahuzlzsjs.supabase.co"
$serviceKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFibGRxdGFxYXduYWh1emx6c2pzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NzA1OTIwOCwiZXhwIjoyMDcyNjM1MjA4fQ.-tP6NsvVa6vMFcYXRbXjqQsKC-rm5DxUYi6MzJuiAVI"

$headers = @{
    "apikey" = $serviceKey
    "Authorization" = "Bearer $serviceKey"
    "Content-Type" = "application/json"
}

Write-Host "🏆 Generador de Classificacions Finals" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Aplicar migració si es demana
if ($ApplyMigration) {
    Write-Host "📦 Aplicant migració..." -ForegroundColor Yellow
    
    $migrationPath = Join-Path $PSScriptRoot "supabase\migrations\20250211000001_generate_final_classifications.sql"
    
    if (Test-Path $migrationPath) {
        $migrationSql = Get-Content $migrationPath -Raw
        
        try {
            $body = @{
                query = $migrationSql
            } | ConvertTo-Json
            
            $result = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/rpc/exec_sql" -Method Post -Headers $headers -Body $body -ErrorAction Stop
            Write-Host "✅ Migració aplicada correctament" -ForegroundColor Green
        } catch {
            Write-Host "⚠️  Nota: No s'ha pogut aplicar la migració automàticament" -ForegroundColor Yellow
            Write-Host "   Aplica manualment el fitxer: $migrationPath" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ No s'ha trobat el fitxer de migració" -ForegroundColor Red
        exit 1
    }
    Write-Host ""
}

# Obtenir informació de l'event
Write-Host "🔍 Obtenint informació de l'event..." -ForegroundColor Yellow
try {
    $eventResponse = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/events?id=eq.$EventId&select=id,nom,temporada,estat_competicio,tipus_competicio" -Headers $headers
    
    if ($eventResponse.Count -eq 0) {
        Write-Host "❌ Event no trobat: $EventId" -ForegroundColor Red
        exit 1
    }
    
    $event = $eventResponse[0]
    Write-Host "   📋 Event: $($event.nom)" -ForegroundColor White
    Write-Host "   📅 Temporada: $($event.temporada)" -ForegroundColor White
    Write-Host "   🔄 Estat: $($event.estat_competicio)" -ForegroundColor White
    Write-Host ""
} catch {
    Write-Host "❌ Error obtenint informació de l'event: $_" -ForegroundColor Red
    exit 1
}

# Comprovar partides jugades
Write-Host "🎱 Comprovant partides jugades..." -ForegroundColor Yellow
try {
    $partidesResponse = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/calendari_partides?event_id=eq.$EventId&select=id,estat" -Headers $headers
    
    $totalPartides = $partidesResponse.Count
    $partidesValidades = ($partidesResponse | Where-Object { $_.estat -eq 'validat' }).Count
    $partidesCancellades = ($partidesResponse | Where-Object { $_.estat -eq 'cancel·lada_per_retirada' }).Count
    
    Write-Host "   📊 Total partides: $totalPartides" -ForegroundColor White
    Write-Host "   ✅ Validades: $partidesValidades" -ForegroundColor Green
    Write-Host "   ❌ Cancel·lades: $partidesCancellades" -ForegroundColor Red
    Write-Host ""
    
    if ($partidesValidades -eq 0) {
        Write-Host "⚠️  No hi ha partides validades. No es poden generar classificacions." -ForegroundColor Yellow
        exit 0
    }
} catch {
    Write-Host "❌ Error comprovant partides: $_" -ForegroundColor Red
    exit 1
}

# Generar classificacions
Write-Host "🏆 Generant classificacions finals..." -ForegroundColor Yellow
try {
    $body = @{
        p_event_id = $EventId
    } | ConvertTo-Json
    
    $result = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/rpc/generate_final_classifications" -Method Post -Headers $headers -Body $body
    
    if ($result[0].success) {
        Write-Host "✅ $($result[0].message)" -ForegroundColor Green
        Write-Host "   📈 Classificats: $($result[0].classifications_count)" -ForegroundColor White
    } else {
        Write-Host "❌ Error: $($result[0].message)" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Error generant classificacions: $_" -ForegroundColor Red
    Write-Host "   Detalls: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "🎉 Classificacions generades correctament!" -ForegroundColor Green
Write-Host ""
Write-Host "📊 Per veure les classificacions:" -ForegroundColor Cyan
Write-Host "   http://localhost:5173/campionats-socials/$EventId/classificacio" -ForegroundColor White
Write-Host ""
