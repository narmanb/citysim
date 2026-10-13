# Isometric conversion validation — 2026-10-13

Feature branch: `feature/isometric-renderer`. Base: `163a698275c2c4250a6d9b095902c5adca3dffe4`. No remote push or merge performed.

## Verified

- Original browser launches, actual Save/Load and Export/Import round-trip baseline city tiles, cash and seed.
- Supplied starter: 972 ZIP entries, 957 PNGs, four Kenney CC0 packs. Original bytes of five selected atlas PNG/XML files are preserved; manifest hashes and crop bounds validate, and all four licenses are packaged.
- Small interactive art proof pans/zooms and shows consistent grass, water, end/straight/corner/intersection roads, houses, a medium building and trees.
- Ten Node geometry/asset tests pass, covering 2,704 tile centers at multiple zooms, elevated picking, zoom midpoint preservation, all adjacency masks including edges, contained irregular-parcel footprints, sprite overhangs, cliff extents and bridge guardrail axes.
- Real game browser checks pass: road placement, default drag-panning without construction, painted shared parcels, undo/redo, successive elevated placement and inspection, local Save/Load, exported/imported JSON, older optional-field defaults, all thirteen overlays and ground-cache reuse.
- Real Chromium touch events pass for landscape tapping, panning, parcel painting, and a two-finger pinch in paint mode without unintended construction or spending.
- Existing simulation smoke checks pass for commercial/logistics parcels, connected channels, full parcel power/water propagation and greater apartment capacity. The old parcel workflow test also failed on untouched main: it changed `resType` without updating higher-priority `zoneType`. Only that test setup was corrected.
- Byte comparison confirms World/simulation and SaveManager/history/InputManager/UI implementations remain unchanged. HTML changes add resource scripts and instantiate the separate isometric renderer.
- A city built with existing placement methods and simulated for 36 months grew 32 developed tiles, 181 residents and 222 jobs. It has a working bridge, two connected rail stations, one route, and observed moving cars and a train. The existing Events UI triggers a real building fire under deterministic test randomness.
- Pixel regression proves that raised foreground terrain hides a car behind it. Opaque terrain foundations also prevent partial-alpha interior PNG pixels leaking car colors. Separate pixel checks confirm that houses and industry visibly change from level 1 to 2.
- Runtime packaging test passes: browser and Android resource trees contain identical HTML/scripts/textures/licenses with verified hashes. The packaged Android resource layout loads in Chromium with all nonlocal requests blocked. Missing atlas files show a useful notice and procedural fallback instead of a blank city.
- Embedded and separate JavaScript syntax checks, Python compilation and `git diff --check` pass.

## Desktop measurement

On headless Chromium in this workspace, the populated test city at scale 40 has 560 visible ground tiles and 53 static objects. Across 80 ordinary animation frames, median draw time was 1.5 ms and p95 was 2.8 ms; median frame interval was 16.7 ms and p95 was 17.0 ms. These are desktop browser observations, not Android measurements or a guaranteed frame rate.

## Art and device limits

The supplied subset lacks the proposed modular/vector comparison families and dedicated civic, power/water, industrial and rail sprites. Those systems use readable procedural composites/labels. Terrain uses stepped elevation faces and shoreline edges rather than authored smooth slope transitions. No external assets or paid generation were used.

Managed Chromium rejects `file://` navigation with `ERR_BLOCKED_BY_ADMINISTRATOR`, so a direct browser file-URL launch could not be verified here. The runtime uses ordinary local scripts and Image loading and makes no fetch/API requests. Actual Android WebView file loading, APK compilation, persistence/import/export, memory and frame rate require device verification. This environment has Java 21 but no Gradle, Android SDK, sdkmanager or adb; no APK is claimed as built or tested. The updated workflow uses SDK 35, Gradle 8.10.2 and Java 17 and copies the complete offline runtime.

Review the browser milestone before merging into main; review dedicated civic art and performance on the target device before release.
