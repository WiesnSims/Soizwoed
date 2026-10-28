# Local multiplayer check over ENet: one headless host + N headless clients on localhost.
# Default: every client connects, the host sees every join, clients leave one by one.
# -HostLeavesFirst: the host quits while clients are connected; every client must notice.
param([int]$Clients = 1, [int]$Port = 24760, [float]$Seconds = 8, [switch]$HostLeavesFirst)
. "$PSScriptRoot/godot_run.ps1"

$hostSeconds = if ($HostLeavesFirst) { $Seconds - 3 } else { $Seconds + 2 }
$hostProc = Start-Godot "mp_host" @("--headless", "--", "--net=enet", "--host", "--port=$Port", "--smoke=$hostSeconds")
Start-Sleep -Milliseconds 1500
$clientProcs = @()
for ($i = 1; $i -le $Clients; $i++) {
    # Clients quit one second apart, like real players leaving. Clients quitting in the
    # very same frame make the host log a harmless engine error (see docs/DECISIONS.md).
    $clientProcs += Start-Godot "mp_client$i" @("--headless", "--", "--net=enet", "--join=127.0.0.1", "--port=$Port", "--smoke=$($Seconds - $Clients + $i)")
}

$allOk = $true
foreach ($proc in $clientProcs) {
    $ok = Wait-Godot $proc ([int]$Seconds + 60)
    $log = Get-GodotLog $proc.LogName
    if (-not ($log | Select-String -SimpleMatch "[net] connected as peer")) {
        Write-Host "[$($proc.LogName)] never connected" -ForegroundColor Red
        $ok = $false
    }
    if ($HostLeavesFirst -and -not ($log | Select-String -SimpleMatch "[net] host left")) {
        Write-Host "[$($proc.LogName)] did not notice the host leaving" -ForegroundColor Red
        $ok = $false
    }
    $allOk = $allOk -and $ok
}
$hostOk = Wait-Godot $hostProc ([int]$Seconds + 60)
$joins = @(Get-GodotLog "mp_host" | Select-String -SimpleMatch "[net] peer joined").Count
if ($joins -ne $Clients) {
    Write-Host "[mp_host] saw $joins of $Clients clients join" -ForegroundColor Red
    $hostOk = $false
}
if (-not ($allOk -and $hostOk)) { Write-Host "MP TEST FAILED (logs: build/logs/)" -ForegroundColor Red; exit 1 }
Write-Host "MP TEST OK ($Clients client(s)$(if ($HostLeavesFirst) { ', host left first' }))" -ForegroundColor Green
