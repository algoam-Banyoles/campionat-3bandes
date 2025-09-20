# Script per actualitzar les claus de Supabase
# Executa aquest script després d'obtenir les noves claus del dashboard

param(
    [Parameter(Mandatory=$true)]
    [string]$AnonKey,
    
    [Parameter(Mandatory=$false)]
    [string]$ServiceRoleKey,
    
    [Parameter(Mandatory=$false)]
    [string]$DatabaseUrl
)

$EnvFile = ".env"

Write-Host "🔑 Actualitzant claus de Supabase..." -ForegroundColor Cyan

# Llegir el fitxer actual
$content = Get-Content $EnvFile -Raw

# Validar que la nova clau té el format correcte (JWT)
if (-not $AnonKey.StartsWith("eyJ")) {
    Write-Host "❌ ERROR: La clau anon no sembla ser un JWT vàlid (hauria de començar amb 'eyJ')" -ForegroundColor Red
    Write-Host "   Assegura't d'haver copiat la clau correcta del dashboard de Supabase" -ForegroundColor Yellow
    exit 1
}

# Actualitzar les claus
$content = $content -replace "VITE_SUPABASE_ANON_KEY=.*", "VITE_SUPABASE_ANON_KEY=$AnonKey"
$content = $content -replace "SUPABASE_ANON_KEY=.*", "SUPABASE_ANON_KEY=$AnonKey"

if ($ServiceRoleKey) {
    if (-not $ServiceRoleKey.StartsWith("eyJ")) {
        Write-Host "❌ ERROR: La clau service_role no sembla ser un JWT vàlid" -ForegroundColor Red
        exit 1
    }
    
    # Afegir service_role key si no existeix
    if ($content -notmatch "SUPABASE_SERVICE_ROLE_KEY=") {
        $content += "`nSUPABASE_SERVICE_ROLE_KEY=$ServiceRoleKey"
    } else {
        $content = $content -replace "SUPABASE_SERVICE_ROLE_KEY=.*", "SUPABASE_SERVICE_ROLE_KEY=$ServiceRoleKey"
    }
}

if ($DatabaseUrl) {
    # Afegir/actualitzar database URL si es proporciona
    if ($content -notmatch "SUPABASE_DB_URL=") {
        $content += "`nSUPABASE_DB_URL=$DatabaseUrl"
    } else {
        $content = $content -replace "SUPABASE_DB_URL=.*", "SUPABASE_DB_URL=$DatabaseUrl"
    }
}

# Guardar el fitxer actualitzat
$content | Set-Content $EnvFile -NoNewline

Write-Host "✅ Claus actualitzades correctament!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Configuració actual:" -ForegroundColor Yellow
Write-Host "   URL: $(($content | Select-String 'VITE_SUPABASE_URL=').Line)" -ForegroundColor Gray
Write-Host "   Anon Key: $($AnonKey.Substring(0,20))..." -ForegroundColor Gray

if ($ServiceRoleKey) {
    Write-Host "   Service Role Key: $($ServiceRoleKey.Substring(0,20))..." -ForegroundColor Gray
}

Write-Host ""
Write-Host "🔄 Recorda reiniciar el servidor de desenvolupament per aplicar els canvis:" -ForegroundColor Cyan
Write-Host "   npm run dev" -ForegroundColor White

# Verificar la connexió
Write-Host ""
Write-Host "🔍 Testejant connexió..." -ForegroundColor Cyan

try {
    # Test bàsic de connexió
    $testUrl = "$(($content | Select-String 'VITE_SUPABASE_URL=').Line.Split('=')[1])/rest/v1/"
    $headers = @{
        'apikey' = $AnonKey
        'Authorization' = "Bearer $AnonKey"
    }
    
    # Suprimim l'output de la connexió de test
    Invoke-RestMethod -Uri $testUrl -Headers $headers -Method GET -TimeoutSec 10 > $null
    Write-Host "✅ Connexió exitosa amb Supabase!" -ForegroundColor Green
} catch {
    Write-Host "❌ Error testejant la connexió: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Verifica que les claus siguin correctes al dashboard de Supabase" -ForegroundColor Yellow
}