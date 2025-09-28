param()

# Consulta les restriccions especials dels jugadors
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

$query = "SELECT id, nom, restriccions_especials FROM inscripcions WHERE restriccions_especials IS NOT NULL AND restriccions_especials != '' ORDER BY nom;"

$psqlArgs = @('-h', $dbHost, '-p', $port, '-U', $user, '-d', $db, '-v', 'ON_ERROR_STOP=1', '-P', 'pager=off')

try {
  $env:PGPASSWORD = $pwd

  Write-Host "`n=== Restriccions especials dels jugadors ==="
  & psql @psqlArgs -c $query
  
  Write-Host "`n=== Jugadors que mencionen 'octubre' ==="
  $octoberQuery = "SELECT id, nom, restriccions_especials FROM inscripcions WHERE restriccions_especials ILIKE '%octubre%' ORDER BY nom;"
  & psql @psqlArgs -c $octoberQuery
  
  Write-Host "`n=== Total de jugadors amb restriccions ==="
  $countQuery = "SELECT COUNT(*) as total_amb_restriccions FROM inscripcions WHERE restriccions_especials IS NOT NULL AND restriccions_especials != '';"
  & psql @psqlArgs -c $countQuery
}
finally {
  $env:PGPASSWORD = $null
}