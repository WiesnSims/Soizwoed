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
    @{ Name = "smoke_cheat"; Args = @("--headless", "--", "--solo", "--scenario=cheat", "--smoke=6"); Expect = @("cheat: money 0 -> 1000, shown 1000") },
    @{ Name = "smoke_notration"; Args = @("--headless", "--", "--solo", "--scenario=notration", "--smoke=8"); Expect = @("notration with 0 spare: boxes \+1", "notration with 30 spare: boxes \+0") },
    @{ Name = "smoke_cart"; Args = @("--headless", "--", "--solo", "--scenario=cart", "--smoke=12"); Expect = @("dropped onto barrow: CARTED, pocket with G: CARTED", "salzkristall CARTED, 0.00 m") },
    @{ Name = "smoke_mandl"; Args = @("--headless", "--", "--solo", "--scenario=mandl", "--smoke=14"); Expect = @("RUN_OFF .* carrying I") },
    @{ Name = "smoke_tatzel"; Args = @("--headless", "--", "--solo", "--scenario=tatzel", "--smoke=30"); Expect = @("tatzelwurm HUNT", "tatzelwurm SURFACE emerge 1\.0", "tatzelwurm LUNGE emerge 1\.0", "player health ([0-9]|[1-9][0-9])$", "tatzelwurm shootable true: throat x2\.50, scales x0\.35", "tatzelwurm dead true") },
    @{ Name = "smoke_kaser"; Args = @("--headless", "--", "--solo", "--scenario=kaser", "--smoke=18"); Expect = @("kasermandl lit true STALK", "kasermandl lit false RETREAT .* player health ([4-7][0-9])$", "kasermandl shot while lit: health ([0-9]+) -> (?!\1)[0-9]+, shootable true", "kasermandl shot in the dark: health ([0-9]+) -> \1, shootable false") },
    @{ Name = "smoke_tools"; Args = @("--headless", "--", "--solo", "--scenario=tools", "--smoke=45"); Expect = @("stirnlampe electric true, open flame false", "obstler: health 55", "leberkaessemmel: health 95", "boeller gone off: true", "rauchbombe: smoke zones 1", "pfeiferl: hunt came from [0-9.]+ m to [0-2]\.", "pusher P1, cargo 1", "salt wall broken after [1-9] hits: true") },
    @{ Name = "smoke_hazards"; Args = @("--headless", "--", "--solo", "--scenario=hazards", "--smoke=50"); Expect = @("gas with stirnlampe: still there true, health 100", "gas with carbide: gone true, health ([0-9]|[1-8][0-9])$", "gas set off by a bang: true", "brine: in brine true, lamp drain x3", "rockfall happened, health 100 -> ([0-9]|[1-8][0-9])$", "bridge with a miner on it: broken false", "bridge with a salt block: broken true, fell to -[45]", "ladder with a salt block: broken true", "rope from 0\.0 down to -[45]", "on the ledge true") },
    @{ Name = "smoke_salzsee"; Args = @("--headless", "--", "--solo", "--scenario=salzsee", "--smoke=40"); Expect = @("section salzsee, [0-9]+ chunks, cell 16 m", "swimming true, lamp on false, head above water true", "in the water: health ([0-9]|[1-8][0-9])$", "out of the water: true", "ferry crossed [67]\.[0-9] m, rider moved [5-7]\.[0-9] m, swimming false") },
    @{ Name = "smoke_tiefe"; Args = @("--headless", "--", "--solo", "--scenario=tiefe", "--smoke=45"); Expect = @("section die_tiefe, [0-9]+ chunks, cell 14 m, relics [01], loot from other sections 0, rails false", "hat worn true on HatPoint", "box opened true, speckbrot in a pocket true", "speckbrot: health 50 -> 6[45], after the poisoning 4[56]", "sword in hands true, bergmandl health ([0-9]|1[0-9]|-1)$", "\[game\] I[0-9]+ cuckoos", "relic held true, carried [0-9]+ s, sensed from (1[6-9]|2[0-9]) m") },
    @{ Name = "smoke_percht"; Args = @("--headless", "--", "--solo", "--scenario=percht", "--smoke=38"); Expect = @("percht: dark and crouching at [0-9]+ m: seen false", "percht: lamp on: seen true", "percht: then HUNT", "percht: out of sight: (SEARCH|INVESTIGATE|PATROL)", "after a bang: INVESTIGATE towards 0 m off", "face to face, player health 40", "percht: mask x3\.00, body x0\.25", "\[percht\] charges", "percht: windup true, charge true", "percht: killed true") },
    @{ Name = "smoke_weibl"; Args = @("--headless", "--", "--solo", "--scenario=weibl", "--smoke=22"); Expect = @("\[salzweibl\] calls$", "salzweibl: lone miner pinned true, can act false, could shoot false", "salzweibl let go: pinned false, health ([4-8][0-9]), shown false") },
    @{ Name = "smoke_combat"; Args = @("--headless", "--", "--solo", "--scenario=combat", "--smoke=45"); Expect = @("kit: pistol true, rounds 8, spare 24", "sights off the centre while aiming: Bead 0.[0-3][0-9]°", "dogs: 0 left after [0-9]+ shots", "flinte fired true, rounds 2, spare shells 4", "stones: player health ([0-9]|[1-8][0-9]|9[0-2])", "bitten: player health ([0-9]|[1-8][0-9])$", "second wind: health 1, still 1, then alive false") },
    @{ Name = "smoke_fundstueck"; Args = @("--headless", "--", "--solo", "--scenario=fundstueck", "--smoke=40"); Expect = @("in the Fundort true, [0-9]+ m from the cage, board [a-z_]+", "lever without it: phase SHIFT, alarm false", "taken: HELD, alarm true, [1-9][0-9]+ s left, carrier P1", "\[game\] wave: \{", "\[game\] spawn hole", "after the first wave: [1-9]", "on board true", "delivered: shift 2, money \+[1-9][0-9]+, ehrenzeichen [1-9], fired false", "timed out: phase OVER, fired true") },
    @{ Name = "smoke_giveup"; Args = @("--headless", "--", "--solo", "--scenario=giveup", "--smoke=12"); Expect = @("lift up: GAVE_UP", "gave up: fired true") },
    @{ Name = "smoke_boss"; Args = @("--headless", "--", "--solo", "--scenario=boss", "--smoke=24"); Expect = @("boss bergkini, health [1-9][0-9]+, fundstueck locked true", "taking it while he lives: FREE, alarm false", "\[bergkini\] awake", "\[bergkini\] dynamite at P1", "boss state FIGHT, bergmandl 0 -> [1-9]", "boss dead true, fundstueck locked false", "taken after the boss: HELD, alarm true", "\[game\] sting sting_bergkini", "\[game\] sting sting_boss_down") },
    @{ Name = "smoke_upgrades"; Args = @("--headless", "--", "--solo", "--scenario=upgrades", "--smoke=12"); Expect = @("upgrades: pistol magazine 8 -> 12, damage 17, pistol cap 64, armour 70, lamp x1\.20, money 1240", "in the mine: kit pistol rounds 12, armour 70 -> 60, health 90") },
    @{ Name = "smoke_meister"; Args = @("--headless", "--", "--solo", "--scenario=meister", "--smoke=36"); Expect = @("Schichtmeister comes for P1", "P1 died") },
    @{ Name = "smoke_weapons"; Args = @("--headless", "--", "--solo", "--scenario=weapons", "--smoke=40"); Expect = @("stutzen loaded 5", "dog head x1\.50, flank x1\.00", "stutzen fired true, rounds 4, dog dead true", "kasermandl in the dark: lit false", "flare fired true, burning [1-9], kasermandl lit true", "schichtmeister after the flare: stunned [2-5]\.[0-9] s", "\[hazards\] the roof came down", "dynamit thrown, items left in slot 4: false") },
    @{ Name = "smoke_seemuada"; Args = @("--headless", "--", "--solo", "--scenario=seemuada", "--smoke=32"); Expect = @("boss seemuada, health [1-9][0-9]+, fundstueck locked true", "\[seemuada\] awake", "\[seemuada\] bit P1", "seemuada UP, shootable true, head x2\.00, neck x0\.50", "boss dead true, fundstueck locked false", "\[game\] sting sting_seemuada") },
    @{ Name = "smoke_schiachpercht"; Args = @("--headless", "--", "--solo", "--scenario=schiachpercht", "--smoke=32"); Expect = @("boss schiachpercht, health [1-9][0-9]+, fundstueck locked true", "swings the bell", "bell shockwave, [1-9] thrown down", "calls [1-9] Grubenhunde", "boss dead true, fundstueck locked false", "\[game\] sting sting_schiachpercht", "\[game\] sting sting_boss_down") },
    @{ Name = "smoke_knappenbrief"; Args = @("--headless", "--", "--solo", "--scenario=knappenbrief", "--smoke=25"); Expect = @("knappenbrief: honours 53 left, max health 120, health 120, start money \+100, slots 11, help up 2\.4 s, armour 15, lamp true", "knappenbrief: again \+0", "knappenbrief kit: flinte true, pistol true, shells 4, pistol rounds 24, armour 15, battery 936 s", "knappenbrief: delivered, honours 53 -> 5[4-9]") },
    @{ Name = "smoke_overtime"; Args = @("--headless", "--", "--solo", "--scenario=overtime", "--smoke=20"); Expect = @("overtime board: .+berstund: Zaache Viecher, Panzerhunde, Knappe Munition, Eile, Fr.+her Pfiff, Ka Liacht", "overtime: lanterns lit 0 of [1-9][0-9]*, shift 450 s, ammo boxes [1-9], dog health 48 \(base 55\), hit 20 -> -12", "ping: marks 1", "overtime alarm: 0\.75 of the usual") },
    @{ Name = "smoke_impacts"; Args = @("--headless", "--", "--solo", "--scenario=impacts", "--smoke=16"); Expect = @("surfaces: rock [1-9][0-9]*, wood [1-9][0-9]*, metal [0-9]+, cage floor METAL", "draw: just taken 0\.[5-9][0-9]", "draw: after 0\.5 s 0\.00", "shot the rock true: marks ([0-9]+) -> (?!\1)[0-9]+", "dog died: marks ([0-9]+) -> (?!\1)[0-9]+", "bergkini head x2\.00, belly x1\.00") },
    @{ Name = "smoke_elites"; Args = @("--headless", "--", "--solo", "--scenario=elites", "--smoke=10"); Expect = @("elite health ([0-9]+) vs [0-9]+, speed x1\.20, glow true", "the Raunacht left a box", "elite dead, ammo boxes \+1") }
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
