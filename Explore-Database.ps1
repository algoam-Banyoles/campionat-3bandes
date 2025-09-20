param(
    [ValidateSet('local', 'cloud', 'both')]
    [string]$Target = 'both',
    [switch]$IncludeSystem,
    [switch]$Verbose
)

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Get-DatabaseInfo {
    param([string]$ConnectionString, [string]$Name)
    
    Write-ColorOutput "`n🔍 === $Name ===" "Cyan"
    
    try {
        $env:PGPASSWORD = $null
        
        # Test connection
        $testResult = psql $ConnectionString -c "SELECT version();" -t 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "❌ No es pot connectar a $Name" "Red"
            if ($Verbose) { Write-ColorOutput "Error: $testResult" "Yellow" }
            return
        }
        
        Write-ColorOutput "✅ Connexió exitosa" "Green"
        
        # Get schemas
        $schemaFilter = if ($IncludeSystem) { "" } else { "WHERE schema_name NOT IN ('pg_catalog','information_schema')" }
        $schemaQuery = "SELECT schema_name FROM information_schema.schemata $schemaFilter ORDER BY schema_name;"
        
        Write-ColorOutput "`n📁 Esquemes:" "Yellow"
        $schemas = psql $ConnectionString -c $schemaQuery -t 2>$null
        if ($schemas) {
            $schemas | ForEach-Object { Write-ColorOutput "  • $($_.Trim())" "White" }
        }
        
        # Get tables
        $tablesFilter = if ($IncludeSystem) { "" } else { "WHERE table_schema NOT IN ('pg_catalog','information_schema')" }
        $tablesQuery = "SELECT table_schema, table_name, table_type FROM information_schema.tables $tablesFilter ORDER BY table_schema, table_name;"
        
        Write-ColorOutput "`n📊 Taules i vistes:" "Yellow"
        $tables = psql $ConnectionString -c $tablesQuery -t 2>$null
        if ($tables) {
            $currentSchema = ""
            $tables | ForEach-Object {
                $parts = $_.Split('|')
                if ($parts.Length -ge 3) {
                    $schema = $parts[0].Trim()
                    $name = $parts[1].Trim()
                    $type = $parts[2].Trim()
                    
                    if ($schema -ne $currentSchema) {
                        Write-ColorOutput "  📂 $schema" "Magenta"
                        $currentSchema = $schema
                    }
                    
                    $icon = if ($type -eq "VIEW") { "👁️ " } else { "📋 " }
                    Write-ColorOutput "    $icon$name ($type)" "White"
                }
            }
        }
        
        # Get functions
        $functionsQuery = "SELECT routine_schema, routine_name, routine_type FROM information_schema.routines $tablesFilter ORDER BY routine_schema, routine_type, routine_name;"
        
        Write-ColorOutput "`n⚡ Funcions:" "Yellow"
        $functions = psql $ConnectionString -c $functionsQuery -t 2>$null
        if ($functions) {
            $currentSchema = ""
            $functions | ForEach-Object {
                $parts = $_.Split('|')
                if ($parts.Length -ge 3) {
                    $schema = $parts[0].Trim()
                    $name = $parts[1].Trim()
                    $type = $parts[2].Trim()
                    
                    if ($schema -ne $currentSchema) {
                        Write-ColorOutput "  📂 $schema" "Magenta"
                        $currentSchema = $schema
                    }
                    
                    $icon = if ($type -eq "FUNCTION") { "🔧 " } else { "📞 " }
                    Write-ColorOutput "    $icon$name ($type)" "White"
                }
            }
        }
        
    } catch {
        Write-ColorOutput "❌ Error: $($_.Exception.Message)" "Red"
    }
}

# Main execution
Write-ColorOutput "🗃️  Explorador de bases de dades Supabase" "Magenta"
Write-ColorOutput "===========================================" "Magenta"

if ($Target -eq 'local' -or $Target -eq 'both') {
    $localConnection = "postgresql://postgres:postgres@127.0.0.1:54322/postgres"
    Get-DatabaseInfo -ConnectionString $localConnection -Name "Base de dades LOCAL"
}

if ($Target -eq 'cloud' -or $Target -eq 'both') {
    if ($env:SUPABASE_DB_URL) {
        Get-DatabaseInfo -ConnectionString $env:SUPABASE_DB_URL -Name "Base de dades CLOUD"
    } else {
        Write-ColorOutput "`n⚠️  Variable SUPABASE_DB_URL no configurada" "Yellow"
        Write-ColorOutput "Executa .\Configure-Supabase.ps1 primer" "White"
    }
}

if ($Target -eq 'both') {
    Write-ColorOutput "`n💡 Consells:" "Yellow"
    Write-ColorOutput "• Utilitza -Target local per veure només la BD local" "White"
    Write-ColorOutput "• Utilitza -Target cloud per veure només la BD cloud" "White"
    Write-ColorOutput "• Afegeix -IncludeSystem per veure esquemes del sistema" "White"
    Write-ColorOutput "• Afegeix -Verbose per veure errors detallats" "White"
}