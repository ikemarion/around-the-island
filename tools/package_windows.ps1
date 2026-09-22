#Requires -Version 7.2
[CmdletBinding()]
param([string]$Godot = $env:GODOT, [switch]$SkipTests)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $Godot) { $Godot = Join-Path $projectRoot '../../.godot-export-runtime/godot.windows.opt.tools.64.exe' }
$engine = (Resolve-Path -LiteralPath $Godot).Path
$source = Get-Content -LiteralPath (Join-Path $projectRoot 'scripts/main_networked.gd') -Raw
$match = [regex]::Match($source, 'const BUILD_VERSION := "(\d+\.\d+(?:\.\d+)?)"')
if (-not $match.Success) { throw 'Cannot determine build version.' }
$version = $match.Groups[1].Value
$packageName = "ATI-v$version-Windows"
$package = Join-Path $projectRoot "build/$packageName"
$archive = Join-Path $projectRoot "releases/$packageName.zip"
if (Test-Path -LiteralPath $archive) { throw "Package already exists: $archive. Preserve it and bump the version for a new release." }
if (-not $SkipTests) {
    # A child PowerShell process gives a reliable exit status even when all
    # Godot children were launched through ProcessStartInfo instead of '&'.
    & (Get-Process -Id $PID).Path -NoProfile -File (Join-Path $PSScriptRoot 'run_tests.ps1') -Godot $engine -Suite All
    if ($LASTEXITCODE -ne 0) { throw 'Tests failed; no player package was created.' }
}
[IO.Directory]::CreateDirectory($package) | Out-Null
[IO.Directory]::CreateDirectory((Split-Path -Parent $archive)) | Out-Null
$exportLog = Join-Path $projectRoot "build/export-v$version.log"
$executable = Join-Path $package "ATI-v$version.exe"
$info = [Diagnostics.ProcessStartInfo]::new()
$info.FileName = $engine
$info.WorkingDirectory = $projectRoot
$info.UseShellExecute = $false
$info.CreateNoWindow = $true
$info.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
$info.RedirectStandardOutput = $true
$info.RedirectStandardError = $true
foreach ($argument in @('--headless', '--path', $projectRoot, '--log-file', $exportLog, '--export-release', 'Windows Desktop', $executable)) { $info.ArgumentList.Add($argument) }
$process = [Diagnostics.Process]::new()
$process.StartInfo = $info
$started = $false
try {
    $started = $process.Start()
    if (-not $started) { throw 'Could not start export.' }
    $output = $process.StandardOutput.ReadToEndAsync()
    $errors = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(120000)) { $process.Kill($true); throw 'Export timed out; no ZIP created.' }
    $combined = $output.GetAwaiter().GetResult() + "`n" + $errors.GetAwaiter().GetResult()
    [IO.File]::WriteAllText((Join-Path $projectRoot "build/export-v$version.console.log"), $combined)
    $bad = @($combined -split '\r?\n' | Where-Object { $_ -match '^\s*(SCRIPT ERROR:|ERROR:)' -and $_ -notmatch '^ERROR: Failed to read the root certificate store\.$' })
    if ($process.ExitCode -ne 0 -or $bad.Count -gt 0 -or -not (Test-Path -LiteralPath $executable)) { throw "Export failed; inspect $exportLog. $($bad -join '; ')" }
} finally {
    if ($started -and -not $process.HasExited) { $process.Kill($true) }
    $process.Dispose()
}
foreach ($document in @('README.md', 'ONLINE-PLAY.md', 'NETWORK-RELIABILITY.md')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $document) -Destination (Join-Path $package $document)
}
Copy-Item -LiteralPath (Join-Path $projectRoot 'art/fonts/OFL-Fredoka.txt') -Destination (Join-Path $package 'OFL-Fredoka.txt')
# Only the intended player files enter the ZIP, even if local smoke testing
# created extra logs beside a previous export. Never distribute diagnostics.
$zip = [IO.Compression.ZipFile]::Open($archive, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($name in @("ATI-v$version.exe", 'README.md', 'ONLINE-PLAY.md', 'NETWORK-RELIABILITY.md', 'OFL-Fredoka.txt')) {
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, (Join-Path $package $name), "$packageName/$name", [IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
} finally { $zip.Dispose() }
$hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText("$archive.sha256", "$hash  $packageName.zip`n")
Write-Output "WINDOWS_PACKAGE READY $archive"
Write-Output "SHA256 $hash"
Write-Output 'This builds a local package only. Verify the exported game before publishing; no GitHub upload is performed.'
