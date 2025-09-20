param(
    [ValidateSet('local', 'cloud', 'both')]
    [string]$Target = 'local',
    [switch]$Detailed,
    [switch]$GenerateReport
)

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Test-DatabaseConnection {
    param([string]$ConnectionString, [string]$Name)
    
    try {
        psql $ConnectionString -c "SELECT 1;" -t 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput ("✅ " + $Name + " - Connexio OK") "Green"
            return $true
        } else {
            Write-ColorOutput ("❌ " + $Name + " - Error de connexio") "Red"
            return $false
        }
    } catch {
        Write-ColorOutput ("❌ " + $Name + " - " + $_.Exception.Message) "Red"
        return $false
    }
}

function Get-RLSStatus {
    param([string]$ConnectionString, [string]$DatabaseName)
    
    Write-ColorOutput "`n🔒 === Row Level Security - $DatabaseName ===" "Cyan"
    
    $rlsQuery = @"
SELECT 
    schemaname,
    tablename,
    rowsecurity,
    CASE 
        WHEN rowsecurity THEN '✅ Activat'
        ELSE '❌ Desactivat'
    END as status
FROM pg_tables 
WHERE schemaname = 'public' 
ORDER BY tablename;
"@
    
    try {
        $result = psql $ConnectionString -c $rlsQuery -t 2>$null
        if ($LASTEXITCODE -eq 0 -and $result) {
            Write-ColorOutput "📊 Estat RLS per taula:" "Yellow"
            $result | ForEach-Object {
                $parts = $_.Split('|')
                if ($parts.Length -ge 3) {
                    $table = $parts[1].Trim()
                    $status = $parts[3].Trim()
                    Write-ColorOutput "  • ${table} : ${status}" "White"
                }
            }
        } else {
            Write-ColorOutput "⚠️  No es poden obtenir dades RLS" "Yellow"
        }
    } catch {
        Write-ColorOutput "❌ Error obtenint RLS: $($_.Exception.Message)" "Red"
    }
}

function Get-RLSPolicies {
    param([string]$ConnectionString, [string]$DatabaseName)
    
    Write-ColorOutput "`n🛡️  === Polítiques RLS - $DatabaseName ===" "Cyan"
    
    $policiesQuery = @"
SELECT 
    schemaname,
    tablename,
    policyname,
    cmd,
    CASE 
        WHEN cmd = 'r' THEN '👁️  SELECT'
        WHEN cmd = 'a' THEN '➕ INSERT'
        WHEN cmd = 'w' THEN '✏️  UPDATE'
        WHEN cmd = 'd' THEN '🗑️  DELETE'
        WHEN cmd = '*' THEN '🔧 ALL'
        ELSE cmd
    END as operation,
    roles
FROM pg_policies 
WHERE schemaname = 'public'
ORDER BY tablename, cmd, policyname;
"@
    
    try {
        $result = psql $ConnectionString -c $policiesQuery -t 2>$null
        if ($LASTEXITCODE -eq 0 -and $result) {
            Write-ColorOutput "📋 Polítiques configurades:" "Yellow"
            $currentTable = ""
            $result | ForEach-Object {
                $parts = $_.Split('|')
                if ($parts.Length -ge 5) {
                    $table = $parts[1].Trim()
                    $policyName = $parts[2].Trim()
                    $operation = $parts[4].Trim()
                    $roles = $parts[5].Trim()
                    
                    if ($table -ne $currentTable) {
                        Write-ColorOutput "`n  📂 $table" "Magenta"
                        $currentTable = $table
                    }
                    
                    Write-ColorOutput "    $operation $policyName ($roles)" "White"
                }
            }
        } else {
            Write-ColorOutput "ℹ️  No hi ha polítiques RLS configurades" "Gray"
        }
    } catch {
        Write-ColorOutput "❌ Error obtenint polítiques: $($_.Exception.Message)" "Red"
    }
}

function Get-AdminUsers {
    param([string]$ConnectionString, [string]$DatabaseName)
    
    Write-ColorOutput "`n👥 === Usuaris Administradors - $DatabaseName ===" "Cyan"
    
    try {
        $adminQuery = "SELECT email, created_at FROM public.admins ORDER BY created_at;"
        $result = psql $ConnectionString -c $adminQuery -t 2>$null
        
        if ($LASTEXITCODE -eq 0 -and $result) {
            Write-ColorOutput "📧 Administradors configurats:" "Yellow"
            $result | ForEach-Object {
                $parts = $_.Split('|')
                if ($parts.Length -ge 2) {
                    $email = $parts[0].Trim()
                    $created = $parts[1].Trim()
                    Write-ColorOutput "  • $email (creat: $created)" "White"
                }
            }
        } else {
            Write-ColorOutput "⚠️  No hi ha administradors configurats" "Yellow"
        }
    } catch {
        Write-ColorOutput "❌ Error obtenint administradors: $($_.Exception.Message)" "Red"
    }
}

function Get-DatabaseRoles {
    param([string]$ConnectionString, [string]$DatabaseName)
    
    if (-not $Detailed) { return }
    
    Write-ColorOutput "`n🎭 === Rols de Base de Dades - $DatabaseName ===" "Cyan"
    
    $rolesQuery = @"
SELECT 
    rolname as role_name,
    CASE 
        WHEN rolsuper THEN '🔴 SUPERUSER'
        WHEN rolcreatedb THEN '🟡 CREATEDB'
        WHEN rolcreaterole THEN '🟠 CREATEROLE'
        ELSE '🟢 NORMAL'
    END as privileges,
    rolcanlogin as can_login
FROM pg_roles 
WHERE rolname NOT LIKE 'pg_%' 
  AND rolname NOT IN ('rds_superuser', 'rdsadmin')
ORDER BY rolsuper DESC, rolname;
"@
    
    try {
        $result = psql $ConnectionString -c $rolesQuery -t 2>$null
        if ($LASTEXITCODE -eq 0 -and $result) {
            Write-ColorOutput "🎭 Rols del sistema:" "Yellow"
            $result | ForEach-Object {
                $parts = $_.Split('|')
                if ($parts.Length -ge 3) {
                    $role = $parts[0].Trim()
                    $privileges = $parts[1].Trim()
                    $canLogin = $parts[2].Trim()
                    $loginStatus = if ($canLogin -eq 't') { "🔓 Pot login" } else { "🔒 No login" }
                    Write-ColorOutput "  • ${role} : ${privileges} | ${loginStatus}" "White"
                }
            }
        }
    } catch {
        Write-ColorOutput "❌ Error obtenint rols: $($_.Exception.Message)" "Red"
    }
}

function Get-FunctionSecurity {
    param([string]$ConnectionString, [string]$DatabaseName)
    
    if (-not $Detailed) { return }
    
    Write-ColorOutput "`n⚡ === Seguretat de Funcions - $DatabaseName ===" "Cyan"
    
    $functionsQuery = @"
SELECT 
    proname as function_name,
    CASE prosecdef
        WHEN true THEN '🔒 SECURITY DEFINER'
        ELSE '🔓 SECURITY INVOKER'
    END as security_type,
    pg_get_userbyid(proowner) as owner
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND proname NOT LIKE 'pg_%'
ORDER BY proname;
"@
    
    try {
        $result = psql $ConnectionString -c $functionsQuery -t 2>$null
        if ($LASTEXITCODE -eq 0 -and $result) {
            Write-ColorOutput "⚡ Funcions i la seva seguretat:" "Yellow"
            $result | ForEach-Object {
                $parts = $_.Split('|')
                if ($parts.Length -ge 3) {
                    $func = $parts[0].Trim()
                    $security = $parts[1].Trim()
                    $owner = $parts[2].Trim()
                    Write-ColorOutput "  • ${func} : ${security} (owner: ${owner})" "White"
                }
            }
        }
    } catch {
        Write-ColorOutput "❌ Error obtenint funcions: $($_.Exception.Message)" "Red"
    }
}

function New-SecurityReport {
    param([string]$ReportContent)
    
    if (-not $GenerateReport) { return }
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $reportFile = "security_audit_$timestamp.md"
    
    $reportHeader = @"
# Informe de Seguretat - Campionat 3 Bandes
**Data:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Generat per:** $env:USERNAME

## Resum Executiu

Aquest informe conté una auditoria completa de la seguretat de la base de dades del projecte Campionat 3 Bandes.

## Detalls de l'Auditoria

"@
    
    $reportHeader + $ReportContent | Out-File -FilePath $reportFile -Encoding UTF8
    Write-ColorOutput "📄 Informe generat: $reportFile" "Green"
}

# Main execution
Write-ColorOutput "🔐 Auditoria de Seguretat - Campionat 3 Bandes" "Magenta"
Write-ColorOutput "===============================================" "Magenta"

$reportContent = ""

if ($Target -eq 'local' -or $Target -eq 'both') {
    $localConnection = "postgresql://postgres:postgres@127.0.0.1:54322/postgres"
    if (Test-DatabaseConnection -ConnectionString $localConnection -Name "Base de dades LOCAL") {
        Get-RLSStatus -ConnectionString $localConnection -DatabaseName "LOCAL"
        Get-RLSPolicies -ConnectionString $localConnection -DatabaseName "LOCAL"
        Get-AdminUsers -ConnectionString $localConnection -DatabaseName "LOCAL"
        Get-DatabaseRoles -ConnectionString $localConnection -DatabaseName "LOCAL"
        Get-FunctionSecurity -ConnectionString $localConnection -DatabaseName "LOCAL"
    }
}

if ($Target -eq 'cloud' -or $Target -eq 'both') {
    if ($env:SUPABASE_DB_URL) {
        if (Test-DatabaseConnection -ConnectionString $env:SUPABASE_DB_URL -Name "Base de dades CLOUD") {
            Get-RLSStatus -ConnectionString $env:SUPABASE_DB_URL -DatabaseName "CLOUD"
            Get-RLSPolicies -ConnectionString $env:SUPABASE_DB_URL -DatabaseName "CLOUD"
            Get-AdminUsers -ConnectionString $env:SUPABASE_DB_URL -DatabaseName "CLOUD"
            Get-DatabaseRoles -ConnectionString $env:SUPABASE_DB_URL -DatabaseName "CLOUD"
            Get-FunctionSecurity -ConnectionString $env:SUPABASE_DB_URL -DatabaseName "CLOUD"
        }
    } else {
        Write-ColorOutput "`n⚠️  Variable SUPABASE_DB_URL no configurada" "Yellow"
        Write-ColorOutput "Executa .\Configure-Supabase.ps1 primer" "White"
    }
}

# Recomanacions de seguretat
Write-ColorOutput "`n💡 === Recomanacions de Seguretat ===" "Yellow"
Write-ColorOutput "✅ Assegura't que RLS està activat en totes les taules sensibles" "White"
Write-ColorOutput "✅ Verifica que només administradors poden modificar dades crítiques" "White"
Write-ColorOutput "✅ Revisa regularment els usuaris administradors" "White"
Write-ColorOutput "✅ Utilitza funcions SECURITY DEFINER amb precaució" "White"
Write-ColorOutput "✅ Mantén actualitzada la documentació de permisos" "White"

Write-ColorOutput "`n🔧 Opcions adicionals:" "Cyan"
Write-ColorOutput "• Executa amb -Detailed per veure més informació" "White"
Write-ColorOutput "• Utilitza -GenerateReport per crear un informe markdown" "White"
Write-ColorOutput "• Especifica -Target cloud per auditar només Supabase Cloud" "White"