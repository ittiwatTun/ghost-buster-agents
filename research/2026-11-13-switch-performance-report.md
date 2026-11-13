# GhostBuster on Nintendo Switch 1: performance findings (2026-11-12 to 2026-11-13)

Branch `feature/nintendo-sdk`. Hardware: Switch 1 EDEV `XAL03100237598`, handheld mode (`Perf.Mode: Normal`), firmware NX 23.0.1-1.1. Toolchain: Unity 6000.3.28f1 + NX Add-On 22.2.0 (NintendoSDK 22.2.13). Every figure below comes from the development build's own 5-second frame summary in the EDEV log (`frm_fps`, `GPU_ms/f`, `CPU_render_ms/f`, `Total.Memory`). Logs: `GhostBuster/Logs/edev-run-pclow.log`, `GhostBuster/Logs/edev-run-720p.log`; the Medium figures are from the 2026-11-12 session.

## Summary

- ✅ The game builds, deploys, boots and plays on the EDEV with no exceptions: intro, title, lobby, Tutorial, StageSelect and Game1, Joy-Con control, scene loads, memory well inside budget.
- ❌ It does not hold 30 fps in the lobby or in a real stage yet. Tutorial does (42 to 44 fps).
- The GPU is the limit, and it is **fill-bound**: GPU time scales almost exactly with the number of rendered pixels.
- Two changes so far, together about **4 to 5 times faster** than the first build: PC Low render settings instead of PC Medium (about 2 times), and rendering at 720p instead of 1080p (about 2.2 times more).
- Game1 still needs about **2.2 times** less GPU time for 30 fps. The cause is scene content; it is not yet measured per pass.

## 1. Results by step, handheld

| Scene | Step 1: PC Medium, 1920x1080 | Step 2: PC Low, 1536x864 | Step 3: PC Low, 1024x576 (720p x 0.8) | 30 fps? |
| :-- | :-- | :-- | :-- | :-- |
| Lobby | 4.9 to 5.8 fps, GPU 173 to 206 ms | 10.1 to 10.3 fps, GPU 96 to 98 ms | **22.4 fps, GPU 44 ms** | ❌ needs 1.3x |
| Tutorial | 11.6 to 12.2 fps, GPU 78 to 85 ms | about 20 fps, GPU 36 to 45 ms (few samples) | **42 to 44 fps, GPU 21 to 23 ms** | ✅ |
| StageSelect | not measured | 9.3 to 10.2 fps, GPU 98 to 108 ms | **16.5 to 19.4 fps, GPU 54 to 58 ms** | ❌ needs 1.7x |
| Game1 | not measured (est. 250 to 350 ms GPU) | 5.9 to 7.9 fps, GPU 121 to 174 ms | **13.3 to 15.1 fps, GPU 66 to 75 ms** | ❌ needs 2.2x |
| AreaVideo (video) | | 60 fps, GPU 11.5 ms | | ✅ |

30 fps means about 33 ms per frame on both GPU and CPU.

**CPU render thread** (step 3): Lobby 5.6 to 5.8 ms, Tutorial 7 to 10 ms, StageSelect 13 to 14 ms, Game1 14 to 20 ms. Not the limit today, but Game1 already uses about half of a 33 ms frame, so it becomes the next limit once the GPU is fixed.

**Memory** (step 3): 0.97 to 1.44 GB total, peak in Game1. Comfortable (step 1 lobby was 1.41 GB used, 1.44 GB free).

## 2. Finding: the game rendered 1080p on a 720p screen

- `SettingsData.Boot()` runs `ApplyScreen()` at startup, which applied the PC screen-size option (default 1920x1080) on Switch too. Handheld native is 1280x720, so every frame rendered 2.25 times the pixels the screen shows.
- Fixed in `d0a1cc4f1` (merged into `feature/nintendo-sdk` as `e51dd0a0c`): on Switch, `ApplyScreen` sets 1280x720. The build logs the real size once at boot; on the EDEV it reads `Switch screen 1280x720, render scale 0.8, renders 1024x576`.
- Result: GPU time dropped 2.2 times in every scene (Lobby 97 to 44 ms), which matches the 2.25 times fewer pixels. This is the evidence that the GPU is fill-bound.
- Not checked: docked mode. The player setting `switchScreenResolutionBehavior` may switch the resolution on docking by itself.

## 3. Finding: PC Low halves the GPU cost of PC Medium

What `PC_Low_RPAsset` turns off compared with `PC_Medium_RPAsset` (same renderer):

| Setting | Medium | Low |
| :-- | :-- | :-- |
| Render scale | 1.0 | 0.8 |
| MSAA | 2x | off |
| Opaque texture | on | off |
| Main light shadow map | 2048 | 1024 |
| Shadow distance / cascades | 70 m / 2 | 40 m / 1 |
| Additional light shadows | on | off |
| Soft shadows | on | off |
| Color grading mode | HDR | LDR |

- Lobby GPU 177 to 97 ms, Tutorial 80 to 40 ms at the time of the test.
- The look of Low on Switch has not been judged by the art lead.
- **Status: test only.** The Switch quality level still points at `PC_Medium_RPAsset` in the committed project; the switch to `PC_Low_RPAsset` (`ProjectSettings/QualitySettings.asset`) and the locked index (`SettingsData.cs`, `? 0`) are uncommitted edits in the main tree.

## 4. Finding: the remaining cost is in the stage content

- At the same resolution, Game1 costs about 3 times the GPU time of Tutorial (70 vs 22 ms) and StageSelect about 2.5 times.
- Because cost tracks pixels, the likely suspects are things that touch many pixels: overdraw and transparency (the `GhostBuster/LitXRay` translucent wall pass), full-screen post-processing (Bloom, UberPost), real-time lights, grass and VFX. **These are not measured yet.**
- GPU time in Game1 also climbs during play (121 to 174 ms at step 2), probably from more ghosts and effects on screen or a wider camera; not checked.

## 5. Scene loads (step 3)

| Load | Total | Of which unloading the previous scene |
| :-- | :-- | :-- |
| Tutorial | 2.9 s | 0.3 s |
| AreaVideo | 1.7 s | 0.1 s |
| Lobby | 5.6 s | 1.8 s |
| StageSelect | 4.9 to 6.8 s | 1.4 to 2.3 s |
| Game1 | 10.7 s | 6.5 s |

Loading Game1 spends 6.4 to 6.6 s unloading StageSelect (three runs), while unloading Game1 takes 1.4 to 1.6 s. Worth a look later; not a blocker.

## 6. Build facts

- The first Switch build compiles every shader variant: about 2 h 24 min at Medium, plus 1 h 09 min for the PC Low variants (URP `Lit` 2,880 variants, `LitXRay` `XRayTranslucentWall` 1,536). Variants are cached in `Library/`; later builds take about 2 to 4 minutes.
- Build size: 5.1 to 5.2 GB NSPD.
- Builds run detached at Idle priority; at Normal priority the 12 shader compilers make the PC unusable.

## 7. Installable ROM

- `SwitchBuild.BuildDevelopmentRom` (menu GhostBuster > Switch > Build Development ROM (NSP)) builds `Build/SwitchRom/GhostBuster.nsp`: 1.69 GB, 1 min 26 s with cached shaders (`caa5f2db0`).
- Switch publishing settings now carry title "Catch Me Wooo Demo", publisher "Varisoft" and a placeholder 1024x1024 icon (`Image/Logo/SwitchIcon.png`, the game logo on a blue gradient) in every language slot. Real icon art is still to come.
- Installed into the EDEV system memory on 2026-11-13 with `DevMenuCommand -- application install --force`: `[SUCCESS]`. It starts from the HOME Menu without the PC. This ROM has the 720p fix and the uncommitted PC Low test settings, so it plays like step 3 above.

## 8. Recommended next steps

1. **Measure Game1 per pass** with the NVN / Low-Level Graphics Debugger (Unity for Switch manual §7.3.4): one frame capture shows which passes take the 70 ms. Do this before any further change.
2. **Decide the Switch base:** PC Low (2 times faster, look not yet approved) or Medium. Then commit the Switch quality level properly.
3. **Lock Switch to 30 fps** once scenes reach it, so Tutorial-like scenes do not swing between 30 and 60.
4. **Fixed Switch settings** (owner's note, handed to the team): on Switch, Screen Mode, Screen Size, Graphics, Light, VSync and Frame Rate have one fixed value and their rows are hidden.
5. **Check docked mode** (resolution and frame rate) once handheld is settled.
6. Then the CPU side of Game1 (render thread 14 to 20 ms) and the 6.5 s StageSelect unload.

## 9. Commits on `feature/nintendo-sdk` not yet pushed

`b50037b09` Switch input package · `919f181b5` TMP Overlay shaders always included · `dca3a8947` strict variant matching opt-in · `737e94c23` Switch settings written by builds · `d0a1cc4f1` Switch renders at 720p · `e51dd0a0c` merge of `fix/switch-720p` · `caa5f2db0` ROM build, title, publisher, icon · `1990ec87d` merge of `feature/switch-nsp-build`.
