<#
Waits for one Unity test run started through the unity-editor-mcp test_run tool and always exits.
Start it through Monitor BEFORE test_run: a PROGRESS line every minute and the exit are the notifications.
-Attach joins a run already in flight; its start marker is then not checked.

Reads only what the Editor writes on its own:
  Temp/pipeline_test_request.json  - written by test_run when the request is accepted
  Temp/pipeline_test_status.json   - written by the pipeline when the run finishes
  %LOCALAPPDATA%/Unity/Editor/Editor.log - run start/finish markers, test framework crashes

Budget: with no -TimeoutSeconds, the run gets twice the last measured wall time of the same
mode/filter plus a minute (TestDurations.psm1, MCP/test-durations.json), 1800 s for a suite never
measured. A finished run records its wall time. -StallSeconds defaults to the smaller of 300 and
the last wall time, at least 60.

Exit codes:
  0 finished, nothing failed     1 finished, a test failed or errored
  2 aborted by the test framework or the pipeline
  3 request accepted, run never started (sent during a reload)
  4 no request arrived, or nothing matched the filter
  5 stalled: the run started and the log went silent
  6 cancelled                    7 timed out
#>
param(
    [string]$ProjectPath = '.',
    [int]$RequestSeconds = 180,
    [int]$StartSeconds = 120,
    [int]$StallSeconds = 0,
    [int]$TimeoutSeconds = 0,
    [switch]$Attach
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'TestDurations.psm1') -Force

$project = (Resolve-Path $ProjectPath).Path
$requestFile = Join-Path $project 'Temp\pipeline_test_request.json'
$statusFile = Join-Path $project 'Temp\pipeline_test_status.json'
$logFile = Join-Path $env:LOCALAPPDATA 'Unity\Editor\Editor.log'

$abortPatterns = @(
    'An unexpected error happened while running tests',
    'Too many instant steps in test execution mode',
    '\[PipelineTestRunner\] .*(error|Failed to)'
)

$startedAt = Get-Date
$offset = (Get-Item $logFile).Length
$requestAt = $null
$runStartedAt = $null
$lastActivity = $startedAt
$lastLine = ''
$lastProgress = Get-Date
$linesSinceProgress = 0

function Say([string]$text) {
    Write-Output ("[{0:HH:mm:ss}] {1}" -f (Get-Date), $text)
}

function Read-NewLogLines {
    $length = (Get-Item $logFile).Length
    if ($length -lt $script:offset) {
        $script:offset = 0
    }
    if ($length -eq $script:offset) {
        return @()
    }
    $stream = [System.IO.File]::Open($logFile, 'Open', 'Read', 'ReadWrite, Delete')
    try {
        [void]$stream.Seek($script:offset, 'Begin')
        $reader = New-Object System.IO.StreamReader($stream)
        $text = $reader.ReadToEnd()
        $script:offset = $stream.Position
    }
    finally {
        $stream.Dispose()
    }
    return $text -split "`r?`n" | Where-Object { $_ -ne '' -and $_ -notmatch '^##utp:' }
}

# A run that dies keeps its InitTestScene open and on disk; every later run then restores the
# Editor to it, so a finished run can still leave the Editor on a test scene.
# A healthy run deletes its scene a few seconds after the result lands, so only one still there after 15 s is stranded.
function Stop-Run([int]$code) {
    $deadline = (Get-Date).AddSeconds(15)
    do {
        $stranded = @(Get-ChildItem (Join-Path $project 'Assets') -Filter 'InitTestScene*.unity' -ErrorAction SilentlyContinue)
        if ($stranded.Count -eq 0) {
            break
        }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)
    foreach ($scene in $stranded) {
        Say "STRANDED Assets/$($scene.Name): open the working scene, then asset_delete it before the next run"
    }
    exit $code
}

function Set-Budget([string]$requestJson) {
    $request = $requestJson | ConvertFrom-Json
    $script:budgetKey = "unity:$($request.mode):$($request.filterType):$($request.filter)"
    $last = Get-TestDuration $script:budgetKey
    if ($script:explicitTimeout -eq 0) {
        $script:TimeoutSeconds = Get-TestBudget $script:budgetKey 1800
    }
    if ($script:explicitStall -eq 0) {
        $script:StallSeconds = if ($null -eq $last) { 300 } else { [int][math]::Max(60, [math]::Min(300, $last)) }
    }
    $lastText = if ($null -eq $last) { 'never measured' } else { "last $([math]::Round($last))s" }
    Say "BUDGET $($script:budgetKey): timeout $($script:TimeoutSeconds)s, stall $($script:StallSeconds)s ($lastText)"
}

function Write-Summary {
    $status = Get-Content $statusFile -Raw | ConvertFrom-Json
    if ($status.status -ne 'completed') {
        Say "FINISHED with status '$($status.status)': $($status.message)"
        Stop-Run 2
    }
    if ($null -ne $script:budgetKey -and $null -ne $script:requestAt) {
        Set-TestDuration $script:budgetKey ((Get-Date) - $script:requestAt).TotalSeconds
    }
    $s = $status.summary
    Say ("FINISHED total {0}, passed {1}, failed {2}, skipped {3}, inconclusive {4}, {5}s" -f $s.total, $s.passed, $s.failed, $s.skipped, $s.inconclusive, $status.duration)
    $failed = @($status.results | Where-Object { $_.Status -ne 'Passed' -and $_.Status -ne 'Skipped' })
    foreach ($result in $failed) {
        Say "  $($result.Status) $($result.FullName)"
        if ($result.Message) {
            $messageLines = $result.Message -split "`r?`n" | Select-Object -First 5
            Say ("    " + ($messageLines -join "`n    "))
        }
    }
    if ($s.failed -gt 0 -or $failed.Count -gt 0) {
        Stop-Run 1
    }
    Stop-Run 0
}

# A run that test_run answers in the same call writes no request or status file; the log's finish line is its end.
function Complete-FromLog([int]$failedCount) {
    $deadline = (Get-Date).AddSeconds(5)
    while ((Get-Date) -lt $deadline) {
        if ((Test-Path $statusFile) -and (Get-Item $statusFile).LastWriteTime -ge $startedAt) {
            Write-Summary
        }
        Start-Sleep -Milliseconds 500
    }
    Say 'FINISHED from the log; no status file, see the test_run result for each test'
    if ($failedCount -gt 0) {
        Stop-Run 1
    }
    Stop-Run 0
}

$explicitTimeout = $TimeoutSeconds
$explicitStall = $StallSeconds
$budgetKey = $null
if ($TimeoutSeconds -eq 0) { $TimeoutSeconds = 1800 }
if ($StallSeconds -eq 0) { $StallSeconds = 300 }

Say "watching $project (log offset $offset)"

if ($Attach -and (Test-Path $requestFile)) {
    $requestAt = (Get-Item $requestFile).LastWriteTime
    $runStartedAt = $startedAt
    Say ("ATTACHED " + (Get-Content $requestFile -Raw).Trim())
    Set-Budget (Get-Content $requestFile -Raw)
}

while ($true) {
    Start-Sleep -Milliseconds 1000
    $now = Get-Date

    if ($null -eq $requestAt -and (Test-Path $requestFile) -and (Get-Item $requestFile).LastWriteTime -ge $startedAt.AddSeconds(-2)) {
        $requestAt = (Get-Item $requestFile).LastWriteTime
        Say ("REQUEST " + (Get-Content $requestFile -Raw).Trim())
        Set-Budget (Get-Content $requestFile -Raw)
    }

    foreach ($line in Read-NewLogLines) {
        $lastActivity = $now
        $linesSinceProgress++
        $lastLine = $line
        if ($line -match '\[TestResultCollector\] Run started') {
            $runStartedAt = $now
            Say "STARTED $line"
            continue
        }
        if ($line -match '\[TestResultCollector\] Run finished: (\d+) total, (\d+) passed, (\d+) failed') {
            Say $line
            Complete-FromLog ([int]$Matches[3])
        }
        if ($line -match 'No tests to run after filtering') {
            Say "NO TESTS $line"
            Stop-Run 4
        }
        if ($line -match '\[PipelineTestRunner\] Test run cancelled') {
            Say "CANCELLED $line"
            Stop-Run 6
        }
        if ($line -match 'Reattaching result collector after domain reload') {
            Say "RELOAD DURING RUN $line"
            continue
        }
        foreach ($pattern in $abortPatterns) {
            if ($line -match $pattern) {
                Say "ABORTED $line"
                Say 'clear it with test_cancel before the next test_run'
                Stop-Run 2
            }
        }
    }

    if (($now - $lastProgress).TotalSeconds -ge 60) {
        $clock = if ($null -ne $requestAt) { $requestAt } else { $startedAt }
        $phase = if ($null -ne $runStartedAt) { 'running' } elseif ($null -ne $requestAt) { 'requested' } else { 'waiting for request' }
        $shown = if ($lastLine.Length -gt 160) { $lastLine.Substring(0, 160) } else { $lastLine }
        Say ("PROGRESS {0} {1}s of {2}s, {3} log lines in the last minute; last: {4}" -f $phase, [math]::Round(($now - $clock).TotalSeconds), $TimeoutSeconds, $linesSinceProgress, $shown)
        $lastProgress = $now
        $linesSinceProgress = 0
    }

    if ((Test-Path $statusFile) -and (Get-Item $statusFile).LastWriteTime -ge $startedAt) {
        Start-Sleep -Milliseconds 500
        Write-Summary
    }

    if ($null -eq $requestAt -and ($now - $startedAt).TotalSeconds -gt $RequestSeconds) {
        Say "NO REQUEST within ${RequestSeconds}s"
        Stop-Run 4
    }
    if ($null -ne $requestAt -and $null -eq $runStartedAt -and ($now - $requestAt).TotalSeconds -gt $StartSeconds) {
        Say "NOT STARTED ${StartSeconds}s after the request; last log line: $lastLine"
        Say 'clear it with test_cancel before the next test_run'
        Stop-Run 3
    }
    if ($null -ne $runStartedAt -and ($now - $lastActivity).TotalSeconds -gt $StallSeconds) {
        Say "STALLED no log line for ${StallSeconds}s; last: $lastLine"
        Stop-Run 5
    }
    $clockStart = if ($null -ne $requestAt) { $requestAt } else { $startedAt }
    if (($now - $clockStart).TotalSeconds -gt $TimeoutSeconds) {
        Say "TIMEOUT after ${TimeoutSeconds}s; last: $lastLine"
        Stop-Run 7
    }
}
