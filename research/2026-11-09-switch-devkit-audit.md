# GhostBuster → Nintendo Switch devkit readiness audit

2026-11-09, read-only. Repo `E:\Itt\Repository\GhostBuster` @ `develop` `271940f2b`, Unity 6000.3.2f1. Nothing was edited.

Markers: ✅ ready · ⚠ needs work · ❌ blocker. **[obs]** = seen on this machine or in the repo. **[inf]** = inferred from public Unity/Switch knowledge; check it against Nintendo's NDA docs.

Re-checked by the main session after the audit agent: ✅ `Nintendo Switch` defines lack `DISABLESTEAMWORKS` (`ProjectSettings.asset:842`) · ✅ `m_PerPlatformDefaultQuality: Nintendo Switch: 1` = PC (`QualitySettings.asset:124`) · ✅ `switchUserAccountSaveDataSize: 0` (`:670`) · ✅ 6000.3.2f1 PlaybackEngines = Android, Metro, iOS, Windows only · ✅ `scriptingBackend: Standalone: 0` (Mono) · ✅ no `.cs`/asmdef references McpPlugin/SignalR/ReflectorNet · ✅ `TitleSceneUI.cs:268` `Application.Quit()` · PlayerPrefs: 86 lines in 14 project files + Mirror's `DeviceAuthenticator` (grep `PlayerPrefs`, comments included).

## Bottom line

- Nothing Nintendo is installed on this machine: no Switch module, no SDK, no tools.
- The game has never been built with IL2CPP, and Switch only supports IL2CPP.
- The code is in fair shape:
  - Steam sits behind `IOnlineTransportProvider`.
  - When no provider is registered, online play is hidden.
  - Local co-op runs on `NullTransport` with no socket.
- One hard compile blocker: `DISABLESTEAMWORKS` is not defined for Switch.
- Biggest content risks: lightmap memory and the cost of the PC renderer.

## 1. Machine readiness

- ❌ **No Switch build module in any installed editor [obs].** Unity Hub installs editors to `E:\UnityHub`.
  - Installed: 6000.0.75f1, **6000.3.2f1** (the project's), 6000.3.8f1, 6000.3.16f1.
  - Every one has only `AndroidPlayer`, `MetroSupport`, `iOSSupport` and `windowsstandalonesupport`.
- ❌ **No Nintendo SDK or tooling [obs].** No matching env vars, no `C:\Nintendo*` folders, no Program Files entries, no `HKLM`/`HKCU\SOFTWARE\Nintendo` keys, no uninstall entries.
- ✅ **Windows IL2CPP player variation is present** in 6000.3.2f1 [obs]. It can serve as a cheap IL2CPP test, but `.ai/CURRENT_STATE.md:132` notes the MSVC C++ workload was missing (2026-09).
- ⚠ **No `Library/` in this checkout [obs]**, so the git-sourced packages (Steamworks.NET, Coplay, unity-mcp, `com.unity.pipeline`) could not be inspected.
- ⚠ **Editor version [inf].**
  - The Switch module must match the editor version exactly.
  - 6000.3.2f1 is an early 6.3 patch with known bugs here: I-077, and the HTTP/2 bug noted at `BugReportSender.cs:134`.
  - 6000.3.8f1 and 6000.3.16f1 are already installed.
  - "Nintendo Switch" and "Nintendo Switch 2" are separate groups (`ProjectSettings.asset:842-843`), so separate modules and SDKs.

## 2. Project configuration

- ⚠ **The `switch*` player keys are untouched Unity defaults [inf].**
  - `switchApplicationID: 0x01004b9000490000` is a placeholder (`:591`).
  - Title, publisher, icons and NMETA are empty.
  - Save data size and journal size are 0 (`:670-671`).
  - NPad styles 22, count 8, touch on (`:704-708`).
  - Local communication IDs are empty.
- ❌ **Scripting backend is Mono** (`Standalone: 0`, `:858-860`), with no Switch entry. Switch is IL2CPP-only [inf].
- ✅ Other settings:
  - .NET Standard 2.1 (`:951`)
  - `allowUnsafeCode: 1`, incremental GC
  - Linear color space
  - NVN is the only Switch graphics API [inf].
- ⚠ `activeInputHandler: 2` (Both). Legacy `Input` is used only by Mirror's GUIConsole, ToggleHotkey and RemoteStatistics, and by TempAssets demos.
- ❌ **Defines** (`:835-853`):
  - Switch has `UNITY_POST_PROCESSING_STACK_V2;UNITY_MCP_READY;DOTWEEN` and no `DISABLESTEAMWORKS`.
  - Standalone still carries stale Photon `FUSION*` defines.
- Identity: `productName: Catch Me Wooo Demo`, `bundleVersion: 0.4.6.1`, `com.varisoft.catchmewooo`.
- ⚠ **Build scenes:** 22, all enabled, including dev scenes (`NetSpikeScene`, `PlaygroundScene`) and the 7 PvP scenes. The only build profile is `Assets/Settings/Build Profiles/Windows.asset`.
- **Quality and URP:**
  - ⚠ Switch defaults to the **PC** quality level → `PC_RPAsset`.
  - ✅ `Scripts/Settings/GraphicsPreset.cs` already swaps whole RP assets at runtime (`PC_Low`, `PC_Medium`, `PC_High`), which is a ready hook for a Switch tier.
  - ⚠ `PC_RPAsset` [inf heavy]: HDR, MSAA 2×, depth and opaque textures, 2048 shadows with 4 cascades to 100 m, soft shadows, 8192 additional-light shadow atlas, cookies.
  - ⚠ `PC_Renderer`: Forward+, native render pass, FreeOutline, Darkroom, Decals, **full-res SSAO**.
  - Lightest today is `PC_Low`: scale 0.8, 1 cascade, 1024 shadows, 40 m, HDR still on.
- **Packages:**
  - ❌ `com.rlabrecque.steamworks.net` (`release/2025.164.1`): its native plugin is desktop only.
  - ⚠ `com.coplaydev.coplay` (`#beta`) and `com.coplaydev.unity-mcp` (`#main`) track moving branches; confirm they are editor-only.
  - ⚠ `com.unity.pipeline 0.6.0-exp.1` (with glTFast and OpenImageIO) is experimental; verify it does not break the Switch target.
  - ⚠ `com.unity.postprocessing 3.5.1` is unused under URP.
  - ✅ UniTask, Input System 1.18.0, Cinemachine 3.1.6, AI Navigation, URP 17.3, Timeline, uGUI, Burst, Collections and linework-lite should be fine [inf].
  - ✅ ParrelSync, Recorder and ProBuilder are editor-only.

## 3. Code and plugin blockers

- ⚠ **`Assets/Plugins/NuGet/` (18 MB, 41 DLLs)** contains McpPlugin, SignalR client, Roslyn, Microsoft.Extensions.*, R3, ReflectorNet, System.Text.Json.
  - They are enabled for every player platform, Switch included.
  - Nothing references them [obs].
  - They came in with commit `002e8c74a` (2026-07-02, "Mass Furniture Area1 Stage1"), which looks accidental.
  - Under IL2CPP they risk AOT and linker errors and add size [inf]. Remove them or make them Editor-only.
- ✅ No other native plugins under `Assets/`. DOTween runtime is fine; DOTweenEditor and Mirror's Cecil are editor-only.
- ❌ **Steam compile break on Switch.**
  - `FizzySteamworks.asmdef` is limited to desktop platforms, which is correct.
  - But `SteamOnlineTransport.cs`, `SteamBootstrap.cs` and `SteamInvite.cs` rely on `#if !DISABLESTEAMWORKS`, and nothing defines that for Switch.
  - So `using Steamworks;` / `using Mirror.FizzySteam;` compile into Assembly-CSharp against missing assemblies → compile errors.
  - Fix: add `DISABLESTEAMWORKS` to the Switch defines or a Switch build profile.
- ✅ **Steam architecture is otherwise good:**
  - `IOnlineTransportProvider` (`Net/OnlineTransport.cs`); only `SteamOnlineTransport` registers, via `[RuntimeInitializeOnLoadMethod]`.
  - With no provider, `TitleSceneUI.cs:67` hides Join and `:172` blocks online.
  - The Fizzy transport is created at runtime; no scene or prefab serializes it.
- ⚠ **Steam-flavoured scripts that still run on every platform:**
  - auto-spawned: `SteamBootstrap`, `SteamInputDiagnostics` (F10, `Keyboard.current`), `RemotePlayDeviceReconnector` (may help Joy-Con reconnect; review it)
  - also: `RemotePlayInviteButton`
  - `LobbyFlowController`, `RoomPanelUI`, `CrashReporting` and `BugReportSender` reference `SteamBootstrap` / `SteamInvite`.
- **Networking:**
  - ✅ Local sessions run `StartHost()` on `NullTransport` with `listen=false`, so they need no socket.
  - Direct/LAN (`KcpTransport` on `PersistentRoot.prefab`) is debug-gated (`TitleSceneUI.cs:222`, `RoomPanelUI.cs:126` `LanMode`).
  - ⚠ kcp2k opens raw UDP sockets.
  - [inf] Retail Switch online needs Nintendo's services (NEX/NSO), and local wireless needs LDN. **The first devkit build should be Local only.**
- ⚠ **Saves:**
  - All persistence is `PlayerPrefs`: SettingsData 36, StageRecords 13, StageProgress 12, GuideProgress 7, TutorialProgress 6, plus 9 one-site files.
  - `PlayerPrefs.Save()` runs on every setter.
  - [inf] Switch needs user-account save data with a size and journal, and limits write frequency. Wrap persistence in a save service with batched commits.
- ⚠ **Desktop-only systems:**
  - `CrashNotifier` (lock file, temp folders)
  - `BugReportSender` (log tail, Discord webhook via `HttpClient`)
  - `LogRedactor` (`Environment.UserName` / `MachineName`)
  - Disable them on Switch [inf].
- **Input:**
  - ✅ Input System 1.18.0. Gameplay actions bind generic `<Gamepad>/…` only, menus go through `UIInputRouter`, and join uses `PlayerInputManager.JoinPlayer`.
  - ⚠ 14 `Keyboard.current` sites, mostly dev tools. `DebugMenuUI` F1 is not gated on development builds.
  - ⚠ Intro skips read `Gamepad.all`.
  - ⚠ `GamepadGlyphs.cs:49-57` detects Switch/JoyCon, but only Xbox and PS art exist, and `LobbyControllerKind.Switch` is never used.
  - [inf] A single sideways Joy-Con lacks the right stick and triggers the bindings use.
  - [inf] Player join must fit Nintendo's controller-support applet. Handheld mode and HOME suspend need handling; there is no suspend/resume handling now.
- ⚠ **Platform UI:**
  - `Application.Quit` at `TitleSceneUI.cs:268` and `TutorialExitGate.cs:64`
  - display settings in `SettingsData.cs`: resolutions (`:31`), window modes (`:22`), `Screen.SetResolution` (`:299`), uncapped fps (`:41`)
  - `UrlButton.cs:91` `Application.OpenURL`
  - All need hiding or replacing on Switch [inf].
- ✅ Already console-friendly:
  - `ImageFilePicker` is Win-guarded.
  - Canvases scale from 1920×1080; check handheld legibility.
  - Languages are EN and JA.
  - No `Reflection.Emit` or `Type.GetType` in project scripts.
  - No `link.xml` yet; the first IL2CPP build may need one for Mirror, UniTask or DOTween [inf].

## 4. Build pipeline

- ✅ `Assets/_Project/Editor/Build/SteamBuild.cs` is a clean template:
  - menus `GhostBuster/Steam/Build Windows x64 (Mono|IL2CPP)`, plus a CLI entry with `-il2cpp`
  - output `Build/Steam/Windows64/`
  - A `SwitchBuild.cs` would follow the same shape: `BuildTarget.Switch`, IL2CPP, Switch defines, a shipping scene list, NSP/NSPD output.
- ⚠ No CI. `tools/` holds only Python checkers.
- ⚠ IL2CPP has never been built (`.ai/CURRENT_STATE.md:132`).

## 5. Performance and size risk

- Assets total 4.0 GB: Scenes 1.9 GB, ThirdParty 990 MB, TempAssets 489 MB. 22 of 121 scenes are in the build. No Addressables.
- ❌/⚠ **Lightmaps:** max 2048, with no Switch overrides (0 metas with `buildTarget: Switch`).

  | Stage | Lightmap sets | Baked data on disk |
  | :-- | --: | --: |
  | Area1Stage1 | 27 | 257 MB |
  | Area1Stage3 | 50 | 499 MB |
  | Area1Stage4 | 47 | 494 MB |
  | Area1Stage5 | 54 | 530 MB |
  | Area1Stage2 / 6 | 0 | 0 |

  Estimate [inf]: roughly 0.5–0.9 GB of GPU memory per stage, against about 3.2 GB of usable shared RAM on Switch 1. Needs Switch import overrides, fewer and denser atlases, or no directional maps.
- ⚠ **Lights:** 517 `Light` components in `_Project` prefabs (331 Realtime, 186 Mixed, 304 with soft shadows). Related open issues: I-026 (additional-light shadow cost) and I-072 (FPS degrades over long sessions; never profiled).
- ⚠ **VFX and textures:** 118 ParticleSystems (CFXR, Epic Toon FX). 202 textures over 4 MB on disk. 3 `_Project` textures have max size ≥4096.
- ⚠ **Renderer [inf]:** needs its own `Switch_RPAsset` and renderer: no SSAO, 1 cascade, small shadow atlas, render scale about 0.7–0.8, MSAA off, maybe HDR off.

## Preparation checklist (ordered)

1. **Nintendo access:** developer portal and NDA, devkit, NintendoSDK, Nintendo Dev Interface / Target Manager, Application ID. Decide **Switch 1 or Switch 2** [inf].
2. **Editor:** confirm which 6000.3 patch has a Switch module available. Consider upgrading off 6000.3.2f1 *before* installing the module. Install the matching module and set the SDK environment per Nintendo's docs [inf].
3. **IL2CPP on Windows first:** install the MSVC C++ workload, run `GhostBuster/Steam/Build Windows x64 (IL2CPP)`, and fix AOT/linker issues (add a `link.xml`).
4. **Dead plugins:** delete or Editor-restrict `Assets/Plugins/NuGet/*`. Drop `com.unity.postprocessing`. Confirm Coplay, unity-mcp and pipeline are editor-only and pin their git refs.
5. **Defines:** add `DISABLESTEAMWORKS` for Switch, ideally in a Switch Build Profile. Remove the stale `FUSION*` defines. Optionally add a `PLATFORM_CONSOLE` define.
6. **Isolate Steam:** gate the `SteamBootstrap`, `SteamInputDiagnostics` and `RemotePlayInviteButton` spawns and the Steam-only UI. The Switch target must compile with zero `Steamworks` / `Mirror.FizzySteam` references.
7. **Disable desktop-only systems on Switch:** bug and crash reporting, `UrlButton`, the exit buttons, display settings, F-key debug tools.
8. **Save data:** a save service over Switch user-account save data, with size, journal and startup user set. Batch writes and migrate the PlayerPrefs sites behind it.
9. **Networking:** the first devkit build is Local only. Make the LAN/KCP path unreachable. Decide separately on NSO/NEX (a new `IOnlineTransportProvider`), LDN, or no online.
10. **Input:**
    - verify NPad maps to the generic bindings
    - pick the supported NPad styles
    - add the controller-support applet to the join flow
    - add Nintendo glyphs and wire `LobbyControllerKind.Switch`
    - handle reconnect and HOME suspend
11. **Rendering and memory:**
    - add `Switch_RPAsset`, its renderer and a Switch quality level
    - add texture and lightmap overrides
    - re-evaluate lightmap counts per stage
    - pick 30 or 60 fps
    - profile I-072 on the device
12. **Player settings:** NMETA, titles, icons, Application ID, languages EN/JA, display version, startup logo.
13. **Build entry:** `SwitchBuild.cs` modelled on `SteamBuild.cs`, with a shipping scene list and dev/submission variants.
14. **First devkit run:** a development build, Local 1–4 players through Intro → Lobby → Tutorial → Area1, with memory and frame-time baselines.

## Open questions for the owner

1. Switch 1, Switch 2, or both? Is there a Nintendo developer account or publisher, a devkit, and an Application ID?
2. Stay on 6000.3.2f1 or upgrade first? Which 6.3 patch has a Switch module available?
3. Is online co-op in scope at launch? NSO, local wireless, or none? Cross-play with Steam?
4. Are the PvP modes (P5/P6) and `PlaygroundScene` in the Switch SKU?
5. Is single sideways Joy-Con play required?
6. Is bug/crash reporting needed on Switch? Through what channel?
7. 30 or 60 fps, docked and handheld? Can lighting be re-baked for Switch?
8. Cloud save or data transfer needs? Must the PlayerPrefs data carry over?
9. Who owns `Assets/Plugins/NuGet/` (`002e8c74a`)? Can it be deleted?
