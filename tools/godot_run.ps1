# Shared helper: runs Godot with arguments, captures its output, and reports problems.
# Dot-source it from the other tools scripts.

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Godot = if ($env:GODOT) { $env:GODOT } else { "godot" }
$LogDir = Join-Path $ProjectRoot "build/logs"
New-Item -ItemType Directory -Force $LogDir | Out-Null

# Lines in Godot output that count as a failure.
$ProblemPattern = "SCRIPT ERROR|^ERROR:|^WARNING:|Parse Error|Failed to load"

# Starts Godot and returns the process; output goes to build/logs/<Name>.log.
function Start-Godot([string]$Name, [string[]]$Arguments) {
    $out = Join-Path $LogDir "$Name.log"
    $err = Join-Path $LogDir "$Name.err.log"
    $proc = Start-Process -FilePath $Godot -ArgumentList (@("--path", "`"$ProjectRoot`"") + $Arguments) `
        -RedirectStandardOutput $out -RedirectStandardError $err -NoNewWindow -PassThru
    $null = $proc.Handle  # caching the handle keeps ExitCode readable after exit
    $proc | Add-Member -NotePropertyName LogName -NotePropertyValue $Name
    return $proc
}

function Get-GodotLog([string]$Name) {
    $out = Get-Content (Join-Path $LogDir "$Name.log") -ErrorAction SilentlyContinue
    $err = Get-Content (Join-Path $LogDir "$Name.err.log") -ErrorAction SilentlyContinue
    return @($out) + @($err)
}

# Waits for the process and returns $true when it exited cleanly with no problem lines.
function Wait-Godot($Proc, [int]$TimeoutSeconds = 120) {
    if (-not $Proc.WaitForExit($TimeoutSeconds * 1000)) {
        $Proc.Kill()
        Write-Host "[$($Proc.LogName)] timed out after $TimeoutSeconds s" -ForegroundColor Red
        return $false
    }
    $Proc.WaitForExit()
    $problems = Get-GodotLog $Proc.LogName | Where-Object { $_ -match $ProblemPattern }
    $ok = ($Proc.ExitCode -eq 0) -and (-not $problems)
    if ($problems) { $problems | ForEach-Object { Write-Host "[$($Proc.LogName)] $_" -ForegroundColor Red } }
    if ($Proc.ExitCode -ne 0) { Write-Host "[$($Proc.LogName)] exit code $($Proc.ExitCode)" -ForegroundColor Red }
    return $ok
}
