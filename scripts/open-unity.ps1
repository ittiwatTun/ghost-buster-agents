<#
Opens GhostBuster's Unity Editor with the flags the agent workflow needs, unless an Editor for it is
already running. Run by the SessionStart hook where one is installed (handoff/session-start-setup.md),
and safe to run by hand:

  powershell -NoProfile -ExecutionPolicy Bypass -File open-unity.ps1 [-DryRun]

  -automated       no modal dialog waits for a human
  -force-gfx-mt    multi-threaded renderer, which the Frame Debugger requires

It returns immediately; poll `unity status` until the project's row reads ready.

It launches Unity.exe itself, never `unity open`: the CLI hands the project to Unity Hub, and the
Editor then inherits the Hub process's token. From an elevated shell the launch goes through
Start-StandardUserProcess, because a child of an elevated shell inherits Administrator and Unity
refuses to support that.

-DryRun decides and reports the same way but launches nothing.

This lives in agents.local.ghost-buster/ - user/device scope, private repo, not part of the project. The
project's own docs do not describe it; PREFERENCES.md does.
#>
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'StandardUser.ps1')

# scripts -> agents.local.ghost-buster -> the GhostBuster root, which is the Unity project.
$UnityDir = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$ProjectName = Split-Path $UnityDir -Leaf
$EditorArgs = '-automated -force-gfx-mt'
$Log = Join-Path $UnityDir 'Logs\open-unity.log'
$LogMaxBytes = 200000

function Write-Log([string]$message) {
    Add-Content -LiteralPath $Log -Value ('{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $PID, $message)
}

function Say([string]$message) {
    [Console]::Out.WriteLine($message)
    Write-Log $message
}

function Get-EditorExe {
    $hubRoot = 'C:\Program Files\Unity\Hub\Editor'
    $secondary = Join-Path $env:APPDATA 'UnityHub\secondaryInstallPath.json'
    if (Test-Path -LiteralPath $secondary) {
        $configured = Get-Content -Raw -LiteralPath $secondary | ConvertFrom-Json
        if ($configured -and (Test-Path -LiteralPath $configured)) { $hubRoot = $configured }
    }
    $versionFile = Join-Path $UnityDir 'ProjectSettings\ProjectVersion.txt'
    $version = (Select-String -LiteralPath $versionFile -Pattern '^m_EditorVersion:\s*(\S+)').Matches[0].Groups[1].Value
    Join-Path $hubRoot "$version\Editor\Unity.exe"
}

try {
    New-Item -ItemType Directory -Force -Path (Split-Path $Log) | Out-Null
    if ((Test-Path -LiteralPath $Log) -and (Get-Item -LiteralPath $Log).Length -gt $LogMaxBytes) { Clear-Content -LiteralPath $Log }

    if (-not (Get-Command unity -ErrorAction SilentlyContinue)) {
        Say 'unity CLI not on PATH - Editor not checked, not started'
        exit 0
    }

    # The PID column is the honest one: a closed Editor can still hold a Hub registration, which
    # keeps the row itself present.
    # The CLI writes hints to stderr, which 5.1 turns into a terminating error under Stop.
    $editors = & { $ErrorActionPreference = 'Continue'; unity pipeline editors 2>$null }
    $runningPid = $editors | ForEach-Object {
        $columns = "$_" -split "`t"
        if ($columns.Count -ge 3 -and $columns[0] -eq $ProjectName -and $columns[2].Trim()) { $columns[2].Trim() }
    } | Select-Object -First 1
    if ($runningPid) {
        Say "Unity Editor already running for $ProjectName (pid $runningPid)"
        exit 0
    }

    $editorExe = Get-EditorExe
    if (-not (Test-Path -LiteralPath $editorExe)) {
        Say "no Unity.exe at $editorExe - Editor not started"
        exit 0
    }

    $arguments = '-projectPath "{0}" {1}' -f $UnityDir, $EditorArgs
    $elevated = Test-Elevated

    if ($DryRun) {
        Say "dry run: would start $editorExe $arguments (elevated=$elevated)"
        exit 0
    }

    if (-not $elevated) {
        Start-Process -FilePath $editorExe -ArgumentList $arguments
    }
    elseif (-not (Start-StandardUserProcess -TaskName 'gb-open-unity' -FilePath $editorExe -ArgumentList $arguments -Log $Log)) {
        Say "could not start the Unity Editor as a standard user (log: $Log)"
        exit 0
    }

    Say "Starting Unity Editor for $ProjectName with $EditorArgs - gb-unity-editor-mcp connects once it is ready (log: $Log)"
}
catch {
    Say "open-unity.ps1 failed: $_ (log: $Log)"
}
exit 0
