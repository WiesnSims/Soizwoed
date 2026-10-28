# Headless smoke runs: the main menu, and a solo session. Fails on any script error or warning.
param([float]$Seconds = 5)
. "$PSScriptRoot/godot_run.ps1"

$runs = @(
    @{ Name = "smoke_menu"; Args = @("--headless", "--", "--smoke=$Seconds") },
    @{ Name = "smoke_solo"; Args = @("--headless", "--", "--solo", "--smoke=$Seconds") }
)
$allOk = $true
foreach ($run in $runs) {
    $ok = Wait-Godot (Start-Godot $run.Name $run.Args) ([int]$Seconds + 60)
    if ($run.Name -eq "smoke_solo" -and -not (Get-GodotLog $run.Name | Select-String -SimpleMatch "[net] solo session started")) {
        Write-Host "[$($run.Name)] solo session did not start" -ForegroundColor Red
        $ok = $false
    }
    Write-Host ("{0}: {1}" -f $run.Name, $(if ($ok) { "ok" } else { "FAILED" }))
    $allOk = $allOk -and $ok
}
if (-not $allOk) { Write-Host "SMOKE FAILED (logs: build/logs/)" -ForegroundColor Red; exit 1 }
Write-Host "SMOKE OK" -ForegroundColor Green
