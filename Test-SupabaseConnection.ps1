# ============================================
# Test Supabase Cloud Connection
# ============================================
# Script per verificar la connexió a la base de dades de Supabase
# ============================================

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

Write-ColorOutput "`n🔍 VERIFICANT CONNEXIÓ A SUPABASE CLOUD" "Cyan"
Write-ColorOutput "========================================`n" "Cyan"

# 1. Carregar variables d'entorn del fitxer .env
if (-not (Test-Path ".env")) {
    Write-ColorOutput "❌ Error: Fitxer .env no trobat" "Red"
    Write-ColorOutput "   Crea un fitxer .env basant-te en .env.example`n" "Yellow"
    exit 1
}

Write-ColorOutput "📄 Carregant variables del fitxer .env..." "Gray"

Get-Content .env | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]*)\s*=\s*(.*)$') {
        $name = $matches[1].Trim()
        $value = $matches[2].Trim().Trim('"').Trim("'")
        Set-Item -Path "env:$name" -Value $value
    }
}

# 2. Verificar que la variable està definida
if (-not $env:SUPABASE_DB_URL) {
    Write-ColorOutput "`n❌ SUPABASE_DB_URL no està definida al fitxer .env" "Red"
    Write-ColorOutput "   Afegeix la línia:" "Yellow"
    Write-ColorOutput "   SUPABASE_DB_URL=postgresql://postgres.xxxxx:[PASSWORD]@aws-0-eu-central-1.pooler.supabase.com:6543/postgres`n" "Gray"
    exit 1
}

Write-ColorOutput "✅ Variable SUPABASE_DB_URL trobada" "Green"

# 3. Verificar que psql està instal·lat
$psqlVersion = psql --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "`n❌ psql no està instal·lat o no està al PATH" "Red"
    Write-ColorOutput "   Instal·la PostgreSQL client tools:" "Yellow"
    Write-ColorOutput "   choco install postgresql`n" "Gray"
    exit 1
}

Write-ColorOutput "✅ psql trobat: $psqlVersion" "Green"

# 4. Test de connexió bàsica
Write-ColorOutput "`n🔌 Provant connexió a la base de dades..." "Yellow"

# Try with SSL parameters if not already in the URL
$dbUrlToUse = $env:SUPABASE_DB_URL
if (-not ($dbUrlToUse -match '\?')) {
    $dbUrlToUse = "$dbUrlToUse`?sslmode=require"
    Write-ColorOutput "   Afegint paràmetres SSL..." "Gray"
}

$versionResult = psql $dbUrlToUse -c "SELECT version();" -t 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput "✅ Connexió exitosa!" "Green"
    Write-ColorOutput "`n📊 Versió de PostgreSQL:" "Cyan"
    Write-ColorOutput "   $($versionResult.Trim())" "White"
    
    # Update env variable with working URL
    $env:SUPABASE_DB_URL = $dbUrlToUse
} else {
    Write-ColorOutput "`n❌ Error de connexió:" "Red"
    $errorMsg = $versionResult | Out-String
    Write-ColorOutput "   $($errorMsg.Trim())" "Red"
    
    Write-ColorOutput "`n💡 Possibles solucions:" "Yellow"
    
    if ($errorMsg -match "SSL|certificate") {
        Write-ColorOutput "   🔒 Problema SSL detectat:" "Yellow"
        Write-ColorOutput "   1. Afegeix al final del SUPABASE_DB_URL al fitxer .env:" "Gray"
        Write-ColorOutput "      ?sslmode=require" "White"
        Write-ColorOutput "   2. O si ja hi és, prova amb:" "Gray"
        Write-ColorOutput "      ?sslmode=disable (només per debug local)`n" "White"
    } else {
        Write-ColorOutput "   1. Verifica el password al connection string" "Gray"
        Write-ColorOutput "   2. Comprova que la teva IP està autoritzada a Supabase" "Gray"
        Write-ColorOutput "      Dashboard > Settings > Database > Connection Pooling" "Gray"
        Write-ColorOutput "   3. Verifica que utilitzes el port correcte (6543 per pooler)`n" "Gray"
    }
    exit 1
}

# 5. Obtenir informació del projecte
Write-ColorOutput "`n📋 Informació del projecte:" "Cyan"

# Nom de la base de dades
$dbName = psql $env:SUPABASE_DB_URL -c "SELECT current_database();" -t 2>$null
Write-ColorOutput "   Base de dades: $($dbName.Trim())" "White"

# Usuari actual
$currentUser = psql $env:SUPABASE_DB_URL -c "SELECT current_user;" -t 2>$null
Write-ColorOutput "   Usuari: $($currentUser.Trim())" "White"

# 6. Comptar objectes de la base de dades
Write-ColorOutput "`n📊 Estadístiques de la base de dades:" "Cyan"

# Taules
$tableCount = psql $env:SUPABASE_DB_URL -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';" -t 2>$null
Write-ColorOutput "   Taules (public): $($tableCount.Trim())" "White"

# Vistes
$viewCount = psql $env:SUPABASE_DB_URL -c "SELECT COUNT(*) FROM information_schema.views WHERE table_schema = 'public';" -t 2>$null
Write-ColorOutput "   Vistes: $($viewCount.Trim())" "White"

# Funcions
$functionCount = psql $env:SUPABASE_DB_URL -c "SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'public';" -t 2>$null
Write-ColorOutput "   Funcions: $($functionCount.Trim())" "White"

# 7. Verificar taules clau
Write-ColorOutput "`n🔑 Verificant taules principals:" "Cyan"

$keyTables = @('socis', 'players', 'events', 'categories', 'inscripcions', 'calendari_partides')

foreach ($table in $keyTables) {
    $exists = psql $env:SUPABASE_DB_URL -c "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '$table');" -t 2>$null
    if ($exists.Trim() -eq 't') {
        $rowCount = psql $env:SUPABASE_DB_URL -c "SELECT COUNT(*) FROM $table;" -t 2>$null
        Write-ColorOutput "   ✅ $table ($($rowCount.Trim()) files)" "Green"
    } else {
        Write-ColorOutput "   ❌ $table (no existeix)" "Red"
    }
}

# 8. Test de permisos d'escriptura (crear i eliminar una taula temporal)
Write-ColorOutput "`n🔓 Verificant permisos d'escriptura..." "Yellow"

$testTable = "test_connection_" + (Get-Date -Format "yyyyMMddHHmmss")
$createResult = psql $env:SUPABASE_DB_URL -c "CREATE TEMP TABLE $testTable (id INT); DROP TABLE $testTable;" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput "✅ Permisos d'escriptura correctes" "Green"
} else {
    Write-ColorOutput "⚠️  Advertència: No es poden crear taules temporals" "Yellow"
    Write-ColorOutput "   Això és normal si l'usuari només té permisos de lectura" "Gray"
}

# 9. Verificar funcions crítiques
Write-ColorOutput "`n⚙️  Verificant funcions crítiques:" "Cyan"

$criticalFunctions = @(
    'get_social_league_classifications',
    'get_head_to_head_results',
    'registrar_incompareixenca'
)

foreach ($func in $criticalFunctions) {
    $exists = psql $env:SUPABASE_DB_URL -c "SELECT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'public' AND p.proname = '$func');" -t 2>$null
    if ($exists.Trim() -eq 't') {
        # Verificar si té search_path definit
        $hasSearchPath = psql $env:SUPABASE_DB_URL -c "SELECT pg_get_functiondef(oid) FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'public' AND p.proname = '$func' LIMIT 1;" -t 2>$null | Select-String "search_path"
        
        if ($hasSearchPath) {
            Write-ColorOutput "   ✅ $func (amb search_path)" "Green"
        } else {
            Write-ColorOutput "   ⚠️  $func (sense search_path - WARNING DE SEGURETAT)" "Yellow"
        }
    } else {
        Write-ColorOutput "   ❌ $func (no existeix)" "Red"
    }
}

# 10. Resum final
Write-ColorOutput "`n" "White"
Write-ColorOutput "════════════════════════════════════════" "Cyan"
Write-ColorOutput "✅ VERIFICACIÓ COMPLETADA AMB ÈXIT" "Green"
Write-ColorOutput "════════════════════════════════════════" "Cyan"
Write-ColorOutput "`n💡 La connexió a Supabase està configurada correctament!" "White"
Write-ColorOutput "   Pots executar scripts SQL amb:" "Gray"
Write-ColorOutput "   psql `$env:SUPABASE_DB_URL -f fitxer.sql`n" "Gray"
