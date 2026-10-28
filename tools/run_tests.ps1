# Runs all GUT unit tests headless. Exit code 0 = all passed.
. "$PSScriptRoot/godot_run.ps1"

$proc = Start-Godot "tests" @("--headless", "-s", "addons/gut/gut_cmdln.gd", "-gdir=res://tests", "-gexit")
$ok = Wait-Godot $proc 300
Get-GodotLog "tests" | Select-String -Pattern "^(Tests|Passing Tests|Failing Tests|Risky|Pending)\s|\[Failed\]" | ForEach-Object { $_.Line }
if (-not $ok) { Write-Host "TESTS FAILED (log: build/logs/tests.log)" -ForegroundColor Red; exit 1 }
Write-Host "TESTS OK" -ForegroundColor Green
