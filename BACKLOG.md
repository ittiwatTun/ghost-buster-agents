# Backlog

Deferred work the owner wants kept, newest first. One entry per item: what it is, why it was deferred, what unblocks it. An item leaves when it ships, is delegated or the owner drops it, and moves to `_archive/BACKLOG.md` with the date and how it left.

## Switch settings fixed to one value, not configurable (added 2026-11-13)

- **What:** owner's note: "the switch should fixed the setting to only one value. no configurable." On Switch every display and graphics setting has one fixed value and its row does not show: Screen Mode, Screen Size (fixed 1280x720 since `d0a1cc4f1`), Graphics Quality and Light Quality (fixed by `SettingsData.QualityIsFixedToMedium`; the fixed tier waits on the Switch look decision, Medium vs PC Low), VSync and Frame Rate. Language, audio, subtitles, name labels and camera speed stay configurable (assumption, confirm with the owner).
- **Where:** rows are `SettingSelector` (`Kind` enum) / `SettingToggle` components listed per tab in `SettingsUI.tabs[].rows`, authored by the `SettingsGraphicsRowsBuilder` table (D58). Hiding a row means taking it out of `rows` as well as deactivating it, or keyboard/gamepad focus lands on an invisible row (`SettingsUI.MoveRow` walks the array). A tab left empty (Graphic) should drop out of the tab bar too.
- **Why deferred:** owner said it is a note, not an order.
- **Unblocks when:** the owner asks for it, or the Switch quality tier is decided.

## Switch NSP build entry, to install the game on the EDEV (added 2026-11-13)

- **What:** a second `SwitchBuild` entry (menu and CLI) that builds an `.nsp` with Create NSP ROM File on, so the game installs into EDEV system memory and starts from the DevMenu or HOME Menu without the PC. Install paths (manual 5.1 and 7.4): Target Manager 2 > Install Application > System memory; `UnityForNintendoSwitch\Tools\InstallApplication.bat` (`DevMenuCommand -- application install "<nsp>" --force`); or microSD > DevMenu > Install from SD. Check the Publishing settings (application ID, title, icon) and consider ROM compression; run `InvalidateApplicationCache.bat` after an icon or title change.
- **Why deferred:** owner: "hold for now. nsp when the result are stable." NSPD stays the daily test format (faster rebuild, log on the PC).
- **Unblocks when:** the Switch quality and frame rate results are stable (the PC Low vs Medium comparison and whatever follows it).
