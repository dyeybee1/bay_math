param(
    [switch]$SkipFlutterBuild
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$releaseDir = Join-Path $projectRoot 'build\windows\x64\runner\Release'
$outputDir = Join-Path $projectRoot 'build\installers'

$versionLine = Get-Content (Join-Path $projectRoot 'pubspec.yaml') |
    Where-Object { $_ -match '^version:\s*' } |
    Select-Object -First 1
if ($versionLine -notmatch '^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$') {
    throw 'pubspec.yaml must contain a numeric version such as 0.1.0+1.'
}
$appVersion = '{0}.{1}.{2}' -f $Matches[1], $Matches[2], $Matches[3]
$fileVersion = '{0}.{1}' -f $appVersion, $Matches[4]

Push-Location $projectRoot
try {
    if (-not $SkipFlutterBuild) {
        & flutter build windows --release --target lib/main_staff.dart
        if ($LASTEXITCODE -ne 0) { throw 'Flutter Windows release build failed.' }
    }

    foreach ($requiredFile in @('bay_math.exe', 'flutter_windows.dll', 'data\app.so')) {
        if (-not (Test-Path -LiteralPath (Join-Path $releaseDir $requiredFile))) {
            throw "Windows release is missing $requiredFile. Build it before packaging."
        }
    }

    # Flutter's Windows runner and plugins import these Visual C++ runtime DLLs.
    $runtimeFiles = @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')
    $redistDirectories = @(
        foreach ($vsRoot in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
            if (-not $vsRoot) { continue }
            $pattern = Join-Path $vsRoot 'Microsoft Visual Studio\*\*\VC\Redist\MSVC\*\x64\Microsoft.VC*.CRT'
            Get-ChildItem -Path $pattern -Directory -ErrorAction SilentlyContinue
        }
    )
    $redistDirectory = $redistDirectories |
        Where-Object {
            $directory = $_.FullName
            @($runtimeFiles | Where-Object { -not (Test-Path -LiteralPath (Join-Path $directory $_)) }).Count -eq 0
        } |
        Sort-Object FullName -Descending |
        Select-Object -First 1
    if ($null -eq $redistDirectory) {
        throw 'Could not find the x64 Visual C++ redistributable DLLs in Visual Studio.'
    }
    foreach ($runtimeFile in $runtimeFiles) {
        Copy-Item -LiteralPath (Join-Path $redistDirectory.FullName $runtimeFile) -Destination $releaseDir -Force
    }

    $compilerCandidates = @(
        (Join-Path ${env:ProgramFiles(x86)} 'NSIS\makensis.exe'),
        (Join-Path $env:ProgramFiles 'NSIS\makensis.exe')
    )
    $compiler = $compilerCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $compiler) { throw 'NSIS is required. Install the free NSIS compiler first.' }

    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
    & $compiler "/DAPP_VERSION=$appVersion" "/DAPP_FILE_VERSION=$fileVersion" "/DRELEASE_DIR=$releaseDir" "/DOUTPUT_DIR=$outputDir" (Join-Path $PSScriptRoot 'baymath_teacher_installer.nsi')
    if ($LASTEXITCODE -ne 0) { throw 'NSIS installer compilation failed.' }

    $installer = Join-Path $outputDir "BayMath-Teacher-Setup-$appVersion.exe"
    if (-not (Test-Path -LiteralPath $installer)) { throw 'NSIS did not create the installer.' }
    Write-Output "Installer ready: $installer"
}
finally {
    Pop-Location
}
