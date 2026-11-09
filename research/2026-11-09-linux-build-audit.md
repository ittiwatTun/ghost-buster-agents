# GhostBuster → Linux build readiness audit

2026-11-09, read-only. Repo `E:\Itt\Repository\GhostBuster` @ `develop` `271940f2b`, Unity 6000.3.2f1. Nothing was edited.

Markers: ✅ ready · ⚠ needs work · ❌ blocker. **[obs]** = seen on this machine or in the repo. **[doc]** = public Unity or Steamworks documentation, from training knowledge; no web lookup in this session. **[inf]** = a guess that needs a test on a Linux machine.

Unlike Switch, Linux has no NDA layer: Unity's Linux player and Steamworks' Linux support are publicly documented.

## Bottom line

- One install is missing: **Linux Build Support** is in none of the 4 editors.
- One content risk: **every in-game video is H.264**. Unity recommends VP8/webm for Linux [doc]; the docs do not say outright that a Linux Player cannot play H.264, but they list no Linux H.264 decoder, and Linux players are commonly reported to fail on `.mp4` [inf]. The intro (AreaVideoScene), the stage previews and the guide clips may show nothing. Settle it with one test build on Linux; the fix (transcode to VP8) is cheap either way.
- Everything else is small. Steam, Mirror and FizzySteamworks all support Linux, and project code has almost no Windows-only paths.
- A native Linux build is optional for Steam Deck: the current Windows build can run there under Proton. Pick the goal first (see Open questions).

## 1. Machine readiness

- ❌ **No Linux Build Support module [obs].** 6000.0.75f1, 6000.3.2f1, 6000.3.8f1 and 6000.3.16f1 each have only `AndroidPlayer`, `MetroSupport`, `iOSSupport` and `windowsstandalonesupport`.
  - Fix: Unity Hub → 6000.3.2f1 → Add modules → *Linux Build Support (Mono)*, and *(IL2CPP)* if wanted. Free, public download.
- ⚠ **IL2CPP for Linux from Windows** needs Unity's Linux toolchain and sysroot packages [doc]. Unity pulls `com.unity.toolchain.*` / `com.unity.sysroot.*` in when you first build. A Mono Linux build needs none of it.
- ⚠ **No Linux machine for testing** was found in this setup [inf]. A Steam Deck, a Linux PC, or WSL2 with GPU (weak for games) is needed. A build cannot be checked on Windows.

## 2. Project configuration

- ✅ **Graphics API [obs].** `m_BuildTargetGraphicsAPIs` has no Linux entry, so Linux uses the automatic list: Vulkan first, then OpenGLCore [doc]. URP 17.3 Forward+, SSAO, decals and native render pass are supported on Vulkan [doc].
- ⚠ **Custom shader** `Assets/_Project/Shaders/LitXRay/LitXRay.shader:255` has `#pragma exclude_renderers gles3 glcore` [obs]. Under Vulkan it compiles. If a machine falls back to OpenGLCore, that pass is skipped, so X-ray outlines vanish.
  - Fix: force Vulkan only for Linux, or drop `glcore` from the exclude.
- ✅ **Scripting backend [obs]:** `Standalone: 0` (Mono). That covers Linux too, since Linux is in the Standalone group. Mono Linux builds work with no extra toolchain.
- ✅ **Defines [obs]:** Linux shares the Standalone defines, so `STEAMWORKS_NET` and the `MIRROR_*` set apply. Steam code compiles as on Windows. The stale `FUSION*` defines are harmless clutter.
- ⚠ **Build profile [obs]:** only `Assets/Settings/Build Profiles/Windows.asset`.
- ⚠ **Display [obs/doc]:**
  - `SettingsData.cs:22` offers `ExclusiveFullScreen`, which exists only on Windows; on Linux it becomes borderless fullscreen [doc]. Hide that option on Linux, or accept it.
  - `ImageFilePicker.cs:41` reads the same mode, but that code is Windows-guarded.

## 3. Content risk: video

- ⚠ **All shipping video clips are H.264 [obs].**
  - `Assets/Recordings/*.mp4`: an `ftyp mp42` header and an `avc1` atom found in `Movie_004.mp4` and `intro.mp4`.
  - Unity Recorder output, 31 files, 14 MB.
- Referenced by shipping data [obs]:
  - `intro.mp4` → `Scenes/AreaVideoScene.unity`
  - `Movie_004` to `Movie_007` → `Data/StageDatas/stage1-5.asset`
  - `Movie_008`, `009`, `011`, `025`, `045`, `046`, `047`, `051`, `054` → `Data/Guides/Guide_*.asset`
  - Played by `IntroSceneHandler`, `AreaVideoSceneHandler`, `StageDetailUI`, `GuidePanelUI`, `SceneFlowManager`.
- Import settings [obs]:
  - `intro.mp4.meta` transcodes for "Others" to `codec: 1` (H.264).
  - The rest have `targetSettings: {}`, so the source H.264 ships as is.
- What the Unity 6.3 docs say, checked 2026-11-09 ([file compatibility](https://docs.unity.com/en-us/engine/6000.3/manual/video/sources/file-compatibility), [target platforms](https://docs.unity.com/en-us/engine/6000.3/manual/video/sources/compatibility-target-platforms)):
  - "the optimal encoding for Linux is a .webm container with VP8 for video and Vorbis for audio."
  - Editor preview uses the host OS decoders. In the format table, `.mp4` is most likely not ticked for Linux; the fetched table was garbled, so confirm in a browser.
  - The vendor decoder list names Windows, UWP, Android and iOS, not Linux. Linux Player H.264 support is not stated either way.
- [inf] Linux players are commonly reported to play only VP8 and to fail on `.mp4`. Unverified here: one Linux test build with one clip decides it.
- **Not only Linux (owner, 2026-11-09: some Windows machines without the codec also fail).** H.264 in Unity is decoded by the OS, through Media Foundation on Windows:
  - Windows N/KN editions ship without Media Foundation (`MFPlat.DLL`). They need the Microsoft Media Feature Pack, or H.264 playback fails ([AVPro Windows notes](https://renderheads.com/content/docs/AVProVideo/articles/platform-windows.html)).
  - Unity's issue tracker logs a non-specific `VideoPlayer` failure when Media Foundation is absent ([Win 8 N/KN issue](https://issuetracker.unity3d.com/issues/win-8-kn-slash-n-videoplayer-inadequate-error-reporting-on-errorreceived-callback-when-media-player-is-not-present)).
  - Steam Deck under Proton goes through Wine's Media Foundation [inf, weak spot].
  - The repo already has two open Media Foundation-related crashes: I-032 (D3D12 faults on the MF hardware-decoded texture, worked around by pinning D3D11) and I-029 (Editor crashes while MF opens the guide clips).
  - [inf] VP8 is decoded by Unity's own software decoder on every platform, so a VP8 transcode removes the OS codec dependency everywhere, and likely the MF path behind I-032 and I-029 as well. Cost: CPU decode, lower quality per bitrate. These clips are short and small (14 MB total).
  - No video handler subscribes to `VideoPlayer.errorReceived` [obs]. The prepare loops time out and carry on: `AreaVideoSceneHandler.cs:192-197` logs a generic "prepare did not finish" warning, `IntroSceneHandler.cs:345`, and `GuidePanelUI.cs:506`. None logs the decoder's reason, so a codec failure on a player's machine reads as a timeout in a bug report.
- Fix:
  - Turn on transcoding on every referenced clip, with codec VP8, or Auto (picks per target platform). `intro.mp4` already transcodes, but to H.264, which does not help Linux. Transcode settings are per clip; Windows and Linux share the "Standalone" settings, so Windows moves to VP8 too, which also works.
  - Or re-export the clips as `.webm` VP8.
  - Size and import time grow somewhat [inf].

## 4. Code and plugins

- ✅ **Windows-only code is contained [obs]:**
  - The only player-side `DllImport` is `ImageFilePicker.cs` (comdlg32/user32), behind `#if UNITY_STANDALONE_WIN || UNITY_EDITOR_WIN` (`:16`). Elsewhere it reports `Supported=false`.
  - No `Registry`, `SpecialFolder` or `Process.Start` in player code. `SteamBuild.cs:75` `Process.Start` is in an editor script.
  - `LogRedactor.cs:15` already masks `/home/<user>` paths.
- ✅ **Resources are case-safe:** no string `Resources.Load("…")` calls in `_Project` [obs]. Linux file systems are case-sensitive, but asset references inside a build are not file paths [doc].
- ✅ **Steam:**
  - `FizzySteamworks.asmdef` includes `LinuxStandalone64` [obs, from the Switch audit].
  - Steamworks.NET ships `libsteam_api.so` for Linux x86_64 [doc]; the package contents were not inspectable (no `Library/`).
  - `steam_appid.txt` is copied next to the build by `SteamBuild.CopyAppIdFile`. On Linux it must also sit next to the executable for builds started outside Steam [doc].
- ✅ **Mirror and kcp2k** use plain .NET sockets with IPv6 dual-mode; Linux is a supported Mirror platform [doc].
- ⚠ **`Assets/Plugins/NuGet/` (41 unreferenced DLLs, any platform)** ships into the Linux build too. Mono is tolerant; IL2CPP may hit linker errors. Same fix as in the Switch audit: remove them or make them Editor-only.
- ⚠ **Input [inf]:**
  - The Input System on Linux reads gamepads through SDL [doc], so generic `<Gamepad>` bindings work.
  - But `GamepadGlyphs.FromLayout` (`UI/GamepadGlyphs.cs:49-57`) picks glyphs by layout name: `XInput`, `DualShock`/`DualSense`/`PlayStation`, `Switch`/`JoyCon`.
  - Linux layout names differ from Windows (no XInput) [inf], so Xbox pads may get generic glyphs.
  - Under Steam, controllers often appear as a "Steam Virtual Gamepad" [inf].
  - Test on the device and add Linux layout names.
- ✅ **Bug/crash reporting:** `Application.consoleLogPath` and `persistentDataPath` resolve under `~/.config/unity3d/<company>/<product>/` on Linux [doc]. The Discord `HttpClient` post works on Mono. The HTTP/2 note at `BugReportSender.cs:134` needs a re-test.
- ✅ `PlayerPrefs` on Linux are a file under `~/.config/unity3d/…` [doc]; no change needed.
- ✅ `Application.OpenURL` (`UrlButton.cs:91`) goes through `xdg-open` [doc].

## 5. Steam distribution

- ⚠ **One depot, Windows only [obs].**
  - `Steam/app_build.vdf` maps `5246231` → `depot_5246231.vdf`, with `ContentRoot` `Windows64/`.
  - A native Linux release needs:
    - a second depot in Steamworks, set to OS Linux
    - a `depot_<id>.vdf` with `ContentRoot` `Linux64/`
    - its line in `app_build.vdf`
    - the Linux launch option in the Steamworks app config (executable `<name>.x86_64`)
- Steam Deck [doc]:
  - With no Linux depot, Deck runs the Windows depot under Proton.
  - Deck Verified review checks controller glyphs, text size at 1280×800, the default config and the launcher.
  - A native Linux build is not required for Verified.

## 6. Build pipeline

- ⚠ **`SteamBuild.cs` builds Windows x64 only [obs].** For Linux, add `GhostBuster/Steam/Build Linux x64 (Mono|IL2CPP)`:
  - `BuildTarget.StandaloneLinux64`, output `Build/Steam/Linux64/`
  - the same `ApplySteamPlayerSettings` (it already targets `NamedBuildTarget.Standalone`)
  - copy `steam_appid.txt`
- ⚠ No CI [obs]. A Linux build can also run on Windows in batchmode once the module is installed [doc].

## Preparation checklist (ordered)

1. Decide the goal: native Linux depot, or Steam Deck via Proton only (then skip to step 8).
2. Install Linux Build Support (Mono, plus IL2CPP if wanted) for 6000.3.2f1, or for the editor you settle on.
3. Video: set VP8 transcoding for Linux on the 14 referenced clips (or re-export as `.webm`). Check playback in AreaVideoScene, stage detail and the guide panel.
4. LitXRay: force Vulkan only for Linux in Player Settings, or allow `glcore`.
5. Remove or Editor-restrict `Assets/Plugins/NuGet/*`.
6. Add the `Build Linux x64` entry to `SteamBuild.cs`; build Mono first.
7. Test on a Linux machine or Deck:
   - launch, Vulkan, Local 1–4 players
   - gamepad glyphs (fix `FromLayout` for Linux layout names)
   - online through Steam (Fizzy) and LAN
   - video
   - save location, bug report
8. Steam: add the Linux depot, vdf and launch option, upload to a beta branch. For Deck, test the Windows build under Proton on a Deck and work toward Verified (glyphs, text size, 1280×800).

## Open questions for the owner

1. Native Linux build, or Steam Deck through Proton only?
2. Is there a Linux PC or Steam Deck for testing?
3. Mono or IL2CPP for Linux (match what Windows ships)?
4. Can the video clips change format (VP8/webm), or must the Windows build stay H.264?
