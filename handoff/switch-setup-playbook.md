# Playbook: set up a PC for Nintendo Switch 1 development, from the developer portal to the first build on the EDEV

Written 2026-11-12 from the first setup on this machine (Windows 11, Unity Hub, an EDEV). It ends where `switch-edev-playbook.md` begins: that file covers building and running GhostBuster itself.

The steps that happen on Nintendo's website and in Nintendo Package Manager are described from what was seen on this setup; menu names on the portal can move. Nintendo's own instructions, once installed, are the source of truth. They are CONFIDENTIAL: read them in place and never copy their text into a tracked file.

Paths below use this machine's layout:

- `$NX` = the NNPM environment folder, here `E:\Nintendo\Unity6000.3.28_LTS-NXAddon22.2.0-Unity6.3`
- `$CLT` = `$NX\NintendoSDK\Tools\CommandLineTools`
- Unity Hub installs editors to `E:\UnityHub\<version>`

## 0. Before you start

| Need | Notes |
| :-- | :-- |
| Nintendo Developer Portal account | `developer.nintendo.com`, for an organization enrolled in the Nintendo Developer Program, NDA signed |
| Switch 1 development hardware | an EDEV is enough (see step 1) |
| A USB-C **data** cable | many USB-C cables only charge; the EDEV is then invisible to the PC |
| Windows PC | NintendoSDK supports Windows only |
| Unity Hub | the manual assumes it |
| A Unity license that covers Switch | a commercial Unity license or the Nintendo platform-specific license (Unity for Switch manual, FAQ 6.2) |
| Disk space | the environment, the editor and the first build together take tens of GB; this build alone is 5.2 GB |

## 1. Decide the platform and the hardware

- **Switch 1 or Switch 2.** They are separate targets with separate SDKs, Unity modules and build profiles (`Nintendo Switch` and `Nintendo Switch 2` are different define groups in Player Settings). This playbook is Switch 1, which NNPM calls **NX**.
- **EDEV or SDEV.** EDEV: looks like a retail console, 4 GB RAM, battery, connects over USB, some development controls missing. SDEV: thicker, 6 GB RAM, cable power only, Ethernet, full development controls, screen mirroring, a debug controller. Nintendo's Unity manual says one EDEV is necessary and sufficient for development and master ROM submission, and that a team must own at least one EDEV for the final check. Manual page 4.1 has the full table.

## 2. Log in to the developer portal and get Nintendo Package Manager

1. Log in at `developer.nintendo.com`.
2. Download **Nintendo Package Manager (NNPM)**. Nintendo Dev Interface (NDI) is deprecated and can no longer be downloaded, so any guide that says "install NDI" is out of date.
3. Install NNPM and start it.

## 3. Install the Switch environment with NNPM

1. Sign in to NNPM with the portal account.
2. Platform: **NX** (Switch 1). Toolset: **Unity**.
3. Pick the Unity version from **Recommended version** (or All versions). The name reads `<Unity version> <LTS or not>-NXAddon<NintendoSDK NX Add-On version>-<Unity family>`, here `6000.3.28 LTS-NXAddon22.2.0-Unity6.3`. **This decides your project's editor version**: the Switch module only installs into that exact editor patch.
4. Packages tab: add or remove extras, such as Unity for Nintendo Switch Documents (keep it; it is the manual).
5. Install location: keep the path short. The manual warns that a deep path can break application builds.
6. **Install packages** and wait.

What it installed here:

```
$NX\
  NintendoSDK\                 SDK, tools, docs; NINTENDO_SDK_ROOT points here
  NintendoSDK-NPLN\  NintendoSDK-Pia7\  NintendoSDK-PiaUnity3\
  LowLevelGraphicsDebugger\  NvnGraphicsDebugger\
  UnityForNintendoSwitch\
    UnitySetup-Nintendo-Switch-Support-for-Editor-<version>-SDK-<sdk>-<date>-<hash>.exe   the Unity module
    UnityDownloadAssistant-<version>.exe                                                the matching editor
    Packages\com.unity.inputsystem.switch@<x.y.z>\                                      Switch controller support
    Documents\                                                                          the Unity for Switch manual
    Tools\SwitchMenu_DevMenu.bat  SwitchMenu_HomeMenu.bat
```

7. Check the variable: open a **new** terminal and run `echo %NINTENDO_SDK_ROOT%` (PowerShell: `$env:NINTENDO_SDK_ROOT`). Here it is a user variable, `$NX\NintendoSDK`. If several SDKs are installed, this variable decides which one Unity uses.

## 4. Read the NNPM Environment checker

NNPM > the environment > **Environment checker**. Not every red item matters for Unity:

| Item | Needed for a Unity build? |
| :-- | :-- |
| Windows 11, .NET SDK 10, .NET Framework 4.8 | ✅ yes; NNPM installs .NET 10 (`%NINTENDO_SDK_ROOT%\Installers\DotNetSdk\*\Install.bat` if not) |
| Nintendo Target Manager 2 and its NX Plugin | ✅ yes; deploys to the console |
| Visual Studio Professional 2022, MSVC | ❌ no: "Visual Studio is not required for Unity builds" (manual page 3). Community 2022 does not satisfy the checker; that is fine |
| VSI for NX (VS 2019 / 2022) | ❌ only for debugging native C++ code; needs VS Professional |
| NVN API driver | ❌ "NVN API is not required for Unity for Nintendo Switch development" (manual 4.2) |
| Microsoft Visual C++ 2013 Redistributable (x86) | ⚠ install it from Microsoft; cheap, and some SDK tool may load it |

Click **Check environment** again after installing anything.

## 5. Install the matching Unity Editor

1. Unity Hub > Installs > install exactly the version from step 3, here **6000.3.28f1**. Add **Windows Build Support (IL2CPP)**; Switch is IL2CPP-only, and a PC IL2CPP build is a cheap way to find IL2CPP problems early.
2. Alternative: run `$NX\UnityForNintendoSwitch\UnityDownloadAssistant-<version>.exe`. If the Hub already has the editor, skip it. The `x.x.x` of the editor must match the `x.x.x` in the `UnitySetup-Nintendo-Switch-Support-for-Editor-x.x.x-...exe` file name.
3. If the editor is not in the Hub list, Hub > Installs > Locate > `<editor folder>\Editor\Unity.exe`.

## 6. Install the Unity Switch module

1. **Close every Unity Editor that runs this version.** Editors of other versions can stay open.
2. Run `$NX\UnityForNintendoSwitch\UnitySetup-Nintendo-Switch-Support-for-Editor-6000.3.28f1-SDK-22.2.0-20261030-8f082d2fe476.exe` from Explorer or PowerShell. From Git Bash the unquoted backslashes are eaten (`E:NintendoUnity...: command not found`); there, quote it with forward slashes.
3. **Set the destination to the editor folder**, here `E:\UnityHub\6000.3.28f1`, the same folder as the installed editor. The default may point somewhere else.
4. **Quit Unity Hub from the tray icon and start it again**, so it picks up `NINTENDO_SDK_ROOT`.
5. Verify: `E:\UnityHub\6000.3.28f1\Editor\Data\PlaybackEngines\Switch` exists (with `NintendoSDKTools.dll` inside), and Build Profiles lists Nintendo Switch.

## 7. Set up the EDEV

Manual: NintendoSDK Documents > Initializing the EDEV (`$NX\NintendoSDK\Documents\Package\contents\Pages\Page_126561209.html`).

1. **Charge** it on the AC adapter for about an hour. A low battery during initialization can fail the update.
2. **Note the serial number** on the sticker under the console (here `XAL03100237598`).
3. **Connect** the USB-C data cable from a PC USB port (straight into the PC, not a hub) to the USB-C port on the bottom of the EDEV, out of the dock. It powers on by itself. Do not use a relay box during initialization. Give Windows a moment to install the USB driver before going on.
4. **Check the driver:** Device Manager shows `NintendoSdkDebugger` or `NintendoSDK DevKit`. PowerShell check: `Get-PnpDevice -PresentOnly | Where-Object InstanceId -match 'VID_057E'`. If it is missing, run `$NX\NintendoSDK\Installers\DevkitDriver\dpinst.exe`.
5. **Initialize the firmware:** NNPM > Helpful links > Initialize the Development Hardware > Initialize the EDEV/HDEV/ADEV. In the tool:
   - 1\. select the row whose Serial matches the sticker;
   - 2\. keep the suggested firmware variation (here `23.0.1-1.1`, which matches the bundled SystemUpdater; firmware newer than the SDK number is normal); do not pick `Prod` without reading the PROD MODE notes;
   - 3\. **Start initialization**; allow the Windows Firewall prompts; the log pauses for 80 to 90 s; the fan gets loud;
   - wait for **Success** at the lower left, then Exit. About five minutes.
6. **Verify:** `& "$CLT\ControlTarget.exe" list-target` prints the serial with `<NoIpAddress>` (USB).

If the EDEV does not appear in the tool, try another cable and port, Re-Scan, then the "When EDEV Initialization Fails" page, then Nintendo support.

## 8. Smoke test with an empty project

Proves the editor, the module, the SDK, the toolchain and the EDEV before any real project gets in the way. About 10 minutes, all from the `unity` CLI (`%LOCALAPPDATA%\Unity\bin\unity.exe`). Keep the project outside the game repository.

```powershell
$u = "$env:LOCALAPPDATA\Unity\bin\unity.exe"
& $u projects create SwitchSmoke --path E:\Itt\Repository --editor-version 6000.3.28f1 --template 3d --no-cloud --non-interactive
& $u build E:\Itt\Repository\SwitchSmoke --create-profile Switch
& $u build E:\Itt\Repository\SwitchSmoke --profile Switch --output-path E:\Itt\Repository\SwitchSmoke\Build\SwitchSmoke
& "$CLT\RunOnTarget.exe" E:\Itt\Repository\SwitchSmoke\Build\SwitchSmoke.nspd_root --target XAL03100237598 --no-wait
```

- `--target Switch` alone is refused for Switch; it needs a build profile or `--execute-method`.
- The build took about 8 minutes here (IL2CPP, 1,308 compile steps with NintendoClang). Licensing handshake errors in the batch log are harmless.
- Success: the console prints `Exit( Result: Success, ExitKind: NoWait )` and the URP sample scene appears on the EDEV.

## 9. Bring the game project to the Switch editor version

Only if the project's `ProjectSettings/ProjectVersion.txt` is not already the editor from step 3.

1. `git fetch origin`, fast-forward `develop`, cut a branch (here `feature/nintendo-sdk`).
2. Open the project **through Unity Hub** with the new editor the first time. A launcher that reads `ProjectVersion.txt` would still pick the old editor.
3. Expect a large first import with an empty `Library/`, a possible API Updater timeout on third-party DLLs (harmless inside a patch line), and package bumps to the editor's verified versions (here Input System 1.18.0 to 1.20.1, which is worth a two-controller menu test).
4. Expect texture `.meta` churn from the reimport (here 3,874 files: importer format v13, a WindowsStoreApps block per installed UWP module). Commit it on its own, separate from the version bump; it also pushes a GitHub PR past its roughly 3,000-file display limit, so consider a separate PR.
5. Check Play mode, the PC build, then tell the team before merging: everyone moves editors together.

## 10. Next

Continue with `switch-edev-playbook.md`: the project changes GhostBuster needs for Switch, the build command, deploying and running, reading the EDEV log, and troubleshooting.
