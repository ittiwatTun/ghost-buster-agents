# Post-it

One line each, newest on top. Surprises worth a glance, not a record.

- 2026-11-09 — Nintendo Dev Interface (NDI) is deprecated and no longer downloadable; the Switch 1 SDK and tools now come through the Nintendo Package Manager (NNPM) on the developer portal (per Epic's UE 5.7 Switch notes). Older guides that say "install NDI" are stale.
- 2026-11-09 — `mv` of a folder failed with `Device or resource busy` while the Bash tool's working directory sat inside it; it worked once the cwd moved out. Unity's `UnityPlayer.dll` carries its own Media Foundation error strings, so `grep -a` on the player binary answers "which decoder does the build use" without a test machine.
- 2026-11-09 — GhostBuster tracks `.claude/settings.local.json`, so the private SessionStart hook cannot live there the way it does in king-of-ashes-unity. `git remote add` with the https URL shows `git@github.com:` because a global `url.insteadOf` rewrites it.
