param(
    [Parameter(ParameterSetName = 'Interactive')]
    [switch]$Interactive,
    
    [Parameter(ParameterSetName = 'Direct', Mandatory)]
    [SecureString]$Password,
    
    [Parameter(ParameterSetName = 'Direct')]
    [string]$ProjectRef = "qbldqtaqawnahuzlzsjs",
    
    [Parameter(ParameterSetName = 'Direct')]
    [string]$Database = "postgres",
    
    [Parameter(ParameterSetName = 'Direct')]
    [ValidateSet('direct', 'pooler')]
    [string]$ConnectionType = 'direct',
    
    [switch]$Persist,
    [switch]$TestConnection
)

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Test-SupabaseConnection {
    param([string]$ConnectionString)
    
    Write-ColorOutput "🔍 Provant connexió..." "Yellow"
    
    try {
        $env:PGPASSWORD = $null
        $testResult = psql $ConnectionString -c "SELECT version();" -t 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ Connexió exitosa!" "Green"
            Write-ColorOutput "📊 Versió PostgreSQL: $($testResult.Trim())" "Cyan"
            return $true
        } else {
            Write-ColorOutput "❌ Error de connexió: $testResult" "Red"
            return $false
        }
    } catch {
        Write-ColorOutput "❌ Error inesperat: $($_.Exception.Message)" "Red"
        return $false
    }
}

function Get-SupabaseConnectionString {
    param(
        [string]$ProjectRef,
        [SecureString]$Password,
        [string]$Database,
        [string]$ConnectionType
    )
    
    $PlainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
    )
    $EncodedPassword = [uri]::EscapeDataString($PlainPassword)
    
    $user = "postgres.$ProjectRef"
    
    if ($ConnectionType -eq 'direct') {
        $dbHost = "aws-0-eu-central-1.pooler.supabase.com"
        $port = 5432
        Write-ColorOutput "🔗 Utilitzant connexió directa (port 5432)" "Cyan"
    } else {
        # El pooler pot estar en diferents regions, provem la més comuna per EU
        $dbHost = "aws-1-eu-central-1.pooler.supabase.com"
        $port = 6543
        Write-ColorOutput "🔗 Utilitzant connection pooler (port 6543)" "Cyan"
        Write-ColorOutput "ℹ️  Si falla, prova amb connexió directa (-ConnectionType direct)" "Yellow"
    }
    
    $connectionString = "postgresql://${user}:${EncodedPassword}@${dbHost}:${port}/${Database}?sslmode=require"
    
    # Neteja variables sensibles
    Remove-Variable PlainPassword -ErrorAction SilentlyContinue
    Remove-Variable EncodedPassword -ErrorAction SilentlyContinue
    
    return $connectionString
}

function Show-SupabaseInfo {
    param([string]$ConnectionString)
    
    # Màscara per mostrar la connexió de forma segura
    $maskedConnection = $ConnectionString -replace ':[^@]+@', ':********@'
    Write-ColorOutput "🔧 String de connexió: $maskedConnection" "Green"
}

# Funció principal
function Main {
    Write-ColorOutput "🚀 Configurador de Supabase Cloud" "Magenta"
    Write-ColorOutput "======================================" "Magenta"
    
    if ($Interactive) {
        Write-ColorOutput "📝 Mode interactiu activat" "Yellow"
        
        $ProjectRef = Read-Host "Project Reference (qbldqtaqawnahuzlzsjs)"
        if ([string]::IsNullOrEmpty($ProjectRef)) { $ProjectRef = "qbldqtaqawnahuzlzsjs" }
        
        $Database = Read-Host "Base de dades (postgres)"
        if ([string]::IsNullOrEmpty($Database)) { $Database = "postgres" }
        
        $ConnectionTypeInput = Read-Host "Tipus de connexió - direct/pooler (direct)"
        if ([string]::IsNullOrEmpty($ConnectionTypeInput)) { $ConnectionTypeInput = "direct" }
        $ConnectionType = $ConnectionTypeInput
        
        $Password = Read-Host "Contrasenya de la base de dades" -AsSecureString
        
        $PersistInput = Read-Host "Desar permanentment? [y/N]"
        $Persist = $PersistInput -eq 'y' -or $PersistInput -eq 'Y'
    }
    
    # Genera string de connexió
    $connectionString = Get-SupabaseConnectionString -ProjectRef $ProjectRef -Password $Password -Database $Database -ConnectionType $ConnectionType
    
    # Mostra informació
    Show-SupabaseInfo -ConnectionString $connectionString
    
    # Estableix variable d'entorn
    $env:SUPABASE_DB_URL = $connectionString
    Write-ColorOutput "🔧 Variable SUPABASE_DB_URL establerta per aquesta sessió" "Green"
    
    # Desa permanentment si s'ha sol·licitat
    if ($Persist) {
        [Environment]::SetEnvironmentVariable('SUPABASE_DB_URL', $connectionString, 'User')
        Write-ColorOutput "💾 Variable desada permanentment" "Green"
    }
    
    # Prova connexió si s'ha sol·licitat
    if ($TestConnection) {
        Test-SupabaseConnection -ConnectionString $connectionString
    }
    
    Write-ColorOutput "`n🎯 Pròxims passos:" "Yellow"
    Write-ColorOutput "1. Executa: supabase db pull --db-url `$env:SUPABASE_DB_URL" "White"
    Write-ColorOutput "2. Executa: supabase db reset" "White"
    Write-ColorOutput "3. Desenvolupa localment amb: npm run dev" "White"
    
    # Neteja
    Remove-Variable Password -ErrorAction SilentlyContinue
}

# Executa funció principal
Main