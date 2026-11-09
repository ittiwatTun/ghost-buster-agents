---
name: unity-scene-capture-no-handles
description: unity-editor-mcp screenshot and capture_scene_view render the scene camera only, without Handles, gizmos or the navmesh display; a Scene view in 2D mode ignores LookAt rotation
type: reference
---

`mcp__unity-editor-mcp__screenshot` (view scene) and `capture_scene_view` render the Scene view camera alone. Nothing a `SceneView.duringSceneGui` handler draws with `Handles`, no gizmo, and not Unity's navmesh display appear in the image, so a Scene view overlay cannot be checked from a capture.

The Scene view camera only moves on a repaint, and it does not repaint while the Editor is in the background: `editor_focus` first. A Scene view in 2D mode keeps rotation at identity whatever `LookAtDirect` is given: set `in2DMode = false` first.

**Why:** 2026-09-28, checking `NavGeometryOverlay` on map0001. Four captures showed no overlay, first from the origin, then flat in 2D mode.

**How to apply:** check an overlay's state through its fields by reflection (it loaded the file, and the edge count is right), and check the geometry numerically (`NavMesh.FindClosestEdge` against the obstacle faces). Leave the visual comparison to the owner. An ad-hoc `GL` render into a `RenderTexture` misprojected here, so it is not a substitute.
