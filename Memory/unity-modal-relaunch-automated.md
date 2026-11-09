---
name: unity-modal-relaunch-automated
description: when a Unity modal dialog blocks the Editor's main thread, close Unity and reopen it through open-unity.ps1 with -automated instead of asking the owner to click it
type: feedback
---

When a modal dialog (such as "Scene(s) Have Been Modified" raised by the test runner) blocks the Unity Editor, close Unity and reopen it with `scripts/open-unity.ps1` (this folder), which launches with `-automated` so no modal dialog waits for a human.

**Why:** owner, 2026-10-22 (king-of-ashes, carried over with this setup), after a test run hung on that dialog in an Editor opened from Unity Hub (no `-automated`) and the owner had to find and answer it: *"next time you can close unity and open as no prompt window mode."*

**How to apply:** a pipeline command timing out with `Main thread operation timed out` while `Get-Process Unity` reads Responding means a modal; list the Editor's windows to name it. Check the Editor's command line (`Get-CimInstance Win32_Process`) for `-automated` before a test run; a Hub-launched Editor lacks it. Close the Editor, then run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "E:/Itt/Repository/GhostBuster/.agents.local.ghost-buster/scripts/open-unity.ps1"` and poll `editor_status` until ready.
