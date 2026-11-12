# Playbook: build GhostBuster for Nintendo Switch 1 and run it on the EDEV

Written 2026-11-12 from the first end-to-end run on this machine. Branch `feature/nintendo-sdk`. Every command below was run for real; the timings are this machine's (12 logical cores, 64 GB RAM).

Nintendo's own documents are installed locally and are the source of truth; read them in place, never copy their text into a tracked file (they are CONFIDENTIAL):

- Unity for Switch manual: `E:\Nintendo\Unity6000.3.28_LTS-NXAddon22.2.0-Unity6.3\UnityForNintendoSwitch\Documents\contents-en\Pages\` (4.1 hardware `Page_218187855`, 4.2 install `Page_209097536`, 3 operating environment `Page_209097519`, 5.1 build and run `Page_218194222`, 5.10 Input System `Page_1132438889`).
- NintendoSDK docs: `...\NintendoSDK\Documents\Package\contents\Pages\` (Initializing the EDEV `Page_126561209`).

In the commands below, `$NX` is the environment root `E:\Nintendo\Unity6000.3.28_LTS-NXAddon22.2.0-Unity6.3` and `$CLT` is `$NX\NintendoSDK\Tools\CommandLineTools`.

## 1. Hardware facts

- Switch 1 development hardware is the SDEV (6 GB, Ethernet, full debug) or the EDEV (retail-like, 4 GB, USB, battery). One EDEV is enough for development and is required for the final check before master ROM submission. Our unit is an EDEV, serial `XAL03100237598`.
- The EDEV connects to the PC with a USB-C data cable into the port on the bottom of the console, undocked. No relay box is needed (the docs only say not to use one during initialization).
- Switch 1 budget for the game: about 3.2 GB RAM shared by CPU and GPU, 3 CPU cores at about 1 GHz, a Maxwell GPU at 307 to 460 MHz handheld and 768 MHz docked, 720p handheld and 1080p docked.

## 2. One-time machine setup

1. **Nintendo Package Manager (NNPM).** Nintendo Dev Interface (NDI) is deprecated; NNPM replaced it. Sign in, pick the Unity toolset and the version NNPM recommends (here `6000.3.28 LTS`, NX Add-On 22.2.0). It installs into one environment folder and sets the user variable `NINTENDO_SDK_ROOT` to `$NX\NintendoSDK`.
2. **NNPM Environment checker.** Red items that do not block a Unity build: Visual Studio Professional and MSVC ("Visual Studio is not required for Unity builds"), VSI for NX (C++ debugging only, needs VS Professional), NVN API driver (not used by Unity). Install the Microsoft Visual C++ 2013 Redistributable (x86) if it shows as missing.
3. **Unity Editor `6000.3.28f1`** through Unity Hub. The Switch module must match the editor patch exactly. Add Windows Build Support (IL2CPP) for a PC-side IL2CPP check.
4. **Switch module.** Close every Editor running 6000.3.28f1, then run `$NX\UnityForNintendoSwitch\UnitySetup-Nintendo-Switch-Support-for-Editor-6000.3.28f1-SDK-22.2.0-20261030-8f082d2fe476.exe` and set the install folder to the Editor folder (`E:\UnityHub\6000.3.28f1`). Run it from PowerShell or Explorer; from Git Bash the backslashes are eaten. Verify: `E:\UnityHub\6000.3.28f1\Editor\Data\PlaybackEngines\Switch` exists.
5. **Restart Unity Hub from the tray** so it sees `NINTENDO_SDK_ROOT`.

## 3. One-time EDEV setup

1. Charge the EDEV for about an hour; a low battery can fail the firmware update.
2. Plug the USB-C data cable straight into a PC port (no hub). Device Manager must show `NintendoSdkDebugger` or `NintendoSDK DevKit`. If not, run `$NX\NintendoSDK\Installers\DevkitDriver\dpinst.exe`.
3. NNPM > Helpful links > Initialize the Development Hardware > Initialize the EDEV/HDEV/ADEV. Pick the row whose Serial matches the sticker under the console, keep the suggested firmware (here `23.0.1-1.1`), Start initialization, allow the firewall prompts, wait through the 80 to 90 s pause in the log, until Success.
4. Check: `& "$CLT\ControlTarget.exe" list-target` prints `XAL03100237598  <NoIpAddress>` (USB).

## 4. What the project needs (already on `feature/nintendo-sdk`)

| Piece | Where | Why |
| :-- | :-- | :-- |
| Editor 6000.3.28f1 | `ProjectSettings/ProjectVersion.txt` | the version NNPM pairs with the Switch module |
| `DISABLESTEAMWORKS` in the Nintendo Switch define group | `ProjectSettings/ProjectSettings.asset` | the Steam scripts compile out |
| NuGet DLLs Editor-only | `Assets/Plugins/NuGet/*.dll.meta` | they would otherwise ship to the IL2CPP player |
| `CrashReporting` no-op on Switch | `Scripts/Core/CrashReporting.cs` | `CrashReportHandler` does not exist on Switch |
| "Switch" quality level using `PC_Medium_RPAsset` | `ProjectSettings/QualitySettings.asset` | Switch matches the PC shipping default and URP strips shaders against that asset only |
| Graphics and light quality locked to Medium on Switch | `Scripts/UI/Settings/SettingsData.cs` | no stripped tier can be picked at runtime |
| Switch input package | `Packages/com.unity.inputsystem.switch` (copied from `$NX\UnityForNintendoSwitch\Packages\com.unity.inputsystem.switch@1.0.2`, folder renamed without `@1.0.2`) | without it Joy-Cons are only a generic gamepad and the player cannot move |
| TMP Overlay shaders always included | `ProjectSettings/GraphicsSettings.asset` | `WorldUIOnTop` swaps labels to the Overlay shader at runtime, so their outline/underlay variants were never built (PC has the same gap, silently) |
| Build entry | `Assets/_Project/Editor/Build/SwitchBuild.cs` | development NSPD build to `Build/Switch/GhostBuster.nspd` |

## 5. Build

1. **Close GhostBuster's Unity Editor.** Batch mode cannot open a project the Editor holds.
2. **Close the game on the EDEV:** `& "$CLT\ControlTarget.exe" terminate --target XAL03100237598`. An NSPD runs its files from the PC, so a running game locks `Build/Switch/*.nspd` and the build fails with "Could not write ... being used by another process".
3. **Start the build detached and at Idle priority**, so it survives the Claude Code session closing and does not freeze the PC:

   ```powershell
   $log = "E:\Itt\Repository\GhostBuster\Logs\switch-build.log"
   $p = Start-Process -FilePath "$env:LOCALAPPDATA\Unity\bin\unity.exe" -ArgumentList @(
       'build','E:\Itt\Repository\GhostBuster','--target','Switch',
       '--execute-method','SwitchBuild.BuildDevelopment',
       '--log-file',$log,'--no-tail','--no-banner','--non-interactive') -WindowStyle Hidden -PassThru
   $p.PriorityClass = 'Idle'   # children inherit it
   ```

   From the Editor instead: GhostBuster > Switch > Build Development (NSPD).
4. **Watch the log**, never wait blind: `Logs/switch-build.log`. Success ends with `SwitchBuild: done, <MB> in <time>`. A watcher script that prints progress and the result is `temp/watch-switch-build.ps1` in this folder.
5. **Timing.** The first build on a machine compiles every Switch shader variant: about 2 h 24 min here (URP `Lit` 5,760 variants and `GhostBuster/LitXRay` 2 x 3,072 dominate). The variants are cached in `Library/`, so later builds take about 4 minutes unless shaders, materials or the Unity version change. A fresh clone or another machine pays the first build again.
6. **Priority.** Normal priority is 2 to 3 times faster but makes the PC unusable (12 shader compilers at 100% CPU). Raise it only when nobody is using the PC: `temp/build-priority-schedule.ps1 -CliPid <pid> -NormalFrom 12:00 -NormalUntil 13:00` runs detached and re-applies the priority every 30 s.
7. **Strict shader variant matching** is opt-in (`-strictShaderVariants` on the CLI, or the Strict menu item). Do not use it for a normal test build: URP's `UberPost` and `Bloom` get refused for fragment-only keywords reported on the vertex stage, and the whole 3D image goes black behind the UI. It is still useful to find genuinely missing `shader_feature` variants (it found the TMP Overlay gap).

## 6. Deploy and run

```powershell
# send and start; prints the game's log until the game exits
& "$CLT\RunOnTarget.exe" "E:\Itt\Repository\GhostBuster\Build\Switch\GhostBuster.nspd_root" --target XAL03100237598 --print-host-time

# start and return at once
& "$CLT\RunOnTarget.exe" "...\GhostBuster.nspd_root" --target XAL03100237598 --no-wait

# close the game / restart the EDEV
& "$CLT\ControlTarget.exe" terminate --target XAL03100237598
& "$CLT\ControlTarget.exe" reset --target XAL03100237598
```

- Pass the empty `GhostBuster.nspd_root` file; NintendoSDK tools read it as the NSPD folder of the same name.
- The first transfer of a 5.2 GB build over USB takes about 5 minutes; the EDEV looks idle meanwhile. Later runs start in seconds.
- Running RunOnTarget again closes the running game first, so it doubles as "restart the game".
- A PC-run NSPD is not installed on the EDEV and cannot be started again from its HOME menu; start it from the PC.
- To keep the log in a file while working: start RunOnTarget with `Start-Process ... -RedirectStandardOutput <file> -PassThru` and read the file.
- GUI alternative: Nintendo Target Manager 2 > right-click the EDEV > Connect to Target, then drag the `.nspd` folder onto its row.

## 7. Reading the EDEV log

- Boot is healthy when you see `Initialize engine version: 6000.3.28f1`, `Initialised in ... seconds` and `Starting main loop at ... seconds`.
- Scene loads: `[SceneFlowManager] load trace <Scene>: ... total=<ms>`.
- A development build prints a frame summary every 5 s: `Frame: N Perf.Mode: Normal frm_fps: 5.64 frm_ms/f: 177.27 CPU_render_ms/f: 11.31 CPU_present_ms/f: 162.21 GPU_ms/f 176.67 Total.Memory:1.41GB`. `Perf.Mode: Normal` is handheld; docked shows a boost mode. 30 fps needs about 33 ms per frame.
- Controller join: `Player 1 joined via Gamepad`.
- `[WARNING] Attempting to disable VSync without "No Vsync Capability"` is harmless; the game runs with vsync.
- Thai log text prints as `???`; that is the console, not the game.

## 8. Troubleshooting

| Symptom | Cause | Fix |
| :-- | :-- | :-- |
| PC lags badly during a build | shader compilers at Normal priority | set the build to Idle (section 5) |
| Build disappears halfway | it was a child of the Claude Code session, which closed | start it detached (section 5) |
| `Could not write ... being used by another process` | the game is still running on the EDEV from that NSPD | `ControlTarget.exe terminate`, then rebuild |
| EDEV idle for minutes after RunOnTarget | first transfer of the 5 GB build | wait about 5 minutes |
| Log stops after `Starting main loop`, USB device ID changes | the cable came loose | reseat the cable, run RunOnTarget again (add `--reset`) |
| Only UI visible, 3D background black | strict shader variant matching refused the post-processing pass | build without `-strictShaderVariants` |
| Touch works but Joy-Cons do not move the player | Switch input package missing | `Packages/com.unity.inputsystem.switch` (section 4) |
| Switch module missing after install | installer pointed at the wrong folder, or Hub not restarted | rerun it into `E:\UnityHub\6000.3.28f1`, restart Hub from the tray |
| GitHub PR shows no code changes | over about 3,000 files; the 3,874 texture metas from the Unity upgrade push the code past the cut-off | review per commit, or split the upgrade into its own PR |

## 9. State after the first run (2026-11-12)

- ✅ Toolchain proven end to end: CLI build, NintendoClang IL2CPP, USB deploy, the game boots into Intro and the title screen.
- ✅ Memory in the lobby: 1.41 GB used, 1.44 GB free.
- ❌ **GPU: 5.6 fps in the lobby handheld, 177 ms GPU per frame**, about 5 to 6 times over a 30 fps budget at PC Medium. The intro video runs at 49 fps. Next: test the Switch quality level on `PC_Low_RPAsset` (its variants are already cached), then profile with the NVN Graphics Debugger. The final Switch look is a team decision.
- ⚠ Button prompts show keyboard and Xbox/PS glyphs; Switch glyphs are still to do.
- ⚠ The graphics and light quality rows still show in the Switch settings menu, though both are locked to Medium.
- ⚠ Touch drives the menus; the game must also be fully playable on controllers.
