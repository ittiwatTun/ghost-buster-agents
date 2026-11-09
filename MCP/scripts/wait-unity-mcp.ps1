<#
Stdio MCP server for a Unity Editor that waits for the Editor before it serves. Registered in local
scope as `gb-unity-editor-mcp` (see agents.local.ghost-buster/MCP/README.md):

  powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File wait-unity-mcp.ps1 -ProjectPath <path>

`unity mcp` answers initialize at once and lists 0 tools while no Editor for the project is ready, and
never tells the client when tools appear. This script leaves the client's initialize in the pipe until
`unity status` reads the project ready, then starts `unity mcp` on the same stdin and stdout.

-ProjectPath is relative to the GhostBuster root. The wait ends at $env:MCP_TIMEOUT milliseconds, the
client's own startup bound, or when the client exits. Stdout carries MCP only; everything else goes to
Logs/wait-unity-mcp.log and stderr.

This lives in agents.local.ghost-buster/ - user/device scope, private repo, not part of the project.
#>
param([Parameter(Mandatory)] [string]$ProjectPath)

$ErrorActionPreference = 'Stop'

# MCP\scripts -> MCP -> agents.local.ghost-buster -> the GhostBuster root, which is the Unity project.
$UnityDir = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$Project = [IO.Path]::GetFullPath((Join-Path $UnityDir $ProjectPath)).TrimEnd('\')
$Log = Join-Path $UnityDir 'Logs\wait-unity-mcp.log'
$LogMaxBytes = 200000
$PollSeconds = 2
$DefaultWaitMilliseconds = 600000

function Write-Log([string]$message) {
    $line = '{0} [{1}] {2}: {3}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $PID, (Split-Path $Project -Leaf), $message
    [Console]::Error.WriteLine($line)
    try { Add-Content -LiteralPath $Log -Value $line } catch { }
}

function Get-WaitMilliseconds {
    $configured = 0
    if ([int]::TryParse("$env:MCP_TIMEOUT", [ref]$configured) -and $configured -gt 0) { return $configured }
    return $DefaultWaitMilliseconds
}

# The pid, once `unity status` reads this project ready.
function Get-ReadyEditorPid {
    $ErrorActionPreference = 'Continue'
    try {
        $status = (& unity status --json 2>$null) -join "`n" | ConvertFrom-Json
        $editor = @($status.data.instances) | Where-Object { $_.state -eq 'ready' -and "$($_.project)".TrimEnd('\') -eq $Project } | Select-Object -First 1
        if ($editor) { return $editor.pid }
    }
    catch { }
    return $null
}

function Wait-Editor([int]$clientPid) {
    $waitMilliseconds = Get-WaitMilliseconds
    $watch = [Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        $editorPid = Get-ReadyEditorPid
        if ($editorPid) {
            Write-Log "Editor ready (pid $editorPid) after $([int]$watch.Elapsed.TotalSeconds)s"
            return $true
        }
        if (-not (Get-Process -Id $clientPid -ErrorAction SilentlyContinue)) {
            Write-Log "client $clientPid exited while waiting"
            return $false
        }
        if ($watch.ElapsedMilliseconds -ge $waitMilliseconds) {
            Write-Log "no ready Editor after $([int]($waitMilliseconds / 1000))s - not serving; run /mcp once it is ready"
            return $false
        }
        Start-Sleep -Seconds $PollSeconds
    }
}

try {
    if ((Test-Path -LiteralPath $Log) -and (Get-Item -LiteralPath $Log).Length -gt $LogMaxBytes) { Clear-Content -LiteralPath $Log }

    $clientPid = [int](Get-CimInstance Win32_Process -Filter "ProcessId=$PID").ParentProcessId
    Write-Log "waiting for a ready Editor at $Project (client $clientPid, up to $([int]((Get-WaitMilliseconds) / 1000))s)"
    if (-not (Wait-Editor $clientPid)) { exit 1 }

    # No redirection, so `unity mcp` inherits this process's stdin and stdout and reads the waiting initialize itself.
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = (Get-Command unity -CommandType Application | Select-Object -First 1).Source
    $start.Arguments = 'mcp --project-path "{0}"' -f $Project
    $start.UseShellExecute = $false
    $server = [Diagnostics.Process]::Start($start)
    $server.WaitForExit()
    Write-Log "unity mcp exited with $($server.ExitCode)"
    exit $server.ExitCode
}
catch {
    Write-Log "wait-unity-mcp.ps1 failed: $_"
    exit 1
}
