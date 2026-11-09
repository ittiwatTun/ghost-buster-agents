# Handoff: session start on any machine

Session start is the `/session-start` command the owner types, plus the private files that make a GhostBuster session load this folder. This repo tracks every piece; the ones that must sit outside it are installed once per machine by `scripts/setup-machine.ps1`.

## Tracked here, installed there

| Untracked target (per machine) | Tracked source | How |
| :-- | :-- | :-- |
| `%USERPROFILE%\.claude\commands\session-start.md` | `setup/session-start.md` | copied |
| `<GhostBuster>\CLAUDE.local.md` | `setup/CLAUDE.local.md` | its import line is added; other lines stay |
| `<GhostBuster>\PREFERENCES.md` (already gitignored by the project) | `setup/PREFERENCES.pointer.md` | copied |
| `<GhostBuster>\.mcp\mcpserver.settings.json` | `setup/mcpserver.settings.json` | copied; VS MCP AI Server port 3011 |
| `<GhostBuster>\.git\info\exclude` | — | `/.agents.local.ghost-buster/`, `/CLAUDE.local.md`, `/.mcp/` added |
| `<GhostBuster>\.claude\settings.local.json` `hooks.SessionStart` | `setup/session-start-hooks.json` | merged, **only while git does not track the file** |

To change a piece, edit its tracked source, commit, and run the script again. Never hand-edit an installed copy.

## The SessionStart hook is not installed

GhostBuster tracks `.claude/settings.local.json` (it holds the team's permissions and the comment-standard hook), so the script prints `skipped` for it. Writing the hook there would put this machine's launcher into every commit that touches that file. Options, none taken yet:

1. Run the launchers by hand when needed (current state).
2. The team untracks `.claude/settings.local.json` (`git rm --cached`, add it to `.gitignore`); the script then installs the hook on its next run.
3. A user-scope hook in `~/.claude/settings.json` that runs only when `$CLAUDE_PROJECT_DIR` is the GhostBuster root. It costs a PowerShell start in every project's session.

## Install

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File <GhostBuster>\.agents.local.ghost-buster\scripts\setup-machine.ps1 -DryRun
powershell -NoProfile -ExecutionPolicy Bypass -File <GhostBuster>\.agents.local.ghost-buster\scripts\setup-machine.ps1
```

Each line is `ok`, `written` or `skipped` and names its target. `VarisDev1`, 2026-11-09: everything written, the hook skipped.

## Verify

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File <GhostBuster>\.agents.local.ghost-buster\scripts\open-unity.ps1 -DryRun
powershell -NoProfile -ExecutionPolicy Bypass -File <GhostBuster>\.agents.local.ghost-buster\scripts\open-vs.ps1 -DryRun
```

`VarisDev1`, 2026-11-09: `would start E:\UnityHub\6000.3.2f1\Editor\Unity.exe -projectPath "E:\Itt\Repository\GhostBuster" -automated -force-gfx-mt (elevated=True)` and `would start Visual Studio for GhostBuster.slnx (elevated=True)`. Real runs log to `GhostBuster/Logs/open-unity.log` and `open-vs.log`.

`-automated` makes every Editor modal dialog and save prompt answer Cancel unseen, for the owner's own clicks too. An Editor tool must confirm in its own window, never through `EditorUtility.DisplayDialog`.

## Not included

The MCP servers are registered by `MCP/README.md` § Setup on another machine; they are keyed to local paths.
