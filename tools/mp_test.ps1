# Local multiplayer check over ENet: one headless host + N headless clients on localhost.
# Default: every client connects, the host waits for all of them, rides down, plays a short
#   shift and rides up (the clients stay behind). Every peer must build the same mine.
# -HostLeavesFirst: the host quits in the Gasthaus while clients are connected; every client
#   must notice.
# -Coop: one client and the scripted co-op scenario (tools/dev/dev_scenario.gd "coop"): item
#   physics sync, carrying together, hand-over, death and spectating.
# -Tools: one client uses the M4 tools (tools/dev/dev_scenario.gd "mptools"); the host must see
#   every use arrive and the client must see the results.
param([int]$Clients = 1, [int]$Port = 24760, [switch]$HostLeavesFirst, [switch]$Coop, [switch]$Tools)
. "$PSScriptRoot/godot_run.ps1"

if ($Coop -or $Tools) { $Clients = 1 }
$hostArgs = @("--headless", "--", "--net=enet", "--host", "--port=$Port")
$clientExtra = @()
$hostExpect = @()
$clientExpect = @()
if ($HostLeavesFirst) {
    $hostSeconds = 6
    $clientSeconds = 12
    $clientExpect = @("\[net\] host left")
} elseif ($Coop) {
    $hostSeconds = 34
    $clientSeconds = 30
    $hostArgs += @("--scenario=coop", "--wait-peers=1")
    $clientExtra = @("--scenario=coopclient")
    $hostExpect = @("host: ITestFall fell [1-9]", "host: block holder 1 helper \d+, speed 0\.95", "after letting go, block holder \d+ helper 0", "host: 1 corpse\(s\), client alive false", "\[game\] shift ended")
    $clientExpect = @("client sees ITestPick STORED by P1", "client saw ITestFall fall", "client carrying together with P1, speed 0\.95", "client took the block over", "client dead, spectating P1", "\[game\] shift ended")
} elseif ($Tools) {
    $hostSeconds = 36
    $clientSeconds = 32
    $hostArgs += @("--scenario=mptools", "--wait-peers=1")
    $clientExtra = @("--scenario=mptoolsclient")
    $hostExpect = @("Alphorn by P[0-9]{2,}", "Bierzelt cloud", "Hunt called by P[0-9]{2,}", "host sees P[0-9]+: lamp electric true, health 55", "\[game\] shift ended")
    $clientExpect = @("client used stirnlampe", "client health after obstler 55", "client used boeller", "client used funkgeraet", "client saw the hunt roll [1-9]", "\[game\] shift ended")
} else {
    $hostSeconds = 26
    $clientSeconds = 19
    $hostArgs += @("--auto-shift=6", "--wait-peers=$Clients")
    $hostExpect = @("\[game\] shift ended")
    $clientExpect = @("\[game\] shift started", "\[game\] shift ended")
}

$hostProc = Start-Godot "mp_host" ($hostArgs + @("--smoke=$hostSeconds"))
Start-Sleep -Milliseconds 1500
$clientProcs = @()
for ($i = 1; $i -le $Clients; $i++) {
    # Clients quit one second apart, like real players leaving. Clients quitting in the
    # very same frame make the host log a harmless engine error (see docs/DECISIONS.md).
    $clientProcs += Start-Godot "mp_client$i" (@("--headless", "--", "--net=enet", "--join=127.0.0.1", "--port=$Port") + $clientExtra + @("--smoke=$($clientSeconds + $i)"))
}

function Test-Expect([string]$Name, [string[]]$Patterns) {
    $log = Get-GodotLog $Name
    $ok = $true
    foreach ($pattern in $Patterns) {
        if (-not ($log | Select-String -Pattern $pattern)) {
            Write-Host "[$Name] missing in log: $pattern" -ForegroundColor Red
            $ok = $false
        }
    }
    return $ok
}

# "mine built (seed 123, 9 chunks)" – identical on every peer, or the layouts differ.
function Get-MineLine([string]$Name) {
    $line = Get-GodotLog $Name | Select-String -Pattern "mine built \((seed -?\d+, \d+ chunks)\)" | Select-Object -First 1
    if ($line) { return $line.Matches[0].Groups[1].Value }
    return ""
}

$allOk = $true
foreach ($proc in $clientProcs) {
    $ok = Wait-Godot $proc ($clientSeconds + 60)
    $ok = (Test-Expect $proc.LogName (@("\[net\] connected as peer") + $clientExpect)) -and $ok
    $allOk = $allOk -and $ok
}
$hostOk = Wait-Godot $hostProc ($hostSeconds + 60)
$hostOk = (Test-Expect "mp_host" $hostExpect) -and $hostOk
$joins = @(Get-GodotLog "mp_host" | Select-String -SimpleMatch "[net] peer joined").Count
if ($joins -ne $Clients) {
    Write-Host "[mp_host] saw $joins of $Clients clients join" -ForegroundColor Red
    $hostOk = $false
}
if (-not $HostLeavesFirst) {
    $hostMine = Get-MineLine "mp_host"
    foreach ($proc in $clientProcs) {
        $clientMine = Get-MineLine $proc.LogName
        if ($clientMine -ne $hostMine) {
            Write-Host "[$($proc.LogName)] built '$clientMine', host built '$hostMine'" -ForegroundColor Red
            $allOk = $false
        }
    }
}
# Co-op: an item thrown while walking must fly the same way on both peers (host throw and
# client throw).
function Get-Flight([string]$Name, [string]$Who, [string]$Item) {
    $line = Get-GodotLog $Name | Select-String -Pattern "$($Who): $Item flew ([\d.]+) m" | Select-Object -First 1
    if ($line) { return [double]$line.Matches[0].Groups[1].Value }
    return -1.0
}
if ($Coop) {
    foreach ($item in @("ITestThrow", "ITestThrow2")) {
        $hostFlight = Get-Flight "mp_host" "host" $item
        $clientFlight = Get-Flight "mp_client1" "client" $item
        if ($hostFlight -lt 1.0 -or [math]::Abs($hostFlight - $clientFlight) -gt 0.5) {
            Write-Host "[mp] $item flew $hostFlight m on the host but $clientFlight m on the client" -ForegroundColor Red
            $allOk = $false
        }
    }
}
$mode = if ($HostLeavesFirst) { ", host left first" } elseif ($Coop) { ", co-op scenario" } elseif ($Tools) { ", tools scenario" } else { ", shift played" }
if (-not ($allOk -and $hostOk)) { Write-Host "MP TEST FAILED (logs: build/logs/)" -ForegroundColor Red; exit 1 }
Write-Host "MP TEST OK ($Clients client(s)$mode)" -ForegroundColor Green
