<#
Stdio MCP server for a Visual Studio MCP endpoint that waits for Visual Studio before it serves.
Registered in local scope as `gb-vs-mcp` (see agents.local.ghost-buster/MCP/README.md):

  powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File wait-vs-mcp.ps1 -Url http://localhost:<port>/sdk/

Claude Code gives an http server one 5 s probe at session start and never retries it, and a Visual
Studio opened by the session-start hook is still loading then. A stdio server gets $env:MCP_TIMEOUT
instead, so this script leaves the client's first message in the pipe until the endpoint answers,
then relays each stdin line as one POST and writes each JSON-RPC reply back as one stdout line.
Requests run concurrently. A request the endpoint does not answer gets a JSON-RPC error, so a Visual
Studio closed mid-session fails the call rather than hanging it, and one reopened on the same port
serves again.

The wait ends at $env:MCP_TIMEOUT milliseconds, the client's own startup bound, or when the client
exits. Stdout carries MCP only; everything else goes to Logs/wait-vs-mcp.log and stderr.

This lives in agents.local.ghost-buster/ - user/device scope, private repo, not part of the project.
#>
param([Parameter(Mandatory)] [string]$Url)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Net.Http

# MCP\scripts -> MCP -> agents.local.ghost-buster -> the GhostBuster root, which is the Unity project.
$UnityDir = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$Log = Join-Path $UnityDir 'Logs\wait-vs-mcp.log'
$LogMaxBytes = 200000
$PollSeconds = 2
# Windows takes about 2 s to refuse a connect, so a listener on one of ::1 and 127.0.0.1 needs more than that.
$ProbeTimeoutSeconds = 5
$DefaultWaitMilliseconds = 600000
$InternalError = -32603
$MethodNotFound = -32601

function Write-Log([string]$message) {
    $line = '{0} [{1}] {2}: {3}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $PID, $Url, $message
    [Console]::Error.WriteLine($line)
    try { Add-Content -LiteralPath $Log -Value $line } catch { }
}

function Get-WaitMilliseconds {
    $configured = 0
    if ([int]::TryParse("$env:MCP_TIMEOUT", [ref]$configured) -and $configured -gt 0) { return $configured }
    return $DefaultWaitMilliseconds
}

# Any HTTP status means the server is up; no response means nothing listens.
function Test-Endpoint {
    $request = [Net.WebRequest]::Create($Url)
    $request.Timeout = $ProbeTimeoutSeconds * 1000
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

function Wait-Endpoint([int]$clientPid) {
    $waitMilliseconds = Get-WaitMilliseconds
    $watch = [Diagnostics.Stopwatch]::StartNew()
    while (-not (Test-Endpoint)) {
        if (-not (Get-Process -Id $clientPid -ErrorAction SilentlyContinue)) {
            Write-Log "client $clientPid exited while waiting"
            return $false
        }
        if ($watch.ElapsedMilliseconds -ge $waitMilliseconds) {
            Write-Log "not answering after $([int]($waitMilliseconds / 1000))s - not serving; run /mcp once Visual Studio has loaded"
            return $false
        }
        Start-Sleep -Seconds $PollSeconds
    }
    Write-Log "answering after $([int]$watch.Elapsed.TotalSeconds)s"
    return $true
}

function Write-Message([string]$json) {
    $script:Writer.WriteLine(($json -replace "`r?`n", ' '))
}

function Write-RequestError([object]$id, [string]$reason) {
    Write-Message (ConvertTo-Json -Compress -InputObject @{ jsonrpc = '2.0'; id = $id; error = @{ code = $InternalError; message = "Visual Studio MCP at $Url did not answer: $reason" } })
}

# One JSON-RPC message per SSE event, its data lines joined.
function Get-EventMessages([string]$body) {
    $data = New-Object Collections.Generic.List[string]
    foreach ($line in ($body -split "`r?`n")) {
        if ($line.StartsWith('data:')) {
            $data.Add($line.Substring(5).TrimStart())
            continue
        }
        if ($line -ne '' -or $data.Count -eq 0) { continue }
        $data -join "`n"
        $data.Clear()
    }
    if ($data.Count -gt 0) { $data -join "`n" }
}

# Visual Studio never answers a method it does not know, so the client's version probe is answered here.
function Send-Request([string]$line) {
    $message = $null
    try { $message = $line | ConvertFrom-Json } catch { }
    $id = if ($message) { $message.id } else { $null }
    if ($message -and $message.method -eq 'server/discover') {
        Write-Message (ConvertTo-Json -Compress -InputObject @{ jsonrpc = '2.0'; id = $id; error = @{ code = $MethodNotFound; message = 'Method not found' } })
        return $null
    }
    $request = New-Object Net.Http.HttpRequestMessage([Net.Http.HttpMethod]::Post, $Url)
    $request.Headers.Accept.ParseAdd('application/json')
    $request.Headers.Accept.ParseAdd('text/event-stream')
    if ($script:SessionId) { $request.Headers.Add('Mcp-Session-Id', $script:SessionId) }
    $request.Content = New-Object Net.Http.StringContent($line, $script:Utf8, 'application/json')
    [pscustomobject]@{ Id = $id; Task = $script:Client.SendAsync($request) }
}

function Receive-Response($pending) {
    try {
        $response = $pending.Task.GetAwaiter().GetResult()
        $values = $null
        if ($response.Headers.TryGetValues('Mcp-Session-Id', [ref]$values)) { $script:SessionId = @($values)[0] }
        $body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        if (-not $response.IsSuccessStatusCode) { throw "HTTP $([int]$response.StatusCode) $body" }

        $mediaType = if ($response.Content.Headers.ContentType) { $response.Content.Headers.ContentType.MediaType } else { '' }
        if ($mediaType -eq 'text/event-stream') {
            foreach ($message in (Get-EventMessages $body)) { Write-Message $message }
        }
        elseif ($body.Trim()) {
            Write-Message $body
        }
    }
    catch {
        $reason = $_.Exception.GetBaseException().Message
        Write-Log "request $($pending.Id) failed: $reason"
        if ($null -ne $pending.Id) { Write-RequestError $pending.Id $reason }
    }
}

function Invoke-Relay {
    $script:Utf8 = New-Object Text.UTF8Encoding $false
    $reader = New-Object IO.StreamReader([Console]::OpenStandardInput(), $script:Utf8)
    $script:Writer = New-Object IO.StreamWriter([Console]::OpenStandardOutput(), $script:Utf8)
    $script:Writer.AutoFlush = $true
    $script:Writer.NewLine = "`n"
    $script:Client = New-Object Net.Http.HttpClient
    $script:Client.Timeout = [Threading.Timeout]::InfiniteTimeSpan
    $script:SessionId = $null

    $inFlight = New-Object Collections.Generic.List[object]
    $readTask = $reader.ReadLineAsync()
    while ($true) {
        $tasks = [Threading.Tasks.Task[]](@($readTask) + @($inFlight | ForEach-Object { $_.Task }))
        $done = [Threading.Tasks.Task]::WaitAny($tasks)
        if ($done -gt 0) {
            $pending = $inFlight[$done - 1]
            $inFlight.RemoveAt($done - 1)
            Receive-Response $pending
            continue
        }

        $line = $readTask.GetAwaiter().GetResult()
        if ($null -eq $line) { break }
        $pending = if ($line.Trim()) { Send-Request $line } else { $null }
        if ($pending) { $inFlight.Add($pending) }
        $readTask = $reader.ReadLineAsync()
    }
    Write-Log 'client closed stdin'
}

try {
    if ((Test-Path -LiteralPath $Log) -and (Get-Item -LiteralPath $Log).Length -gt $LogMaxBytes) { Clear-Content -LiteralPath $Log }

    $clientPid = [int](Get-CimInstance Win32_Process -Filter "ProcessId=$PID").ParentProcessId
    Write-Log "waiting for the endpoint (client $clientPid, up to $([int]((Get-WaitMilliseconds) / 1000))s)"
    if (-not (Wait-Endpoint $clientPid)) { exit 1 }
    Invoke-Relay
    exit 0
}
catch {
    Write-Log "wait-vs-mcp.ps1 failed: $_"
    exit 1
}
