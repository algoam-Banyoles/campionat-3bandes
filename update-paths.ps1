# Script per actualitzar tots els paths de la reorganització
$files = @(
  'supabase\functions\challenge-notifications\index.ts',
  'static\sw.js',
  'static\service-worker\notifications.js'
)

foreach ($file in $files) {
  if (Test-Path $file) {
    $content = Get-Content $file -Raw
    $content = $content -replace '/reptes/', '/campionat-continu/reptes/'
    $content = $content -replace '`/reptes$', '/campionat-continu/reptes'
    Set-Content $file $content -NoNewline
    Write-Host "Actualitzat: $file"
  }
}
