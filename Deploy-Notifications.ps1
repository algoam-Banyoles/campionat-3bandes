# Script de desplegament del sistema de notificacions
# Deploy-Notifications.ps1

Write-Host "Desplegant sistema de notificacions..." -ForegroundColor Cyan

# Migrar base de dades
Write-Host "1. Executant migracions..." -ForegroundColor Yellow
supabase db push
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Error en les migracions" -ForegroundColor Red
    exit 1
}

# Desplegar Edge Functions
Write-Host "2. Desplegant Edge Functions..." -ForegroundColor Yellow
supabase functions deploy send-push-notification --no-verify-jwt
supabase functions deploy process-notification-queue --no-verify-jwt  
supabase functions deploy challenge-notifications --no-verify-jwt

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Error desplegant funcions" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Sistema de notificacions desplegat!" -ForegroundColor Green
Write-Host "No oblidis configurar les variables d'entorn a Supabase Dashboard" -ForegroundColor Yellow
