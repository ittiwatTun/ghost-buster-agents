# MCP

The private MCP servers a Claude Code session started in `GhostBuster` gets on this machine (`VarisDev1`), and how to set up another machine the same way. Copied 2026-11-09 from the king-of-ashes harness (`king-of-ashes/.agents.local/MCP/`, files `README.md`, `VS_UNITY.md`, `ROSLYN.md`), cut down to one project. Never put any of it in a tracked GhostBuster file.

| File | Holds |
| :-- | :-- |
| `README.md` | This file |
| `scripts/wait-unity-mcp.ps1`, `scripts/wait-vs-mcp.ps1` | The stdio wrappers the `gb-` entries run |
| `scripts/wait-unity-tests.ps1`, `scripts/run-timed.ps1`, `scripts/TestDurations.psm1`, `test-durations.json` (per machine, gitignored) | Long-run watchers, run through Monitor |

## Servers

| Server | Scope | Backend | Serves once |
| :-- | :-- | :-- | :-- |
| `gb-unity-editor-mcp` | local, `~/.claude.json` under `E:/Itt/Repository/GhostBuster` | `unity mcp` on the GhostBuster Editor (project has `com.unity.pipeline` 0.6.0-exp.1) | `unity status` reads the project `ready` |
| `gb-vs-mcp` | local, same | Visual Studio on `GhostBuster.slnx`, MCP AI Server extension, `http://localhost:3011/sdk/` | the port answers any HTTP status |
| `csharp-roslyn-gb` | local, same | `sharplens` (`SharpLensMcp` 1.6.3) on `GhostBuster.slnx` | the `.csproj` files exist |
| `github`, `google-sheets`, `tumrai` | user | as set for king-of-ashes | — |

Port 3011 keeps clear of king-of-ashes' 3009 (u) and 3010 (mo). The extension reads it from `GhostBuster/.mcp/mcpserver.settings.json` when the solution loads; `scripts/setup-machine.ps1` writes that file from `setup/mcpserver.settings.json`, and `.git/info/exclude` hides it. One devenv per solution; a settings file added after devenv started needs a devenv restart.

### Why wrappers

Claude Code spawns MCP servers about 2 s after start. An http entry gets one 5 s probe and is never retried, and `unity mcp` answers with 0 tools while no Editor is ready and never sends `list_changed`. So:

- `wait-vs-mcp.ps1 -Url <endpoint>` is a stdio server that waits until the endpoint answers, then relays each stdin line as a POST and writes each reply back as one line. It answers `server/discover` itself.
- `wait-unity-mcp.ps1 -ProjectPath <path from GhostBuster root>` holds the client's `initialize` until `unity status` reads the project ready, then starts `unity mcp --project-path <full path>` on the same stdio.
- Both wait at most `MCP_TIMEOUT` ms (`120000` from `~/.claude/settings.json` here; king-of-ashes uses `600000` in its gitignored settings, which GhostBuster cannot do without editing its tracked `settings.local.json`). Both log to `GhostBuster/Logs/wait-*.log`, capped at 200 KB.

## Setup on another machine

1. Clone this repo to `<GhostBuster>\agents.local.ghost-buster`.
2. Prerequisites: Windows PowerShell 5.1, `unity` CLI on `PATH`, the Unity Editor in `ProjectSettings/ProjectVersion.txt`, Visual Studio 2022 with MCP AI Server, .NET SDK 8+, `dotnet tool install -g SharpLensMcp`.
3. `powershell -NoProfile -ExecutionPolicy Bypass -File <GhostBuster>\agents.local.ghost-buster\scripts\setup-machine.ps1` (`handoff/session-start-setup.md`).
4. Register the servers from the GhostBuster root (local scope is keyed on that directory; paths absolute):
   ```powershell
   Set-Location <GhostBuster>
   $r = (Resolve-Path .).Path -replace '\\', '/'
   $w = "$r/agents.local.ghost-buster/MCP/scripts"
   claude mcp add -s local gb-unity-editor-mcp -- powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$w/wait-unity-mcp.ps1" -ProjectPath .
   claude mcp add -s local gb-vs-mcp           -- powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$w/wait-vs-mcp.ps1" -Url http://localhost:3011/sdk/
   claude mcp add -s local csharp-roslyn-gb -e "DOTNET_SOLUTION_PATH=$r/GhostBuster.slnx" -e SHARPLENS_TIMEOUT_SECONDS=120 -- sharplens
   ```
   The server name comes before `-e`.
5. Open the project in Unity once with Visual Studio as the external script editor, so the `.csproj` files `GhostBuster.slnx` lists exist (git ignores them). Until then `csharp-roslyn-gb` loads nothing.
6. Restart Claude Code in the GhostBuster root. A server added mid-session does not reach that session.

Undo: `claude mcp remove -s local <name>` for each, from the GhostBuster root.

## Verify

- `claude mcp get <name>` from the GhostBuster root reads local scope and `✔ Connected`.
- `csharp-roslyn-gb` `health_check`: a loaded solution, `partial: false`, empty `loadFailures`. Does SharpLens 1.6.3 load an `.slnx`? Not yet checked on this machine (2026-11-09: the `.csproj` files did not exist).
- With the Editor and VS open: `curl -s -o /dev/null -w '%{http_code}\n' http://localhost:3011/sdk/` (`405` up, `000` nothing), `unity status --json` (`ready`).

## Using them

- `~/.claude/CLAUDE.md` § C# tooling applies with these names: SharpLens for symbol queries (zero-based coordinates, absolute `filePath`, `sync_documents` after each `.cs` edit), `gb-vs-mcp` only for Roslyn refactors and the debugger, and the `RenameSymbol` rules there.
- The Unity recompile stays the compile gate.

## Diagnosing

| Question | Command |
| :-- | :-- |
| Does the VS port answer? | `curl -s -o /dev/null -w '%{http_code}\n' http://localhost:3011/sdk/` |
| Which devenv holds it? | `netsh http show servicestate view=requestq`, the `ID:` above `HTTP://LOCALHOST:3011/SDK/` |
| Which solution does each devenv have? | `Get-Process devenv \| Select-Object Id, StartTime, MainWindowTitle` (titles, never command lines) |
| Is the Editor ready? | `unity status --json` |
| Is a wrapper waiting? | `GhostBuster/Logs/wait-vs-mcp.log`, `wait-unity-mcp.log` |
| Launcher decisions | `scripts/open-unity.ps1 -DryRun`, `scripts/open-vs.ps1 -DryRun`; logs `GhostBuster/Logs/open-unity.log`, `open-vs.log` |
| SharpLens "no solution loaded" | the `.csproj` files did not exist at spawn; open Unity, then `/mcp` reconnect |

## Waiting on a long run

Never wait blind, and never poll `test_status`: it stays `running` forever when the test framework dies mid-run. Both watchers run through **Monitor**, print a `PROGRESS` line every 60 s, and always exit. A `PROGRESS` line whose log stopped moving is read at once. `TestDurations.psm1` keeps each suite's last wall time in `test-durations.json`; a run's budget is twice that plus a minute, 1800 s when never measured.

**Unity tests:** `editor_focus`, then start the watcher through Monitor, then `test_run`. Check `scene_list_open` for `isDirty` first: an Editor launched with `-automated` answers the test runner's save prompt with Cancel unseen, so a dirty scene drops the run before it starts (exit `3`). A dirty scene is the owner's; ask before saving.

```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w agents.local.ghost-buster/MCP/scripts/wait-unity-tests.ps1)" -ProjectPath .
```

Exit codes: `0` passed, `1` a test failed, `2` aborted, `3` accepted but never started, `4` no request or nothing matched, `5` stalled, `6` cancelled, `7` past the budget. `-Attach` joins a run in flight. A crashed run strands `Assets/InitTestScene<guid>.unity` (`STRANDED` line): reopen the working scene, then delete the stranded one.

**Any other long command** (a build, `dotnet build`): `scripts/run-timed.ps1` through Monitor. It kills the process tree past the budget (exit `124`), otherwise exits with the command's code, and records the wall time.

```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w agents.local.ghost-buster/MCP/scripts/run-timed.ps1)" -Key gb:editor-build -TailLines 3 -WorkingDirectory . -Command 'dotnet build Assembly-CSharp-Editor.csproj -v q -nologo'
```
