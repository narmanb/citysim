# MetroForge 0.3.4 terrain test

Branch: `feature/godot-migration`; baseline `f54ae82`.
This test continues Terraforming 2.0 Phase 3, after Phases 1 and 2.
It does not add rounded terrain, Smooth or Hill/Mountain presets.
The complete corner/edge contract is in `docs/terrain-phase3-contract.md`
at the repository root. Original Kenney atlas and license bytes are unchanged.

## What changed

- Undo/Redo are fixed outside the category scroller. The normal 854×394
  phone viewport fits every category alongside history. The selected tool
  remains in the map status on compact screens; narrower categories scroll.
- The last city opens automatically. A separate `resume-city.json` checkpoint
  is written every 15 seconds when dirty and outside construction gestures,
  and synchronously when the app loses focus/backgrounds or exits. Encoding,
  backup validation and periodic disk writes run on a detached snapshot in a
  worker. Manual Save/Load still uses `city.json`. First upgraded launch can
  resume the manual slot if no automatic checkpoint exists. No offline
  simulation or wallpaper service is implemented.
- Checkpoints use atomic replacement and a previous valid `.bak`. Damaged
  checkpoints recover from backup; if both are unreadable, their original
  bytes are copied to numbered `.recovery` files before allowing replacement.
  Failure to preserve them disables autosaving and displays the failure.
- Terraform → Shape terrain converts eligible natural cells to Flat, Sloped
  or Cliff without changing their reference height. Raise/Lower also apply
  the selected shape to changed cells. Flatten restores a flat construction
  top, even if the reference height was already correct.
- Sloped supports Auto/N/E/S/W high edges and Gentle/Medium/Steep strength.
  Strength is separate from the height-step control. Auto needs neighboring
  reference-height differences; on a level neighborhood choose a manual
  direction. Matching ramp edges join exactly; other edges have retaining
  faces. Grass and desert keep their original texture caps.
- New zones, roads, rails and civic buildings require flat/cliff tops.
  Flatten first. Trees and utility bases follow the surface. Shaping skips
  zones, structures, utilities, natural water and non-flat channels. No new
  water physics or automatic regrading is performed.

## Phone checks

Export your existing city before changing test APK installations. App data,
including automatic checkpoints, is lost if Android requires uninstalling a
preview with a different test certificate. Installing an APK over an app
with a matching certificate preserves its data.

1. Confirm Terraform, Undo and Redo are all visible in landscape. Open Shape
   terrain; choose Sloped, E, Medium and 3×3. On empty flat land a tap should
   create a ramp patch. Try each direction on grass and desert. Height limits
   remain −5 to +12; ordinary Flat terrain should still look unchanged.
2. Undo/Redo that brush, including its treasury cost. Try a two-finger pinch
   halfway through a Paint drag: no terrain or money should change. Preview
   and final shape should agree. Tap visible caps and cliff faces at close
   zoom to check selection.
3. Flatten a ramp at the same reference height; then zone/build on it.
   Protected structures and natural water must not move or disappear.
4. Import your city, change something, press Home, then reopen. Repeat after
   removing the app from recent apps. The imported/edited city and treasury
   should return. Also test opening a different city and restarting.
5. Pan/zoom Harbor City and watch FPS, especially at Fit. Report sustained
   slowdown or freezes; desktop software-renderer timings are not phone FPS.

Manual export remains the recommended transferable backup. A crash or forced
kill before checkpoint/background handling may lose up to one checkpoint
interval. Camera position, construction history and tool preferences reset
on launch; the city itself resumes.

## Reproducible validation

Verified locally: `python godot/tools/check_project.py` passed all 19 suites,
including 431 elevation-bound checks, 130 terrain-editor checks, 59 shape
math/schema checks, 49 controller/gesture/layout checks, 746 automatic-growth
checks, native persistence/recovery/restart, UI and original atlas/license
integrity. Actual GL cached/full fixture pixels matched exactly. One mouse
Shape-cancellation bug was reproduced before its fix and passed afterward.
An independent whole-change review approved the final production changes.

Run `python godot/tools/check_project.py` for the complete native suite.
New suites cover shape math/schema, actual shaped picking/walls/cache and
session snapshots/recovery/restart. Controls tests cover native shape touch,
background cancellation, mouse cancellation, Undo/Redo and narrow settings.
Tests use isolated user directories, so they cannot resume a developer city.

For actual GL screenshots and cached/full pixel comparison:

```
DISPLAY=:102 godot --audio-driver Dummy --rendering-method gl_compatibility \
  --path godot --script tools/preview_terrain_shapes.gd -- /tmp/terrain-shapes
```

Internal render fixtures are not distributed showcase/save-city replacements.

### Harbor City render comparison

Same existing no-logistics Harbor City, population 4371, 1280×591 output,
854×394 logical viewport; Godot 4.6.3 compatibility renderer, Mesa llvmpipe,
two-core container, `LP_NUM_THREADS=2`, separate sequential processes. Both
versions recorded exactly the same terrain/object command counts and 360
static layers. The compact tool label removes one UI draw call.

| Scenario | Baseline calls | Candidate calls | Baseline median ms | Candidate median ms |
|---|---:|---:|---:|---:|
| Fit static | 589 | 588 | 62.881 | 55.118 |
| Fit moving agents | 590 | 589 | 59.294 | 66.531 |
| District moving agents | 447 | 446 | 110.815 | 82.963 |
| Close moving agents | 258 | 257 | 68.856 | 99.667 |

Frame timings are inconsistent across scenarios and runs (including large
software-renderer outliers), so wall-clock performance regression is
inconclusive on this host. These results establish retained batching and
unchanged old-city geometry; they do not establish Galaxy S25+ FPS. Shape
cache tests prove local invalidation rather than per-frame full rebuilding.
