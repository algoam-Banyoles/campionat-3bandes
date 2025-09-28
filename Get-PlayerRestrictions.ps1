param(
    [string]$ConnectionString = $env:SUPABASE_DB_URL
)

Write-Host "Consultant restriccions especials dels jugadors..."

try {
    $result = psql $ConnectionString -c "SELECT id, nom, restriccions_especials FROM inscripcions WHERE restriccions_especials IS NOT NULL AND restriccions_especials != '' ORDER BY nom;"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Restriccions trobades:"
        Write-Host $result
    } else {
        Write-Host "Error en la consulta"
    }
} catch {
    Write-Host "Error: $_"
}