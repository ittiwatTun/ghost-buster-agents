# User Preferences

User/device scope for GhostBuster. Lives at `GhostBuster/agents.local.ghost-buster/`, its own private git repo (`ittiwatTun/ghost-buster-agents`), excluded from the project repo by `GhostBuster/.git/info/exclude`. Loaded by `GhostBuster/CLAUDE.local.md`, and pointed at by the gitignored root `PREFERENCES.md` that `CLAUDE.md` Read Order step 0 reads. Set up 2026-11-09 from the king-of-ashes harness (`king-of-ashes/.agents.local`).

All paths in this file are relative to this folder unless they start with `GhostBuster/`.

**Scope against `CLAUDE.md`.** `CLAUDE.md` says this file overrides its default workflow wherever the two conflict. Only the rules written below override it. Everything else in `CLAUDE.md` (worktree then merge to main tree, commit style `[Mod]`/`[Fix]`/`[Add]`, the "Update These After Meaningful Work" list, the online rule) stays as written.

## About the user

- Unity C# developer on GhostBuster (co-op ghost hunting, Mirror online, Steam).
- Writes short, terse prompts in English or Thai; answer in the language of the prompt.

## Working style

- **Status indicators ✅ / ❌ are preferred** in tables, lists and status columns. Don't add other emoji unless asked.
- **A review report in chat is a short summary only**: verdict, counts, one line per Minor and above, open questions, record path. The full findings go in a file.
- **Never publish a claude.ai Artifact unless the owner asks for one by name.** A report, plan or research note stays a local file in this folder, and its short summary goes in chat.

## Working rules

### Editing

- **Never hard-wrap prose.** One paragraph, one list item, one line; the IDE wraps it. Code fences and tables keep their lines.
- **Never rewrite files with a shell text tool**: no `sed -i`, `awk`, or shell read/write loops. Git Bash normalizes CRLF and appends trailing newlines. Use `Edit`, or `perl -0777 -i -pe` for a mechanical edit across many files, then prove it with `git diff --numstat`. Non-ASCII in a perl replacement: see `Memory/perl-non-ascii-replacement.md`.
- **Do not write Python through a bash heredoc.** Write the script with `Write`, then run `python <path>`.
- **A script file written for this machine is Windows PowerShell 5.1 `.ps1`**, never `.sh` or `.cmd`. Run it as `powershell.exe -NoProfile -ExecutionPolicy Bypass -File <path>`. Keep it ASCII: 5.1 reads a BOM-less script as ANSI. One-off commands in the Bash tool stay bash.

### Commits

- **Commit every unit of work as soon as it builds**, one logical change per commit. Commits stay local.
- **Never push a branch and never merge a PR on GitHub. The owner does both.** Report the branches and SHAs ready to push. The local merge into the main tree that `CLAUDE.md` Working Rule 1 asks for is not a push and stays allowed.
- **Pull the base before cutting a branch**: `git fetch origin`, fast-forward local `develop`, then branch.
- **Commit only your own hunks.** The owner may run several sessions on one working tree. Never `checkout`, `stash` or `reset` a file another session may hold; commit with `git commit -- <paths>`.

### Verifying

- **Verify before acting on a review finding, and before defending your own claim.** Read the cited file first; subagent output cites plausible lines that do not match.
- **Cite a SHA or re-measure; never carry a bare figure forward.**
- **Run only the tests a change affects**, never the whole play-mode suite unless the owner asks.
- **A long run is observed every minute, never waited on.** Unity tests go through `MCP/scripts/wait-unity-tests.ps1`, other long commands through `MCP/scripts/run-timed.ps1`, both started through Monitor. See `MCP/README.md` § Waiting on a long run.

## Records this folder owns

| Path | Holds |
| :-- | :-- |
| `PREFERENCES.md` | This file: durable user context. |
| `CURRENT_STATE.md` | Session chronology, 2 newest days only, newest prepended. Rotation rule in its header. |
| `POSTIT.md` | One-line surprises, newest on top. |
| `BACKLOG.md` | Deferred work the owner wants kept: what, why deferred, what unblocks it. |
| `MCP/` | This machine's private MCP setup for GhostBuster: `README.md` (servers, setup, verify, long runs) and `scripts/` (the `gb-` wait wrappers, the long-run watchers). |
| `scripts/` · `setup/` | `open-unity.ps1`, `open-vs.ps1`, `StandardUser.ps1`, `setup-machine.ps1`, and the tracked sources it installs (`handoff/session-start-setup.md`). |
| `Memory/` | The only memory location. Never write memory to `~/.claude/`, `%APPDATA%` or any other machine path. |
| `research/` | Investigations, one file or folder each, dated. |
| `handoff/` | Session handoffs and setup guides. |
| `_archive/` | What left a live ledger (rolled-off `CURRENT_STATE` days, closed backlog items). |
| `temp/` | Scratch and worktrees. Gitignored. |

**`temp/` replaces the harness session scratchpad.** Scratch files go to `temp/scratchpad/<session-id>/`. Never `/tmp` or `%TEMP%`. Never scratch inside the GhostBuster tracked tree: a file under `Assets/` gets imported by Unity.

## Local-machine paths

- **GhostBuster repo**: `E:\Itt\Repository\GhostBuster` (`git@github.com:Varisoft/GhostBuster.git`, base `develop`). `CLAUDE.md` names the main tree `C:/Varisoft/GhostBuster-POC` and worktrees under `.claude/worktrees/`; on this machine the main tree is `E:\Itt\Repository\GhostBuster`.
- **Unity Editor**: 6000.3.2f1 at `E:\UnityHub\6000.3.2f1\Editor\Unity.exe` (Hub secondary install path).
- **king-of-ashes harness** (the source of this setup): `E:\Itt\Repository\king-of-ashes\.agents.local`. Its PM tooling (Gantt, Sprint, Monthly, TownHall, Release, codex, pr records) was not copied.
- **Git identity**: GhostBuster commits as `Ittiwat Tuntithavorn <ittiwat.t@varisoft.com>`.

## Tooling notes

- **The private MCP servers here are `gb-unity-editor-mcp`, `gb-vs-mcp` and `csharp-roslyn-gb`**, local scope in `~/.claude.json` under the GhostBuster path. Where `~/.claude/CLAUDE.md` § C# tooling names `csharp-roslyn-u` / `vs-u-mcp`, the GhostBuster equivalents are these. Never add them to a tracked file. Setup and diagnosis: `MCP/README.md`.
- **GhostBuster also has the CoplayDev `UnityMCP` package** (`com.coplaydev.unity-mcp`) that project docs may name as `mcp__UnityMCP__*`; it is the project's, not part of this setup.
- **The Editor and Visual Studio launchers exist but the SessionStart hook is not installed**: GhostBuster tracks `.claude/settings.local.json`, so a hook there would leak into commits. Run `scripts/open-unity.ps1` and `scripts/open-vs.ps1` by hand, or see `handoff/session-start-setup.md` for the options.
- **Driving the Unity Editor**: `unity` CLI on `PATH` (`%LOCALAPPDATA%\Unity\bin\unity.exe`), the project has `com.unity.pipeline` 0.6.0-exp.1. Never launch the Editor from the agent shell except through `scripts/open-unity.ps1`. A modal dialog blocking the Editor: `Memory/unity-modal-relaunch-automated.md`.
