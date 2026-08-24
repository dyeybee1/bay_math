$file = Resolve-Path "lib\features\teacher\presentation\progress_reports_screen.dart"
$content = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)

# AppSpacing constants from app_spacing.dart (xs=4, sm=8, md=16, lg=24, xl=32)
$content = $content -replace 'AppSpacing\.xl', '32'
$content = $content -replace 'AppSpacing\.lg', '24'
$content = $content -replace 'AppSpacing\.md', '16'
$content = $content -replace 'AppSpacing\.sm', '8'
$content = $content -replace 'AppSpacing\.xs', '4'

# Also remove the primaryDark unused field warning by removing the field
# (it was defined but never used)
$content = $content -replace '  static const Color primaryDark = Color\(0xFF233C82\);\r?\n', ''

[System.IO.File]::WriteAllText($file, $content, [System.Text.Encoding]::UTF8)
Write-Host "Done - replaced all AppSpacing references"
