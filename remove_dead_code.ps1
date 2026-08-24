$file = "lib\features\teacher\presentation\progress_reports_screen.dart"
$content = Get-Content $file -Raw -Encoding UTF8
$pattern = '(?s)\r?\n/// Maps a \[MasteryBand\] to the \[AppBadge\].*?AppBadgeVariant\.neutral,\r?\n    \};'
$content = [Regex]::Replace($content, $pattern, '')
[System.IO.File]::WriteAllText((Resolve-Path $file), $content, [System.Text.Encoding]::UTF8)
Write-Host "Done"
