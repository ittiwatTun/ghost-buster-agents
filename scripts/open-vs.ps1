<#
Opens one Visual Studio per GhostBuster solution, so its VS MCP server (`gb-vs-mcp` in local scope)
answers. Run by the SessionStart hook beside open-unity.ps1 where one is installed
(handoff/session-start-setup.md), and safe to run by hand:

  powershell -NoProfile -ExecutionPolicy Bypass -File open-vs.ps1 [-DryRun]

A solution is opened only when nothing already covers it. Any one of these skips it:
  - its MCP port answers; the port comes from the solution's own .mcp/mcpserver.settings.json
  - a devenv window title or command line names the solution
  - a devenv shows no solution in its title yet, so it may still be loading this one
  - this script launched it less than $LaunchGraceSeconds ago
A devenv opened from the Start menu or the start window carries no solution on its command line;
the window title is the check that sees it.

Runs hold a lock directory, so sessions that start together cannot both launch.

`gb-vs-mcp` runs MCP/scripts/wait-vs-mcp.ps1, which waits for the port, so a Visual Studio started
here connects once it has loaded.

-DryRun decides and reports the same way but launches nothing. Diagnosis: MCP/VS_UNITY.md.

This lives in .agents.local.ghost-buster/ - user/device scope, private repo, not part of the project.
#>
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'StandardUser.ps1')

# scripts -> .agents.local.ghost-buster -> the GhostBuster root, which is the Unity project.
$UnityDir = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$LogsDir = Join-Path $UnityDir 'Logs'
$Log = Join-Path $LogsDir 'open-vs.log'
$Lock = Join-Path $LogsDir 'open-vs.lock'
$LaunchGraceSeconds = 300
$LockWaitSeconds = 20
$LockStaleSeconds = 45
$LaunchConfirmSeconds = 10
$LogMaxBytes = 200000

# Relative to the GhostBuster root.
$Solutions = @(
    'GhostBuster.slnx'
)

function Write-Log([string]$message) {
    Add-Content -LiteralPath $Log -Value ('{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $PID, $message)
}

function Say([string]$message) {
    [Console]::Out.WriteLine($message)
    Write-Log $message
}

function Get-AgeSeconds([string]$path) {
    [int]((Get-Date) - (Get-Item -LiteralPath $path).LastWriteTime).TotalSeconds
}

function Enter-Lock {
    $waited = 0
    while ($true) {
        try {
            New-Item -ItemType Directory -Path $Lock -ErrorAction Stop | Out-Null
            return $true
        }
        catch {
            if ((Test-Path -LiteralPath $Lock) -and (Get-AgeSeconds $Lock) -gt $LockStaleSeconds) {
                Write-Log "breaking stale lock $Lock"
                Remove-Item -LiteralPath $Lock -Force -ErrorAction SilentlyContinue
                continue
            }
            if ($waited -ge $LockWaitSeconds) { return $false }
            Start-Sleep -Seconds 1
            $waited++
        }
    }
}

function Get-DevenvPath {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path -LiteralPath $vswhere)) { return $null }
    $path = & $vswhere -latest -property productPath 2>$null | Select-Object -First 1
    if ($path -and (Test-Path -LiteralPath $path)) { return $path }
    return $null
}

function Get-Devenvs {
    $now = Get-Date
    @(Get-CimInstance Win32_Process -Filter "name='devenv.exe'" | ForEach-Object {
        $process = Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue
        [pscustomobject]@{
            Id          = [int]$_.ProcessId
            AgeSeconds  = [int]($now - $_.CreationDate).TotalSeconds
            Title       = if ($process) { "$($process.MainWindowTitle)" } else { '' }
            CommandLine = "$($_.CommandLine)"
        }
    })
}

# The title starts with the solution name, e.g. `GhostBuster - Foo.cs - Microsoft Visual Studio`.
function Test-NamesSolution($devenv, [string]$slnFile) {
    $base = [IO.Path]::GetFileNameWithoutExtension($slnFile)
    $title = $devenv.Title
    if ($title.StartsWith($base, [StringComparison]::OrdinalIgnoreCase)) {
        $rest = $title.Substring($base.Length)
        if ($rest -eq '' -or $rest.StartsWith(' ')) { return $true }
    }
    return $devenv.CommandLine.IndexOf($slnFile, [StringComparison]::OrdinalIgnoreCase) -ge 0
}

# No window yet, the splash, or the start window.
function Test-ShowsNoSolution($devenv) {
    $devenv.Title -eq '' -or $devenv.Title -match '^Microsoft Visual Studio'
}

# Any HTTP status means the MCP server is up; no response means nothing listens.
function Test-McpPort([int]$port) {
    $request = [Net.WebRequest]::Create("http://localhost:$port/sdk/")
    $request.Timeout = 2000
    $request.Proxy = $null
    try {
        $request.GetResponse().Close()
        return $true
    }
    catch {
        $exception = $_.Exception
        while ($exception -and -not ($exception -is [Net.WebException])) { $exception = $exception.InnerException }
        return [bool]($exception -and $exception.Response)
    }
}

# The devenv that registered the MCP URL with http.sys; netstat shows only System (pid 4) there.
function Get-PortOwner([int]$port) {
    $url = "HTTP://LOCALHOST:$port/SDK/"
    $owner = $null
    foreach ($line in (netsh http show servicestate view=requestq 2>$null)) {
        if ($line -match 'ID: (\d+), image:') { $owner = $Matches[1]; continue }
        if ($line.Trim() -eq $url) { return $owner }
    }
    return $null
}

function Get-McpPort([string]$slnPath) {
    $settings = Join-Path (Split-Path $slnPath) '.mcp\mcpserver.settings.json'
    if (-not (Test-Path -LiteralPath $settings)) { return $null }
    return [int](Get-Content -Raw -LiteralPath $settings | ConvertFrom-Json).port
}

function Start-Devenv([string]$devenvExe, [string]$slnPath) {
    $arguments = '"{0}"' -f $slnPath
    if (-not $script:Elevated) {
        Start-Process -FilePath $devenvExe -ArgumentList $arguments
        return $true
    }
    $taskName = 'gb-open-vs-' +[IO.Path]::GetFileNameWithoutExtension($slnPath)
    return Start-StandardUserProcess -TaskName $taskName -FilePath $devenvExe -ArgumentList $arguments -Log $Log
}

function Invoke-OpenVs {
    $devenvExe = Get-DevenvPath
    if (-not $devenvExe) {
        Say 'no devenv.exe found through vswhere - Visual Studio not started'
        return
    }

    $script:Elevated = Test-Elevated
    $devenvs = Get-Devenvs
    Write-Log ("elevated={0} devenvs=[{1}]" -f $script:Elevated, (($devenvs | ForEach-Object { "$($_.Id):$($_.Title)" }) -join '; '))

    $launched = @()
    foreach ($relative in $Solutions) {
        $slnPath = Join-Path $UnityDir $relative
        $slnFile = Split-Path $slnPath -Leaf
        $slnBase = [IO.Path]::GetFileNameWithoutExtension($slnFile)
        $stamp = Join-Path $LogsDir "open-vs-$slnBase.launched"

        if (-not (Test-Path -LiteralPath $slnPath)) {
            Say "$slnFile not found - skipped"
            continue
        }

        $port = Get-McpPort $slnPath
        $portLabel = if ($port) { "$port" } else { '?' }
        $namingDevenvs = @($devenvs | Where-Object { Test-NamesSolution $_ $slnFile })
        $namingIds = ($namingDevenvs | ForEach-Object { $_.Id }) -join ' '

        if ($port -and (Test-McpPort $port)) {
            $owner = Get-PortOwner $port
            if (-not $owner) { $owner = '?' }
            Say "Visual Studio MCP already answering for $slnFile (port $port, devenv $owner)"
            if ($namingDevenvs.Count -gt 1) {
                Say "  $($namingDevenvs.Count) Visual Studio windows have $slnFile open (devenv $namingIds) - keep devenv $owner, it holds port $port, and closing it stops the MCP server"
            }
            continue
        }

        if ($namingDevenvs.Count -gt 1) {
            Say "$($namingDevenvs.Count) Visual Studio windows have $slnFile open (devenv $namingIds) and none serves MCP port $portLabel - close all but one, start the MCP AI Server there, then /mcp"
            continue
        }

        if ($namingDevenvs.Count -eq 1) {
            $age = $namingDevenvs[0].AgeSeconds
            if ($age -lt $LaunchGraceSeconds) {
                Say "Visual Studio devenv $namingIds is loading $slnFile (${age}s old) - MCP port $portLabel connects once it loads"
            }
            else {
                Say "Visual Studio devenv $namingIds has $slnFile open but MCP port $portLabel is not answering - start the MCP AI Server in that window (or restart it), then /mcp"
            }
            continue
        }

        $showingNoSolution = @($devenvs | Where-Object { Test-ShowsNoSolution $_ })
        if ($showingNoSolution.Count -gt 0) {
            Say "Visual Studio devenv $(($showingNoSolution | ForEach-Object { $_.Id }) -join ' ') shows no solution yet and may be loading $slnFile - not opening another; run this script again once it has loaded"
            continue
        }

        if ((Test-Path -LiteralPath $stamp) -and (Get-AgeSeconds $stamp) -lt $LaunchGraceSeconds) {
            Say "$slnFile was launched $(Get-AgeSeconds $stamp)s ago and no window names it yet - not opening another"
            continue
        }

        if ($DryRun) {
            Say "dry run: would start Visual Studio for $slnFile (elevated=$($script:Elevated))"
            continue
        }

        if (Start-Devenv $devenvExe $slnPath) {
            Set-Content -LiteralPath $stamp -Value (Get-Date -Format o)
            $launched += "$slnFile|$portLabel"
        }
        else {
            Say "could not start Visual Studio for $slnFile (log: $Log)"
        }
    }

    if ($launched.Count -eq 0) { return }

    # A devenv that never appears means the launch failed silently; report what actually started.
    $before = @($devenvs | ForEach-Object { $_.Id })
    $newIds = @()
    for ($i = 0; $i -lt $LaunchConfirmSeconds; $i++) {
        $newIds = @(Get-Process -Name devenv -ErrorAction SilentlyContinue | Where-Object { $before -notcontains $_.Id } | ForEach-Object { $_.Id })
        if ($newIds.Count -ge $launched.Count) { break }
        Start-Sleep -Seconds 1
    }

    foreach ($entry in $launched) {
        $name, $portLabel = $entry -split '\|'
        Say "Starting Visual Studio for $name - MCP port $portLabel connects once it loads"
    }
    if ($newIds.Count -gt 0) {
        Say "  new devenv: $($newIds -join ' ')"
    }
    else {
        Say "  no new devenv appeared within ${LaunchConfirmSeconds}s - check $Log"
    }
}

try {
    New-Item -ItemType Directory -Force -Path $LogsDir | Out-Null
    if ((Test-Path -LiteralPath $Log) -and (Get-Item -LiteralPath $Log).Length -gt $LogMaxBytes) { Clear-Content -LiteralPath $Log }

    if (-not (Enter-Lock)) {
        Say "another open-vs.ps1 run still holds $Lock after ${LockWaitSeconds}s - Visual Studio not checked"
        exit 0
    }
    try {
        Invoke-OpenVs
    }
    finally {
        Remove-Item -LiteralPath $Lock -Force -ErrorAction SilentlyContinue
    }
}
catch {
    Say "open-vs.ps1 failed: $_ (log: $Log)"
}
exit 0
