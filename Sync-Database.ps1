param(
    [ValidateSet('pull', 'push', 'sync', 'reset')]
    [string]$Action = 'sync',
    [switch]$Force,
    [switch]$DryRun,
    [switch]$Backup
)

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Test-Prerequisites {
    Write-ColorOutput "🔍 Verificant prerequisits..." "Yellow"
    
    # Check Supabase CLI
    try {
        $supabaseVersion = supabase --version 2>$null
        Write-ColorOutput "✅ Supabase CLI: $supabaseVersion" "Green"
    } catch {
        Write-ColorOutput "❌ Supabase CLI no trobat" "Red"
        return $false
    }
    
    # Check environment variable
    if (-not $env:SUPABASE_DB_URL) {
        Write-ColorOutput "❌ Variable SUPABASE_DB_URL no configurada" "Red"
        Write-ColorOutput "   Executa .\Configure-Supabase.ps1 primer" "White"
        return $false
    }
    
    Write-ColorOutput "✅ Variable SUPABASE_DB_URL configurada" "Green"
    
    # Test local Supabase
    try {
        psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -c "SELECT 1;" -t 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ Supabase local accessible" "Green"
        } else {
            Write-ColorOutput "⚠️  Supabase local no està executant-se" "Yellow"
            Write-ColorOutput "   Executa 'supabase start' primer" "White"
            return $false
        }
    } catch {
        Write-ColorOutput "❌ Error conectant amb Supabase local" "Red"
        return $false
    }
    
    return $true
}

function Backup-LocalDatabase {
    if (-not $Backup) { return }
    
    Write-ColorOutput "💾 Creant backup de la BD local..." "Yellow"
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFile = "backup_local_$timestamp.sql"
    
    try {
        pg_dump "postgresql://postgres:postgres@127.0.0.1:54322/postgres" > $backupFile
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ Backup creat: $backupFile" "Green"
        } else {
            Write-ColorOutput "❌ Error creant backup" "Red"
            return $false
        }
    } catch {
        Write-ColorOutput "❌ Error en backup: $($_.Exception.Message)" "Red"
        return $false
    }
    
    return $true
}

function Sync-FromCloud {
    Write-ColorOutput "📥 Sincronitzant des de Cloud cap a Local..." "Cyan"
    
    if ($DryRun) {
        Write-ColorOutput "🔍 Mode DRY-RUN: Només mostrant què es faria" "Yellow"
        return
    }
    
    try {
        Write-ColorOutput "⏳ Executant supabase db pull..." "Yellow"
        
        if ($Force) {
            supabase db pull --db-url $env:SUPABASE_DB_URL
        } else {
            supabase db pull --db-url $env:SUPABASE_DB_URL
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ Sincronització completada!" "Green"
            Write-ColorOutput "💡 Executa 'supabase db reset' per aplicar els canvis" "Yellow"
        } else {
            Write-ColorOutput "❌ Error en la sincronització" "Red"
            return $false
        }
    } catch {
        Write-ColorOutput "❌ Error: $($_.Exception.Message)" "Red"
        return $false
    }
    
    return $true
}

function Push-ToCloud {
    Write-ColorOutput "📤 Pujant canvis de Local cap a Cloud..." "Cyan"
    
    if ($DryRun) {
        Write-ColorOutput "🔍 Mode DRY-RUN: Només mostrant què es faria" "Yellow"
        Write-ColorOutput "⚠️  ATENCIÓ: Això pot sobrescriure dades a Cloud!" "Red"
        return
    }
    
    if (-not $Force) {
        Write-ColorOutput "⚠️  ATENCIÓ: Això pot sobrescriure dades a Cloud!" "Red"
        $confirm = Read-Host "Continuar? [y/N]"
        if ($confirm -ne 'y' -and $confirm -ne 'Y') {
            Write-ColorOutput "❌ Operació cancel·lada" "Yellow"
            return $false
        }
    }
    
    try {
        Write-ColorOutput "⏳ Executant supabase db push..." "Yellow"
        supabase db push --db-url $env:SUPABASE_DB_URL
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ Push completat!" "Green"
        } else {
            Write-ColorOutput "❌ Error en el push" "Red"
            return $false
        }
    } catch {
        Write-ColorOutput "❌ Error: $($_.Exception.Message)" "Red"
        return $false
    }
    
    return $true
}

function Reset-LocalDatabase {
    Write-ColorOutput "🔄 Resetejant base de dades local..." "Cyan"
    
    if ($DryRun) {
        Write-ColorOutput "🔍 Mode DRY-RUN: Només mostrant què es faria" "Yellow"
        return
    }
    
    try {
        Write-ColorOutput "⏳ Executant supabase db reset..." "Yellow"
        supabase db reset
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ Reset completat!" "Green"
        } else {
            Write-ColorOutput "❌ Error en el reset" "Red"
            return $false
        }
    } catch {
        Write-ColorOutput "❌ Error: $($_.Exception.Message)" "Red"
        return $false
    }
    
    return $true
}

# Main execution
Write-ColorOutput "🔄 Sincronitzador de Supabase" "Magenta"
Write-ColorOutput "==============================" "Magenta"

if (-not (Test-Prerequisites)) {
    Write-ColorOutput "❌ Els prerequisits no es compleixen" "Red"
    exit 1
}

switch ($Action) {
    'pull' {
        if ($Backup) { Backup-LocalDatabase }
        Sync-FromCloud
    }
    'push' {
        Push-ToCloud
    }
    'reset' {
        if ($Backup) { Backup-LocalDatabase }
        Reset-LocalDatabase
    }
    'sync' {
        Write-ColorOutput "🔄 Sincronització completa..." "Magenta"
        if ($Backup) { Backup-LocalDatabase }
        if (Sync-FromCloud) {
            Reset-LocalDatabase
        }
    }
}

Write-ColorOutput "`n🎯 Pròxims passos recomanats:" "Yellow"
Write-ColorOutput "• Verifica els canvis amb: .\Explore-Database.ps1" "White"
Write-ColorOutput "• Inicia desenvolupament amb: npm run dev" "White"
Write-ColorOutput "• Executa tests amb: npm test" "White"