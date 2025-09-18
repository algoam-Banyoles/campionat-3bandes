param(
  [Parameter(Mandatory)]
  [string]$Password,
  [string]$User = "postgres",
  [string]$Database = "postgres",
  [string]$DbHost = "db.qbldqtaqawnahuzlzsjs.supabase.co",
  [int]$Port = 5432,
  [switch]$Persist
)

$EncodedPwd = [uri]::EscapeDataString($Password)
$Url = "postgresql://{0}:{1}@{2}:{3}/{4}?sslmode=require" -f $User, $EncodedPwd, $DbHost, $Port, $Database

$env:SUPABASE_DB_URL = $Url

if ($Persist.IsPresent) {
  [Environment]::SetEnvironmentVariable('SUPABASE_DB_URL', $Url, 'User')
  Write-Host "SUPABASE_DB_URL guardada com a variable d'entorn d'usuari."
} else {
  Write-Host "SUPABASE_DB_URL establerta per a aquesta sessio."
}

$pattern = "://$([regex]::Escape($User)):[^@]+@"
$replacement = '://{0}:********@' -f $User
$maskedUrl = [regex]::Replace($Url, $pattern, $replacement)
Write-Host "URL configurada: $maskedUrl"

Remove-Variable Password -ErrorAction SilentlyContinue
