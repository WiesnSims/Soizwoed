# Headless smoke runs: the main menu, a solo session in the Gasthaus, a whole solo shift, and the
# scripted dev scenarios (tools/dev/dev_scenario.gd). Fails on any script error or warning, or
# when a run does not log what it should (Expect: regexes).
param([float]$Seconds = 5)
. "$PSScriptRoot/godot_run.ps1"

$runs = @(
    @{ Name = "smoke_menu"; Args = @("--headless", "--", "--smoke=$Seconds"); Expect = @() },
    @{ Name = "smoke_solo"; Args = @("--headless", "--", "--solo", "--smoke=$Seconds"); Expect = @("\[net\] solo session started", "\[game\] hub ready") },
    @{ Name = "smoke_shift"; Args = @("--headless", "--", "--solo", "--auto-shift", "--smoke=16"); Expect = @("\[game\] mine built", "\[game\] shift started", "\[game\] shift ended") },
    @{ Name = "smoke_loot"; Args = @("--headless", "--", "--solo", "--scenario=loot", "--smoke=20"); Expect = @("\[scenario\] back in the Gasthaus, money [1-9]") },
    @{ Name = "smoke_cart"; Args = @("--headless", "--", "--solo", "--scenario=cart", "--smoke=12"); Expect = @("dropped onto barrow: CARTED, pocket with G: CARTED", "salzkristall CARTED, 0.00 m") },
    @{ Name = "smoke_mandl"; Args = @("--headless", "--", "--solo", "--scenario=mandl", "--smoke=14"); Expect = @("RUN_OFF .* carrying I") },
    @{ Name = "smoke_tatzel"; Args = @("--headless", "--", "--solo", "--scenario=tatzel", "--smoke=16"); Expect = @("tatzelwurm HUNT", "tatzelwurm SURFACE emerge 1\.0", "tatzelwurm LUNGE emerge 1\.0", "player health ([0-9]|[1-9][0-9])$") },
    @{ Name = "smoke_kaser"; Args = @("--headless", "--", "--solo", "--scenario=kaser", "--smoke=16"); Expect = @("kasermandl lit true STALK", "kasermandl lit false RETREAT .* player health 65") },
    @{ Name = "smoke_meister"; Args = @("--headless", "--", "--solo", "--scenario=meister", "--smoke=36"); Expect = @("Schichtmeister comes for P1", "P1 died") }
)
$allOk = $true
foreach ($run in $runs) {
    $ok = Wait-Godot (Start-Godot $run.Name $run.Args) 90
    $log = Get-GodotLog $run.Name
    foreach ($pattern in $run.Expect) {
        if (-not ($log | Select-String -Pattern $pattern)) {
            Write-Host "[$($run.Name)] missing in log: $pattern" -ForegroundColor Red
            $ok = $false
        }
    }
    Write-Host ("{0}: {1}" -f $run.Name, $(if ($ok) { "ok" } else { "FAILED" }))
    $allOk = $allOk -and $ok
}
if (-not $allOk) { Write-Host "SMOKE FAILED (logs: build/logs/)" -ForegroundColor Red; exit 1 }
Write-Host "SMOKE OK" -ForegroundColor Green
