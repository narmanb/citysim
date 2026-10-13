# MetroForge isometric implementation plan

**Goal:** Deliver a playable isometric version of the existing game and its offline resources without changing city rules or saves.

**Spec:** [isometric-design.md](isometric-design.md), based on the user-supplied conversion plan.

**Architecture:** Plain scripts expose a shared projection/geometry core and an isometric renderer factory consuming the existing game dependencies. Original atlas resources are loaded once, with generated JavaScript metadata for file-URL compatibility and matching JSON metadata for inspection.

**Constraints:** 52×52 tiles; preserve simulation, version-6 and older saves, Tap + pan, paint, pinch, history and overlays; CC0 supplied artwork only; main stays untouched; device verification must be reported honestly.

## Steps

- [x] Audit baseline commit, Android packaging and old upgrade workflows; launch and export/import a test city.
- [x] Write geometry and manifest tests; observe the missing core/manifest failures.
- [x] Implement `src/isometric-core.js`: projection/inverse, bounds, adjacency masks and contained parcel footprints; import source atlases safely and emit `assets/manifest.json` plus `assets/manifest.js` using `tools/import_isometric_assets.py`.
- [x] Prove grass, water, roads including turns/junctions, house, medium building and tree in `isometric-preview.html` using shared code; verify screenshot and pan/zoom.
- [x] Implement `src/isometric-renderer.js`, with renderer factory consuming the existing class/helpers. Test elevation picking, world/overhang culling, depth sorting and all overlay types before wiring default rendering in `MetroForge-2000.html`.
- [x] Exercise real city UI and save compatibility in Chromium, including touch input, multi-tile parcels, history, terrain, roads/bridges and moving agents. Fix any introduced failures with focused regression checks.
- [x] Implement a shared packaging script and include runtime files in the Android workflow; verify browser and Android asset trees without network access. Build APK only if SDK/Gradle are available.
- [x] Review the complete change, run final checks and provide a browser bundle, screenshots and documented remaining device/art limitations; retain feature branch for review, with no merge.

## Review focus

Map edges and negative screen coordinates must not wrap into another row. Camera zoom must preserve the world point under the gesture midpoint. Elevated surfaces must pick their own tile. Irregular parcels must not paint over neighboring roads or holes. Asset loading failure must produce a visible useful fallback rather than a blank game.
