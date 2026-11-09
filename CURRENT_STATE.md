# Current State

Session chronology, user/device scope. **Newest entry at the top**: always prepend, never append.

**Hard cap: the 2 newest days live here, with every session of each.** On session end, prepend today's entry. When that brings in a third day, move every entry of the oldest day into `_archive/CURRENT_STATE/<YYYY-MM-DD>.md`, one file per day, its sessions newest first.

What belongs here and nowhere else: working-tree state, uncommitted lists, local investigations, what a session decided; anything that differs between machines. Tracked project docs (`GhostBuster/.ai/`, `GhostBuster/docs/`) carry the durable truth.

---

## 2026-11-09 (session 2)

### Switch 1 EDEV onboarding; editor upgrade to 6000.3.28f1 started

- Owner has a **Switch 1 EDEV**, used only for deploy tests. SDEV vs EDEV explained in chat (EDEV = retail-like test unit, retail RAM, limited debugging).
- NDI is deprecated; owner downloaded **NNPM** (Nintendo Package Manager). NNPM recommends Unity **6000.3.28f1 LTS** for the Switch module, so the project moves from 6000.3.2f1 (same minor line).
- GhostBuster: fast-forwarded `develop` to `d0859e6bd` (4 commits, no editor/package change) and cut **`nintendo-sdk` (renamed from `chore/unity-6000.3.28f1`)** in the main tree. Nothing committed on it yet.
- Owner is installing 6000.3.28f1 via Hub. The first open must go through Hub with 6000.3.28f1: `scripts/open-unity.ps1` reads `ProjectVersion.txt` and would still launch 6000.3.2f1.
- Owner opened the project in 6000.3.28f1 through Hub. Editor.log: 0 `error CS`; the API Updater timed out on DOTween and Coplay DLLs during the first import (0/4 updated, benign inside a patch line).
- Commits on `nintendo-sdk` (local, not pushed, not merged):
  - `d8132020f` `[Mod] Upgrade Unity 6000.3.2f1 to 6000.3.28f1 LTS`: ProjectVersion, manifest/lock (Input System 1.18.0 to 1.20.1, ProBuilder 6.1.4, AI Navigation 2.0.16 and others; URP stays 17.3.0), URP global settings v10, ProBuilder settings.
  - `d59631523` `[Mod] Reimport texture metas under Unity 6000.3.28f1`: 3,874 png/jpg metas (importer v13, WindowsStoreApps blocks, AssetOrigin dropped, 15 sentinel filterMode/mipBias written out). Owner chose a separate commit.
- `Packages/Coplay/.gitignore` and `ProjectSettings/EditorBuildSettings.asset` show `M` with identical content (stat-only); left alone.
- NNPM Switch package install in progress. EDEV not connected yet: no USB-C data cable at hand (skipped for now). Ignore the "relay box" (HAT-004) claim from lucklessheaven.com; it is an unverified fan site. The portal's EDEV setup page is the source for cabling.
- MSVC C++ tools are now present (VS Community 2022 17.14), so a Windows IL2CPP test build is possible.
- Open: owner checks Play mode, two gamepads in menus (Input System minor bump, D55), and the Steam Windows build; tells the team before merging into `develop`. Then: Switch module plus its NintendoSDK in NNPM. Tracked docs still name 6000.3.2f1 (`.ai/HANDOFF_AUDIO_SYSTEM.md:18`, I-077); I-077 may be fixed by this upgrade, unverified.

## 2026-11-09 (session 1)

### Harness copied from king-of-ashes; Switch and Linux build audits; video codec finding

Session-start: copy the tool harness from `king-of-ashes/.agents.local` into a GhostBuster agents folder and init repo `ittiwatTun/ghost-buster-agents`. GhostBuster at `develop` `271940f2b` throughout; no project file changed this session.

**Harness (done):**
- Folder is `GhostBuster/.agents.local.ghost-buster`, renamed from `agents.local.ghost-buster` at the owner's ask (`f22ccbf`), kept out of git by `GhostBuster/.git/info/exclude` (`/.agents.local.ghost-buster/`, `/CLAUDE.local.md`, `/.mcp/`), not `.gitignore`.
- Copied and adapted:
  - `PREFERENCES.md`, generic rules only, with a scope note: it overrides `CLAUDE.md` only on what it names.
  - `MCP/README.md`, one file for KOA's README, VS_UNITY and ROSLYN.
  - `MCP/scripts/*`, `scripts/open-unity.ps1`, `open-vs.ps1`, `StandardUser.ps1`, `setup-machine.ps1`, `setup/*`, `handoff/session-start-setup.md`.
  - three generic `Memory/` notes.
- Not copied: Gantt, Sprint, Monthly, TownHall, Release, codex, pr records, sdd, openspec, Drive scripts.
- `setup-machine.ps1` installed: `GhostBuster/CLAUDE.local.md` (`@.agents.local.ghost-buster/PREFERENCES.md`), the root `PREFERENCES.md` pointer, `.mcp/mcpserver.settings.json` (VS MCP port 3011), the exclude lines.
  - SessionStart hook skipped: GhostBuster tracks `.claude/settings.local.json`. Three options are in `handoff/session-start-setup.md`; none chosen.
- MCP, local scope under `E:/Itt/Repository/GhostBuster`, absolute paths to `.agents.local.ghost-buster/MCP/scripts`:
  - `gb-unity-editor-mcp`
  - `gb-vs-mcp` (3011)
  - `csharp-roslyn-gb` (`GhostBuster.slnx`)
  - None checked in a live session yet. The `.csproj` files are not generated, so SharpLens loads nothing until Unity regenerates them.
- Launcher dry runs: `E:\UnityHub\6000.3.2f1\Editor\Unity.exe -projectPath "E:\Itt\Repository\GhostBuster" -automated -force-gfx-mt`; VS for `GhostBuster.slnx`.

**Switch devkit audit** (owner's first task), read-only: `research/2026-11-09-switch-devkit-audit.md`.
- No Switch module or Nintendo SDK on the machine. Mono-only, never built IL2CPP.
- No `DISABLESTEAMWORKS` for Switch, so the Steam scripts will not compile.
- 41 unreferenced NuGet DLLs are enabled for every platform (`002e8c74a`).
- PlayerPrefs saves, with save size 0.
- Switch would use the PC render settings by default; heavy lightmaps.
- Owner asked where the knowledge comes from: repo/machine observation, public Unity facts, training knowledge. No NDA docs. [inf] lines need checking once there is portal access.

**Linux build audit**, read-only: `research/2026-11-09-linux-build-audit.md`.
- Blocker: no Linux Build Support module in any editor.
- Risks: the X-ray shader `LitXRay` excludes `glcore`; glyph detection by `XInput` layout name; one Windows-only Steam depot.
- Steam Deck can run the Windows build under Proton.

**Video codec finding** (grew out of the Linux audit, extended by the owner):
- All 14 shipping clips in `Assets/Recordings` are H.264 (`avc1`).
- Unity's Windows player has no H.264 decoder of its own. Verified in `UnityPlayer.dll` 6000.3.2f1: it calls Media Foundation, embeds libvpx (`WebM Project VP8 Decoder v1.3.0`), has no openh264 or ffmpeg, and carries the "Media Foundation is not installed" error string.
- So H.264 fails on Windows N/KN without the Media Feature Pack, probably on Linux, and possibly under Proton. Related to the open I-032 and I-029 Media Foundation crashes.
- No handler reads `VideoPlayer.errorReceived`, so a failure reads as a prepare timeout.
- First Linux report overstated "Linux cannot play H.264" as documented. Corrected to a risk with Unity 6.3 doc citations (`a4eacf1`).

**Open:**
- Proposed project change, waiting for the owner's go-ahead:
  - transcode the 14 clips to VP8
  - log `errorReceived` in `AreaVideoSceneHandler`, `IntroSceneHandler`, `GuidePanelUI`, `StageDetailUI`
  - add a `KNOWN_ISSUES` entry
  - test on Windows N, Linux and Deck, plus I-032 under D3D12
  - Would run in a worktree per `CLAUDE.md`.
- Switch audit: 9 open questions at the end of its report.
- Linux audit: 4 open questions (native vs Proton-only, test device, backend, video format).
- SessionStart hook: pick an option in `handoff/session-start-setup.md`.
- This repo is not pushed. `origin` is `ittiwatTun/ghost-buster-agents`, rewritten to ssh by a global `insteadOf`.
