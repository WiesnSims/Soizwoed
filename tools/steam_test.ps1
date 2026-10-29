# Steam check on one PC with one account (needs the Steam client running, logged in).
# A headless host creates a public Soizwoed lobby; a second headless instance searches with the
# game/ver filter and must find exactly that lobby, then tries to join it, which must be
# refused (it is our own account's lobby: Steam cannot connect an account to itself).
# Real joining needs a second Steam account on another PC (see the M3 playtest checklist).
param([int]$HostSeconds = 40)
. "$PSScriptRoot/godot_run.ps1"

if (-not (Get-Process steam -ErrorAction SilentlyContinue)) {
    Write-Host "Steam is not running - start Steam and log in first." -ForegroundColor Red
    exit 1
}

$hostProc = Start-Godot "steam_host" @("--headless", "--", "--net=steam", "--host", "--public", "--smoke=$HostSeconds")
$lobby = ""
for ($i = 0; $i -lt 40 -and -not $lobby; $i++) {
    Start-Sleep -Milliseconds 500
    $line = Get-GodotLog "steam_host" | Select-String -Pattern "\[steam\] lobby created (\d+)" | Select-Object -First 1
    if ($line) { $lobby = $line.Matches[0].Groups[1].Value }
}
$ok = $true
if (-not $lobby) {
    Write-Host "[steam_host] no lobby created" -ForegroundColor Red
    $ok = $false
} else {
    Write-Host "lobby $lobby created"
    # Lobby search results can take a few seconds to include a brand-new lobby.
    Start-Sleep -Seconds 3
    $find = Start-Godot "steam_find" @("--headless", "--", "--net=steam", "--find-lobbies", "--smoke=12")
    $ok = (Wait-Godot $find 60) -and $ok
    if (-not (Get-GodotLog "steam_find" | Select-String -Pattern "\[menu\] lobby $lobby`:")) {
        Write-Host "[steam_find] own lobby $lobby not found by the filtered search" -ForegroundColor Red
        $ok = $false
    }
    $join = Start-Godot "steam_join" @("--headless", "--", "--net=steam", "--lobby=$lobby", "--smoke=12")
    $ok = (Wait-Godot $join 60) -and $ok
    if (-not (Get-GodotLog "steam_join" | Select-String -Pattern "refusing lobby $lobby")) {
        Write-Host "[steam_join] joining our own lobby was not refused" -ForegroundColor Red
        $ok = $false
    }
}
$ok = (Wait-Godot $hostProc ($HostSeconds + 30)) -and $ok
foreach ($pattern in @("\[steam\] ready as", "\[net\] hosting via steam", "\[game\] hub ready", "\[steam\] left lobby")) {
    if (-not (Get-GodotLog "steam_host" | Select-String -Pattern $pattern)) {
        Write-Host "[steam_host] missing in log: $pattern" -ForegroundColor Red
        $ok = $false
    }
}
if (-not $ok) { Write-Host "STEAM TEST FAILED (logs: build/logs/)" -ForegroundColor Red; exit 1 }
Write-Host "STEAM TEST OK (lobby $lobby found and filtered)" -ForegroundColor Green
