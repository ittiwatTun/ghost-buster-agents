# Backlog

Deferred work the owner wants kept, newest first. One entry per item: what it is, why it was deferred, what unblocks it. An item leaves when it ships, is delegated or the owner drops it, and moves to `_archive/BACKLOG.md` with the date and how it left.

## NVN Graphics Debugger capture of Game1 on the EDEV (added 2026-11-13)

- **What:** capture one Game1 frame with the NVN Graphics Debugger (NVIDIA, installed by NNPM at `$NX\NvnGraphicsDebugger\`, launcher `$NX\UnityForNintendoSwitch\Tools\NvnGraphicsDebugger.bat`; Unity for Switch manual section 7.3) to see GPU time per pass and draw. Game1 is 66 to 75 ms GPU at 1024x576 (PC Low); 30 fps needs about 33 ms; the GPU is fill-bound. Suspects, unmeasured: `LitXRay` translucent wall pass, post-processing (Bloom, UberPost), shadows, transparency and VFX overdraw. Turn on the Switch build options for shader source visibility in captures first. Figures: `research/2026-11-13-switch-performance-report.md`.
- **Why deferred:** owner: "backlog. i will do when the time come."
- **Unblocks when:** the owner picks Switch performance up again.
