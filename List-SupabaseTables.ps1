param(
  [switch]$IncludeSystem
)

# Llista els esquemes, taules i funcions disponibles a la base de dades Supabase
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

$schemaFilter = $IncludeSystem.IsPresent ? "" : "WHERE schema_name NOT IN ('pg_catalog','information_schema')"
$tablesFilter = $IncludeSystem.IsPresent ? "" : "WHERE table_schema NOT IN ('pg_catalog','information_schema')"

$schemaQuery = "SELECT schema_name FROM information_schema.schemata $schemaFilter ORDER BY schema_name;"
$tablesQuery = "SELECT table_schema, table_name, table_type FROM information_schema.tables $tablesFilter ORDER BY table_schema, table_name;"
$routinesQuery = "SELECT routine_schema, routine_name, routine_type FROM information_schema.routines $tablesFilter ORDER BY routine_schema, routine_type, routine_name;"

$psqlArgs = @('-h', $dbHost, '-p', $port, '-U', $user, '-d', $db, '-v', 'ON_ERROR_STOP=1', '-P', 'pager=off')

try {
  $env:PGPASSWORD = $pwd

  Write-Host "`n=== Esquemes disponibles ==="
  & psql @psqlArgs -c $schemaQuery

  Write-Host "`n=== Taules i vistes ==="
  & psql @psqlArgs -c $tablesQuery

  Write-Host "`n=== Funcions (routines) ==="
  & psql @psqlArgs -c $routinesQuery
}
finally {
  $env:PGPASSWORD = $null
}
