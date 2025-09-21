# PowerShell script to find duplicates in script_cloud_final_complet.sql
$content = Get-Content "script_cloud_final_complet.sql"

# Extract all INSERT statements and parse them
$duplicates = @{}
$missing_socis = @()
$line_number = 0

foreach ($line in $content) {
    $line_number++
    if ($line -match "INSERT INTO mitjanes_historiques.*VALUES \((\d+), (\d+), '([^']+)', ([0-9.]+)\)") {
        $soci_id = $matches[1]
        $year = $matches[2]
        $modalitat = $matches[3]
        $mitjana = $matches[4]
        
        $key = "$soci_id,$year,$modalitat"
        
        if ($duplicates.ContainsKey($key)) {
            $duplicates[$key] += @{
                line = $line_number
                soci_id = $soci_id
                year = $year
                modalitat = $modalitat
                mitjana = $mitjana
                full_line = $line.Trim()
            }
        } else {
            $duplicates[$key] = @(
                @{
                    line = $line_number
                    soci_id = $soci_id
                    year = $year
                    modalitat = $modalitat
                    mitjana = $mitjana
                    full_line = $line.Trim()
                }
            )
        }
    }
}

# Find actual duplicates (more than one entry)
Write-Host "=== DUPLICATE ENTRIES FOUND ===" -ForegroundColor Red
$duplicate_count = 0
foreach ($key in $duplicates.Keys) {
    if ($duplicates[$key].Count -gt 1) {
        $duplicate_count++
        Write-Host "`nDuplicate #$duplicate_count - Key: $key" -ForegroundColor Yellow
        foreach ($entry in $duplicates[$key]) {
            Write-Host "  Line $($entry.line): soci_id=$($entry.soci_id), year=$($entry.year), modalitat='$($entry.modalitat)', mitjana=$($entry.mitjana)" -ForegroundColor White
        }
    }
}

Write-Host "`n=== SUMMARY ===" -ForegroundColor Green
Write-Host "Total duplicate keys found: $duplicate_count" -ForegroundColor Green

# Also check for unusual soci_id formats
Write-Host "`n=== UNUSUAL SOCI_ID FORMATS ===" -ForegroundColor Cyan
$unusual_line = 0
foreach ($line in $content) {
    $unusual_line++
    if ($line -match "INSERT INTO mitjanes_historiques.*VALUES \(([^,]+), (\d+), '([^']+)', ([0-9.]+)\)") {
        $soci_id = $matches[1]
        # Check for unusual formats like leading zeros or very high numbers
        if ($soci_id -match "^0+" -or [int]$soci_id -gt 9999) {
            Write-Host "Line ${unusual_line}: Unusual soci_id format '${soci_id}' - ${line}" -ForegroundColor Yellow
        }
    }
}