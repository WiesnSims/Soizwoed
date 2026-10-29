# Exports the Windows release build to build/Soizwoed.exe and puts steam_appid.txt next to it.
. "$PSScriptRoot/godot_run.ps1"

$buildDir = Join-Path $ProjectRoot "build"
New-Item -ItemType Directory -Force $buildDir | Out-Null

$import = Start-Godot "import" @("--headless", "--import")
if (-not (Wait-Godot $import 600)) { Write-Host "IMPORT FAILED" -ForegroundColor Red; exit 1 }

$export = Start-Godot "export" @("--headless", "--export-release", "`"Windows Desktop`"", "build/Soizwoed.exe")
$ok = Wait-Godot $export 600
$exe = Join-Path $buildDir "Soizwoed.exe"
if (-not $ok -or -not (Test-Path $exe)) { Write-Host "EXPORT FAILED (log: build/logs/export.log)" -ForegroundColor Red; exit 1 }

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "fix_exe_icon.ps1") -Exe $exe
if ($LASTEXITCODE -ne 0) { exit 1 }

Copy-Item (Join-Path $ProjectRoot "steam_appid.txt") $buildDir -Force
Write-Host "BUILD OK: $exe" -ForegroundColor Green
