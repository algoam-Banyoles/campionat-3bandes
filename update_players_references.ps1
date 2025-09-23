# Script para actualizar referencias de 'players' a 'socis'
$sourceDir = "C:\Users\algoa\campionat-3bandes\src"

# Lista de archivos a procesar
$files = @(
    "$sourceDir\routes\+layout.svelte",
    "$sourceDir\routes\+page.svelte",
    "$sourceDir\routes\classificacio\+page.svelte",
    "$sourceDir\routes\llista-espera\+page.svelte",
    "$sourceDir\routes\reptes\+page.svelte",
    "$sourceDir\routes\reptes\me\+page.svelte",
    "$sourceDir\routes\reptes\nou\+page.svelte"
)

foreach ($file in $files) {
    if (Test-Path $file) {
        Write-Host "Updating $file"

        # Leer contenido
        $content = Get-Content $file -Raw

        # Hacer reemplazos
        $content = $content -replace "\.from\('players'\)", ".from('socis')"
        $content = $content -replace "from.*players", "from('socis')"

        # Actualizar selects básicos de players a socis
        $content = $content -replace "\.select\('id, nom, email'\)", ".select('id, nom, cognoms, email')"
        $content = $content -replace "\.select\('id, nom'\)", ".select('id, nom, cognoms')"

        # Escribir de vuelta
        Set-Content $file -Value $content -NoNewline

        Write-Host "✓ Updated $file"
    } else {
        Write-Host "⚠ File not found: $file"
    }
}

Write-Host "✅ Mass update completed"