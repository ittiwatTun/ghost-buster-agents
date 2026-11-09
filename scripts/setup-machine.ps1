<#
Installs the untracked, per-machine pieces of session start from their tracked sources in
.agents.local.ghost-buster/setup/. Safe to run again; a piece already in place is left alone.

  powershell -NoProfile -ExecutionPolicy Bypass -File setup-machine.ps1 [-DryRun]

  | Untracked target                                              | Tracked source                  |
  | %USERPROFILE%\.claude\commands\session-start.md               | setup/session-start.md          |
  | <GhostBuster>\CLAUDE.local.md  (holds the import line)        | setup/CLAUDE.local.md           |
  | <GhostBuster>\PREFERENCES.md  (pointer, gitignored)           | setup/PREFERENCES.pointer.md    |
  | <GhostBuster>\.mcp\mcpserver.settings.json  (VS MCP port)     | setup/mcpserver.settings.json   |
  | <GhostBuster>\.git\info\exclude  (private paths)              | -                               |
  | <GhostBuster>\.claude\settings.local.json hooks.SessionStart  | setup/session-start-hooks.json  |

settings.local.json is merged: only hooks.SessionStart is replaced, every other key stays. GhostBuster
tracks that file in git, so the hook step is skipped while it is tracked: a hook written there would
show in every commit.
The MCP servers are not installed here; see MCP/README.md.

-DryRun reports what it would change and writes nothing.
#>
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'

# PowerShell 7 writes JSON with plain two-space indentation; 5.1 pads it into columns.
if ($PSVersionTable.PSVersion.Major -lt 6 -and (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    $forward = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath)
    if ($DryRun) { $forward += '-DryRun' }
    & pwsh @forward
    exit $LASTEXITCODE
}

# scripts -> .agents.local.ghost-buster -> the GhostBuster root.
$AgentsDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$AgentsName = Split-Path $AgentsDir -Leaf
$RootDir = (Resolve-Path (Join-Path $AgentsDir '..')).Path
$SetupDir = Join-Path $AgentsDir 'setup'
$Utf8 = New-Object System.Text.UTF8Encoding($false)

function Write-Step([string]$Target, [string]$State) {
    Write-Output ("{0,-9} {1}" -f $State, $Target)
}

function Write-TextFile([string]$Path, [string]$Text) {
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    [System.IO.File]::WriteAllText($Path, $Text, $Utf8)
}

function Read-Text([string]$Path) {
    if (-not (Test-Path $Path)) { return $null }
    return [System.IO.File]::ReadAllText($Path)
}

# Copies a tracked source over its target when the two differ.
function Copy-Piece([string]$Target, [string]$Source) {
    $text = Read-Text (Join-Path $SetupDir $Source)
    if ((Read-Text $Target) -eq $text) {
        Write-Step $Target 'ok'
    } else {
        if (-not $DryRun) { Write-TextFile $Target $text }
        Write-Step $Target 'written'
    }
}

# 1. The /session-start command.
Copy-Piece (Join-Path $env:USERPROFILE '.claude\commands\session-start.md') 'session-start.md'

# 2. CLAUDE.local.md: holds the tracked import line; other lines the machine added stay.
$localMdPath = Join-Path $RootDir 'CLAUDE.local.md'
$importLine = (Read-Text (Join-Path $SetupDir 'CLAUDE.local.md')).Trim()
$localMd = Read-Text $localMdPath
if ($localMd -and ($localMd -split "`r?`n") -contains $importLine) {
    Write-Step $localMdPath 'ok'
} else {
    $text = if ($localMd) { $localMd.TrimEnd() + "`n" + $importLine + "`n" } else { $importLine + "`n" }
    if (-not $DryRun) { Write-TextFile $localMdPath $text }
    Write-Step $localMdPath 'written'
}

# 3. Root PREFERENCES.md, which CLAUDE.md step 0 reads; it points at this folder's file.
Copy-Piece (Join-Path $RootDir 'PREFERENCES.md') 'PREFERENCES.pointer.md'

# 4. The VS MCP AI Server port for GhostBuster.slnx, read when the solution loads.
Copy-Piece (Join-Path $RootDir '.mcp\mcpserver.settings.json') 'mcpserver.settings.json'

# 5. The repo's exclude keeps the private paths out of git status.
$excludePath = Join-Path $RootDir '.git\info\exclude'
$exclude = Read-Text $excludePath
$lines = if ($exclude) { $exclude -split "`r?`n" } else { @() }
$missing = @("/$AgentsName/", '/CLAUDE.local.md', '/.mcp/') | Where-Object { $lines -notcontains $_ }
if (-not $missing) {
    Write-Step $excludePath 'ok'
} else {
    $base = if ($exclude) { $exclude.TrimEnd() + "`n" } else { '' }
    $text = $base + ($missing -join "`n") + "`n"
    if (-not $DryRun) { Write-TextFile $excludePath $text }
    Write-Step ("{0} (+ {1})" -f $excludePath, ($missing -join ', ')) 'written'
}

# 6. The SessionStart hook in .claude/settings.local.json, only while git does not track it.
$settingsPath = Join-Path $RootDir '.claude\settings.local.json'
$tracked = & { $ErrorActionPreference = 'Continue'; git -C $RootDir ls-files -- '.claude/settings.local.json' 2>$null }
if ($tracked) {
    Write-Step ("{0} (tracked by git; hook not installed, see handoff/session-start-setup.md)" -f $settingsPath) 'skipped'
} else {
    $hook = (Read-Text (Join-Path $SetupDir 'session-start-hooks.json')) | ConvertFrom-Json
    $settingsText = Read-Text $settingsPath
    $settings = if ($settingsText) { $settingsText | ConvertFrom-Json } else { New-Object PSObject }
    if (-not $settings.hooks) {
        $settings | Add-Member -NotePropertyName hooks -NotePropertyValue (New-Object PSObject) -Force
    }
    $current = if ($settings.hooks.SessionStart) { $settings.hooks.SessionStart | ConvertTo-Json -Depth 32 -Compress } else { '' }
    $wanted = $hook.SessionStart | ConvertTo-Json -Depth 32 -Compress
    if ($current -eq $wanted) {
        Write-Step $settingsPath 'ok'
    } else {
        $settings.hooks | Add-Member -NotePropertyName SessionStart -NotePropertyValue $hook.SessionStart -Force
        if (-not $DryRun) { Write-TextFile $settingsPath (($settings | ConvertTo-Json -Depth 32) + "`n") }
        Write-Step $settingsPath 'written'
    }
}

if ($DryRun) { Write-Output 'dry run: nothing written' }
