param(
    [switch]$Quick,
    [switch]$Verbose
)

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Test-Script {
    param([string]$ScriptPath, [string]$Description)
    
    Write-ColorOutput "`n🧪 Testant: $Description" "Cyan"
    
    if (-not (Test-Path $ScriptPath)) {
        Write-ColorOutput "❌ Script no trobat: $ScriptPath" "Red"
        return $false
    }
    
    try {
        # Test sintaxi PowerShell
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $ScriptPath -Raw), [ref]$null)
        Write-ColorOutput "✅ Sintaxi correcta" "Green"
        
        if (-not $Quick) {
            # Test PSScriptAnalyzer si està disponible
            try {
                $analysis = Invoke-ScriptAnalyzer $ScriptPath -ErrorAction SilentlyContinue
                if ($analysis) {
                    Write-ColorOutput "⚠️  PSScriptAnalyzer warnings:" "Yellow"
                    $analysis | ForEach-Object {
                        Write-ColorOutput "   • Línia $($_.Line): $($_.Message)" "Yellow"
                    }
                } else {
                    Write-ColorOutput "✅ PSScriptAnalyzer: Cap warning" "Green"
                }
            } catch {
                Write-ColorOutput "ℹ️  PSScriptAnalyzer no disponible" "Gray"
            }
        }
        
        return $true
        
    } catch {
        Write-ColorOutput "❌ Error de sintaxi: $($_.Exception.Message)" "Red"
        return $false
    }
}

function Test-Prerequisites {
    Write-ColorOutput "🔍 Verificant prerequisits del sistema..." "Yellow"
    
    # Test PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    Write-ColorOutput "📌 PowerShell: $psVersion" "White"
    
    # Test Supabase CLI
    try {
        $supabaseVersion = supabase --version 2>$null
        Write-ColorOutput "✅ Supabase CLI: $supabaseVersion" "Green"
    } catch {
        Write-ColorOutput "⚠️  Supabase CLI no trobat" "Yellow"
    }
    
    # Test psql
    try {
        $psqlVersion = psql --version 2>$null
        Write-ColorOutput "✅ PostgreSQL Client: $psqlVersion" "Green"
    } catch {
        Write-ColorOutput "⚠️  psql no trobat" "Yellow"
    }
    
    # Test npm
    try {
        $npmVersion = npm --version 2>$null
        Write-ColorOutput "✅ npm: $npmVersion" "Green"
    } catch {
        Write-ColorOutput "⚠️  npm no trobat" "Yellow"
    }
}

function Test-ProjectStructure {
    Write-ColorOutput "`n🏗️  Verificant estructura del projecte..." "Yellow"
    
    $requiredFiles = @(
        "package.json",
        "src/lib/supabaseClient.ts",
        "supabase/config.toml",
        "tsconfig.json",
        "vite.config.ts"
    )
    
    $missingFiles = @()
    foreach ($file in $requiredFiles) {
        if (Test-Path $file) {
            Write-ColorOutput "✅ $file" "Green"
        } else {
            Write-ColorOutput "❌ $file" "Red"
            $missingFiles += $file
        }
    }
    
    if ($missingFiles.Count -eq 0) {
        Write-ColorOutput "✅ Estructura del projecte correcta" "Green"
        return $true
    } else {
        Write-ColorOutput "❌ Falten fitxers importants" "Red"
        return $false
    }
}

function Test-EnvironmentVariables {
    Write-ColorOutput "`n🔧 Verificant variables d'entorn..." "Yellow"
    
    if ($env:SUPABASE_DB_URL) {
        Write-ColorOutput "✅ SUPABASE_DB_URL configurada" "Green"
        if ($Verbose) {
            $maskedUrl = $env:SUPABASE_DB_URL -replace ':[^@]+@', ':********@'
            Write-ColorOutput "   $maskedUrl" "Gray"
        }
    } else {
        Write-ColorOutput "⚠️  SUPABASE_DB_URL no configurada" "Yellow"
    }
}

# Main execution
Write-ColorOutput "🔍 Test Suite per al Campionat 3 Bandes" "Magenta"
Write-ColorOutput "=======================================" "Magenta"

Test-Prerequisites
Test-ProjectStructure
Test-EnvironmentVariables

# Test scripts
$scripts = @(
    @{ Path = ".\Configure-Supabase.ps1"; Description = "Configurador de Supabase" },
    @{ Path = ".\Explore-Database.ps1"; Description = "Explorador de base de dades" },
    @{ Path = ".\Sync-Database.ps1"; Description = "Sincronitzador de base de dades" },
    @{ Path = ".\List-SupabaseTables.ps1"; Description = "Llistador de taules" },
    @{ Path = ".\Set-SupabaseUrl.ps1"; Description = "Configurador d'URL (legacy)" }
)

$allGood = $true
foreach ($script in $scripts) {
    $result = Test-Script -ScriptPath $script.Path -Description $script.Description
    if (-not $result) { $allGood = $false }
}

Write-ColorOutput "`n📊 Resum:" "Magenta"
if ($allGood) {
    Write-ColorOutput "✅ Tots els tests han passat correctament!" "Green"
    Write-ColorOutput "`n🎯 Pròxims passos:" "Yellow"
    Write-ColorOutput "1. Configura Supabase: .\Configure-Supabase.ps1 -Interactive" "White"
    Write-ColorOutput "2. Sincronitza BD: .\Sync-Database.ps1 -Action sync" "White"
    Write-ColorOutput "3. Inicia desenvolupament: npm run dev" "White"
} else {
    Write-ColorOutput "❌ Alguns tests han fallat. Revisa els errors anteriors." "Red"
}

Write-ColorOutput "`n💡 Consells:" "Yellow"
Write-ColorOutput "• Executa amb -Verbose per veure més detalls" "White"
Write-ColorOutput "• Utilitza -Quick per ometre PSScriptAnalyzer" "White"