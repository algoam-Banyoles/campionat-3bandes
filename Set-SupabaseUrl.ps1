param(
  [Parameter(Mandatory)]
  [SecureString]$Password,
  [string]$User = "postgres",
  [string]$Database = "postgres",
  [string]$DbHost = "db.qbldqtaqawnahuzlzsjs.supabase.co",
  [int]$Port = 5432,
  [switch]$Persist
)


$PlainPwd = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))
$EncodedPwd = [uri]::EscapeDataString($PlainPwd)
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

Remove-Variable PlainPwd -ErrorAction SilentlyContinue
Remove-Variable Password -ErrorAction SilentlyContinue
