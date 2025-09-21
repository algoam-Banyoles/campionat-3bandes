# Script per generar claus VAPID i configurar el sistema de notificacions
# Generate-VapidKeys.ps1

Write-Host "=== Configuració del Sistema de Notificacions ===" -ForegroundColor Cyan
Write-Host

# Verificar que web-push està instal·lat
Write-Host "Verificant dependències..." -ForegroundColor Yellow

try {
    $webPushVersion = npx web-push --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ web-push trobat: $webPushVersion" -ForegroundColor Green
    } else {
        throw "web-push no trobat"
    }
} catch {
    Write-Host "❌ web-push no està instal·lat globalment" -ForegroundColor Red
    Write-Host "Instal·lant web-push..." -ForegroundColor Yellow
    npm install -g web-push
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Error instal·lant web-push" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ web-push instal·lat correctament" -ForegroundColor Green
}

Write-Host

# Generar claus VAPID
Write-Host "Generant claus VAPID..." -ForegroundColor Yellow

try {
    $vapidKeys = npx web-push generate-vapid-keys --json | ConvertFrom-Json
    
    if ($vapidKeys.publicKey -and $vapidKeys.privateKey) {
        Write-Host "✅ Claus VAPID generades correctament" -ForegroundColor Green
        Write-Host
        
        Write-Host "=== CLAUS VAPID GENERADES ===" -ForegroundColor Cyan
        Write-Host "Clau pública: " -NoNewline -ForegroundColor White
        Write-Host $vapidKeys.publicKey -ForegroundColor Green
        Write-Host "Clau privada: " -NoNewline -ForegroundColor White
        Write-Host $vapidKeys.privateKey -ForegroundColor Red
        Write-Host
        
        # Crear fitxer .env.local si no existeix
        $envFile = ".env.local"
        $envContent = @"
# Claus VAPID per al sistema de notificacions push
# Generades automàticament amb Generate-VapidKeys.ps1
PUBLIC_VAPID_KEY=$($vapidKeys.publicKey)
VAPID_PRIVATE_KEY=$($vapidKeys.privateKey)

# Email de contacte per a VAPID (requerit per alguns navegadors)
VAPID_CONTACT_EMAIL=admin@campionat3bandes.com

# Configuració de Supabase (si no està ja configurada)
# PUBLIC_SUPABASE_URL=your_supabase_url
# PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
# SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
"@

        if (-not (Test-Path $envFile)) {
            Write-Host "Creant fitxer $envFile..." -ForegroundColor Yellow
            $envContent | Out-File -FilePath $envFile -Encoding UTF8
            Write-Host "✅ Fitxer $envFile creat" -ForegroundColor Green
        } else {
            Write-Host "⚠️  El fitxer $envFile ja existeix" -ForegroundColor Yellow
            $backup = "$envFile.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Copy-Item $envFile $backup
            Write-Host "📄 Còpia de seguretat creada: $backup" -ForegroundColor Gray
            
            # Actualitzar o afegir claus VAPID
            $existingContent = Get-Content $envFile -Raw
            
            if ($existingContent -match "PUBLIC_VAPID_KEY=") {
                $existingContent = $existingContent -replace "PUBLIC_VAPID_KEY=.*", "PUBLIC_VAPID_KEY=$($vapidKeys.publicKey)"
            } else {
                $existingContent += "`nPUBLIC_VAPID_KEY=$($vapidKeys.publicKey)"
            }
            
            if ($existingContent -match "VAPID_PRIVATE_KEY=") {
                $existingContent = $existingContent -replace "VAPID_PRIVATE_KEY=.*", "VAPID_PRIVATE_KEY=$($vapidKeys.privateKey)"
            } else {
                $existingContent += "`nVAPID_PRIVATE_KEY=$($vapidKeys.privateKey)"
            }
            
            if ($existingContent -notmatch "VAPID_CONTACT_EMAIL=") {
                $existingContent += "`nVAPID_CONTACT_EMAIL=admin@campionat3bandes.com"
            }
            
            $existingContent | Out-File -FilePath $envFile -Encoding UTF8
            Write-Host "✅ Fitxer $envFile actualitzat amb les noves claus" -ForegroundColor Green
        }
        
        Write-Host
        Write-Host "=== SEGÜENTS PASSOS ===" -ForegroundColor Cyan
        Write-Host "1. Executa la migració de base de dades:" -ForegroundColor White
        Write-Host "   supabase db push" -ForegroundColor Gray
        Write-Host
        Write-Host "2. Actualitza les Edge Functions amb les claus privades:" -ForegroundColor White
        Write-Host "   - Edita supabase/functions/send-push-notification/index.ts" -ForegroundColor Gray
        Write-Host "   - Substitutes la clau privada placeholder" -ForegroundColor Gray
        Write-Host
        Write-Host "3. Desprega les Edge Functions:" -ForegroundColor White
        Write-Host "   supabase functions deploy --no-verify-jwt" -ForegroundColor Gray
        Write-Host
        Write-Host "4. Configura les variables d'entorn a Supabase:" -ForegroundColor White
        Write-Host "   - VAPID_PRIVATE_KEY=$($vapidKeys.privateKey)" -ForegroundColor Gray
        Write-Host "   - VAPID_CONTACT_EMAIL=admin@campionat3bandes.com" -ForegroundColor Gray
        Write-Host
        Write-Host "5. Reinicia el servidor de desenvolupament:" -ForegroundColor White
        Write-Host "   npm run dev" -ForegroundColor Gray
        Write-Host
        
        # Crear script de desplegament
        $deployScript = @"
# Script de desplegament del sistema de notificacions
# Deploy-Notifications.ps1

Write-Host "Desplegant sistema de notificacions..." -ForegroundColor Cyan

# Migrar base de dades
Write-Host "1. Executant migracions..." -ForegroundColor Yellow
supabase db push
if (`$LASTEXITCODE -ne 0) {
    Write-Host "❌ Error en les migracions" -ForegroundColor Red
    exit 1
}

# Desplegar Edge Functions
Write-Host "2. Desplegant Edge Functions..." -ForegroundColor Yellow
supabase functions deploy send-push-notification --no-verify-jwt
supabase functions deploy process-notification-queue --no-verify-jwt  
supabase functions deploy challenge-notifications --no-verify-jwt

if (`$LASTEXITCODE -ne 0) {
    Write-Host "❌ Error desplegant funcions" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Sistema de notificacions desplegat!" -ForegroundColor Green
Write-Host "No oblidis configurar les variables d'entorn a Supabase Dashboard" -ForegroundColor Yellow
"@
        
        $deployScript | Out-File -FilePath "Deploy-Notifications.ps1" -Encoding UTF8
        Write-Host "📄 Script de desplegament creat: Deploy-Notifications.ps1" -ForegroundColor Gray
        
        Write-Host
        Write-Host "🎉 Configuració completada!" -ForegroundColor Green
        Write-Host "Les claus VAPID estan guardades a $envFile" -ForegroundColor White
        
    } else {
        throw "Les claus generades no són vàlides"
    }
    
} catch {
    Write-Host "❌ Error generant claus VAPID: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host
Write-Host "=== INFORMACIÓ DE SEGURETAT ===" -ForegroundColor Red
Write-Host "⚠️  La clau privada és SENSIBLE - no la comparteixis mai!" -ForegroundColor Red
Write-Host "⚠️  Afegeix .env.local al .gitignore si no ho està ja" -ForegroundColor Red
Write-Host "⚠️  En producció, utilitza variables d'entorn segures" -ForegroundColor Red