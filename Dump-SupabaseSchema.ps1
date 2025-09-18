param(
  [string]$OutputPath = "supabase\schema.sql",
  [switch]$IncludePrivileges
)

# Exporta tot l'esquema de la base de dades Supabase a un fitxer SQL utilitzant pg_dump
if (-not $env:SUPABASE_DB_URL) {
  Write-Host "No s'ha trobat SUPABASE_DB_URL. Executa Set-SupabaseUrl.ps1 primer."
  exit 1
}

$pattern = [regex]"postgresql://(?<user>[^:]+):(?<pwd>[^@]+)@(?<host>[^:/]+):(?<port>\d+)/(?<db>[^?]+)"
$match = $pattern.Match($env:SUPABASE_DB_URL)
if (-not $match.Success) {
  Write-Host "Format de SUPABASE_DB_URL invalid."
  exit 1
}

$user = $match.Groups['user'].Value
$pwd = [System.Uri]::UnescapeDataString($match.Groups['pwd'].Value)
$dbHost = $match.Groups['host'].Value
$port = [int]$match.Groups['port'].Value
$db = $match.Groups['db'].Value

$fullOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
$parentDir = [System.IO.Path]::GetDirectoryName($fullOutputPath)
if ($parentDir -and -not (Test-Path $parentDir)) {
  New-Item -ItemType Directory -Path $parentDir | Out-Null
}

$dumpArgs = @('-h', $dbHost, '-p', $port, '-U', $user, '-d', $db, '--schema-only', '--no-owner', '--file', $fullOutputPath)
if (-not $IncludePrivileges.IsPresent) {
  $dumpArgs += '--no-privileges'
}

try {
  $env:PGPASSWORD = $pwd
  & pg_dump @dumpArgs
  Write-Host "Esquema exportat a $fullOutputPath"
}
catch {
  Write-Error $_
  exit 1
}
finally {
  $env:PGPASSWORD = $null
}
