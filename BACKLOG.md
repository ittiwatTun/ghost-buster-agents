# Backlog

Deferred work the owner wants kept, newest first. One entry per item: what it is, why it was deferred, what unblocks it. An item leaves when it ships, is delegated or the owner drops it, and moves to `_archive/BACKLOG.md` with the date and how it left.

## Switch NSP build entry, to install the game on the EDEV (added 2026-11-13)

- **What:** a second `SwitchBuild` entry (menu and CLI) that builds an `.nsp` with Create NSP ROM File on, so the game installs into EDEV system memory and starts from the DevMenu or HOME Menu without the PC. Install paths (manual 5.1 and 7.4): Target Manager 2 > Install Application > System memory; `UnityForNintendoSwitch\Tools\InstallApplication.bat` (`DevMenuCommand -- application install "<nsp>" --force`); or microSD > DevMenu > Install from SD. Check the Publishing settings (application ID, title, icon) and consider ROM compression; run `InvalidateApplicationCache.bat` after an icon or title change.
- **Why deferred:** owner: "hold for now. nsp when the result are stable." NSPD stays the daily test format (faster rebuild, log on the PC).
- **Unblocks when:** the Switch quality and frame rate results are stable (the PC Low vs Medium comparison and whatever follows it).
