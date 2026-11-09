# Current State

Session chronology, user/device scope. **Newest entry at the top**: always prepend, never append.

**Hard cap: the 2 newest days live here, with every session of each.** On session end, prepend today's entry. When that brings in a third day, move every entry of the oldest day into `_archive/CURRENT_STATE/<YYYY-MM-DD>.md`, one file per day, its sessions newest first.

What belongs here and nowhere else: working-tree state, uncommitted lists, local investigations, what a session decided; anything that differs between machines. Tracked project docs (`GhostBuster/.ai/`, `GhostBuster/docs/`) carry the durable truth.

---

## 2026-11-09 (session 1)

### Harness copied from king-of-ashes; Switch devkit research started

Session-start: copy the tool harness from `king-of-ashes/.agents.local` into `GhostBuster/.agents.local.ghost-buster`, init repo `ittiwatTun/ghost-buster-agents`.

**Done:**
- Copied and adapted: `PREFERENCES.md` (generic rules only; scope note against `CLAUDE.md`), `MCP/README.md` (one file for KOA's README, VS_UNITY and ROSLYN), `MCP/scripts/*` (wrappers resolve the GhostBuster root), `scripts/open-unity.ps1`, `open-vs.ps1`, `StandardUser.ps1`, `setup-machine.ps1`, `setup/*`, `handoff/session-start-setup.md`, three generic `Memory/` notes.
- Not copied: Gantt, Sprint, Monthly, TownHall, Release, codex, pr records, sdd, openspec, Drive scripts, KOA ledgers' content.
- `setup-machine.ps1` run: `GhostBuster/CLAUDE.local.md`, root `PREFERENCES.md` pointer, `.mcp/mcpserver.settings.json` (port 3011), `.git/info/exclude` written. SessionStart hook skipped: GhostBuster tracks `.claude/settings.local.json` (options in `handoff/session-start-setup.md`). GhostBuster `git status` clean after.
- MCP registered local scope under `E:/Itt/Repository/GhostBuster`: `gb-unity-editor-mcp`, `gb-vs-mcp` (3011), `csharp-roslyn-gb` (`GhostBuster.slnx`; `.csproj` files not generated yet).

- First task from the owner: research and audit the preparation to add the Nintendo SDK and build to the devkit. Done read-only: `research/2026-11-09-switch-devkit-audit.md`. Key claims re-checked by hand (defines, quality default, save size, modules, Mono backend, unreferenced NuGet DLLs, `Application.Quit`).

- Linux build audit, read-only: `research/2026-11-09-linux-build-audit.md`. Blockers: no Linux Build Support module, all 14 shipping video clips are H.264 (Linux plays VP8 only).

**Open:**
- Linux audit: 4 open questions (native vs Proton-only, test device, backend, video format).
- Switch audit: 9 open questions for the owner at the end of the report; no project change made.
- Repo not pushed; remote `origin` set.
