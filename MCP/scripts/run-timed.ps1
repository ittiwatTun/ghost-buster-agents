<#
Runs one long command with a budget taken from its last measured wall time, and always exits.
Start it through Monitor: a PROGRESS line every minute and the exit are the notifications.

The budget is twice the last wall time recorded under -Key plus a minute (TestDurations.psm1,
MCP/test-durations.json), -FallbackSeconds for a key never measured. Past the budget the whole
process tree is killed. A command that exits on its own records its wall time.

Output goes to -LogPath; the last -TailLines lines are printed at the end.

Exit codes: the command's own, or 124 when the budget killed it.
#>
param(
    [Parameter(Mandatory = $true)][string]$Key,
    [Parameter(Mandatory = $true)][string]$Command,
    [string]$WorkingDirectory = '.',
    [string]$LogPath = '',
    [int]$FallbackSeconds = 1800,
    [int]$TailLines = 30
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'TestDurations.psm1') -Force

function Say([string]$text) {
    Write-Output ("[{0:HH:mm:ss}] {1}" -f (Get-Date), $text)
}

if ($LogPath -eq '') {
    $LogPath = Join-Path $env:TEMP ("run-timed-{0}.log" -f ($Key -replace '[^A-Za-z0-9._-]', '_'))
}
$last = Get-TestDuration $Key
$budget = Get-TestBudget $Key $FallbackSeconds
$lastText = if ($null -eq $last) { 'never measured' } else { "last $([math]::Round($last))s" }
Say "BUDGET ${Key}: ${budget}s ($lastText); log $LogPath"

$startedAt = Get-Date
$process = Start-Process -FilePath 'cmd.exe' -ArgumentList '/d', '/c', "$Command > `"$LogPath`" 2>&1" `
    -WorkingDirectory (Resolve-Path $WorkingDirectory).Path -NoNewWindow -PassThru
# ExitCode stays null unless the handle is opened while the process is alive.
$null = $process.Handle

$lastSize = 0
while (-not $process.WaitForExit(60000)) {
    $elapsed = ((Get-Date) - $startedAt).TotalSeconds
    if ($elapsed -gt $budget) {
        & taskkill.exe /PID $process.Id /T /F | Out-Null
        Say "TIMEOUT after ${budget}s, process tree killed"
        Get-Content $LogPath -Tail $TailLines -ErrorAction SilentlyContinue
        exit 124
    }
    $size = if (Test-Path $LogPath) { (Get-Item $LogPath).Length } else { 0 }
    $lastLine = Get-Content $LogPath -Tail 1 -ErrorAction SilentlyContinue
    if ($lastLine.Length -gt 160) {
        $lastLine = $lastLine.Substring(0, 160)
    }
    Say ("PROGRESS {0}s of {1}s, log +{2} bytes; last: {3}" -f [math]::Round($elapsed), $budget, ($size - $lastSize), $lastLine)
    $lastSize = $size
}

$seconds = ((Get-Date) - $startedAt).TotalSeconds
Set-TestDuration $Key $seconds
Get-Content $LogPath -Tail $TailLines -ErrorAction SilentlyContinue
Say ("DONE exit {0} in {1}s" -f $process.ExitCode, [math]::Round($seconds))
exit $process.ExitCode
