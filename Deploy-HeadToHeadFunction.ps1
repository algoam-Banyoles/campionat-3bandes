# Deploy Head-to-Head Function to Supabase
# This script deploys the get_head_to_head_results function

Write-Host "🚀 Deploying Head-to-Head Function to Supabase" -ForegroundColor Cyan
Write-Host ""

# Read the migration file
$migrationFile = "supabase\migrations\20251103_fix_head_to_head_rls.sql"

if (-not (Test-Path $migrationFile)) {
    Write-Host "❌ Migration file not found: $migrationFile" -ForegroundColor Red
    exit 1
}

Write-Host "📖 Reading migration file: $migrationFile" -ForegroundColor Yellow
$sqlContent = Get-Content $migrationFile -Raw

Write-Host ""
Write-Host "📋 Next steps:" -ForegroundColor Green
Write-Host "1. Go to your Supabase Dashboard: https://supabase.com/dashboard" -ForegroundColor White
Write-Host "2. Navigate to: SQL Editor" -ForegroundColor White
Write-Host "3. Click 'New Query'" -ForegroundColor White
Write-Host "4. Copy the SQL from: $migrationFile" -ForegroundColor White
Write-Host "5. Paste it into the SQL editor" -ForegroundColor White
Write-Host "6. Click 'Run' to execute" -ForegroundColor White
Write-Host ""
Write-Host "Or use Supabase CLI:" -ForegroundColor Green
Write-Host "   supabase db push" -ForegroundColor Cyan
Write-Host ""

# Copy SQL to clipboard if possible
try {
    $sqlContent | Set-Clipboard
    Write-Host "✅ SQL copied to clipboard - ready to paste into Supabase!" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Could not copy to clipboard automatically" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "📄 SQL Preview (first 500 chars):" -ForegroundColor Magenta
Write-Host $sqlContent.Substring(0, [Math]::Min(500, $sqlContent.Length)) -ForegroundColor Gray
Write-Host "..." -ForegroundColor Gray
