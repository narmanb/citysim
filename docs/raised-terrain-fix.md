# Raised terrain and power-line vegetation — 0.2.2

The user's 0.2.1 Android test confirmed that flat terrain no longer changed when placing zones or power lines. A further screenshot showed raised grass as tilted pieces, with rectangular zone diamonds appearing detached from the visible ground. Power lines also retained trees on their tiles.

## Causes and correction

The grass mapping selected `landscapeTiles_022.png`, an authored ramp, although projection, picking, and zoning treated each tile as a flat 132 × 66 surface. The sand mapping selected a water-edge tile. Inspection of the newly supplied full Base collection confirmed the appropriate flat grass and sand artwork. The existing atlas already contains both replacements, so no new textures or license families are added.

- Grass now uses `landscapeTiles_067.png`; sand uses `landscapeTiles_059.png`. Importer and both runtime manifests agree.
- Terrain textures are clipped to their projected ground plane. PNG foundations cannot impose a different slope or depth. Exposed faces use stored neighboring elevations, and equal-height neighboring tiles join into a flat plateau.
- An opaque foundation with a small raster overlap prevents background cracks between tiles. Zone diamonds, terrain caps, and picking share the same projection and elevation offset.
- Static terrain and objects are painted once in complete depth order, then cached. Replaying selected ground over an already completed scene had altered nearby cliff edges and antialiased borders.
- Moving-agent regions are recomposed on a reusable offscreen canvas and copied as opaque device-aligned raster regions. Regional vector clips changed Canvas antialiasing even after boundary alignment; an independent review reproduced the discrepancy with invisible cars. Full wire bounds include connections to neighbors at different elevations, preventing regional rendering from erasing those wires.

This correction provides flat raised terraces. Height transitions remain stepped faces; editable corner heights and smooth slope transitions are not implemented by this update. The earlier all-grass ramp appearance was not a functioning slope model.

## Power lines and trees

Constructing a line clears its tile's tree within the existing construction/history action. Undo restores both the tree and the construction cost; redo clears the tree again. Tree and forest tools reject power-line tiles. Loading an older city clears tree flags beneath existing lines while retaining the lines and other city data.

No saved-city elevation values or serialization format are changed. Native activity code and the preview package identity remain unchanged.

## Verification

The new `tests/raised_terrain.py` checks ten behaviors: plateau surfaces and picking across elevations −3/0/2/5 and both biomes; real cliff depth; texture clipping; sealed tile seams; pole isolation on raised terrain; tree clearing with undo/redo; forest rejection; older-save cleanup; hidden-agent ground invariance; and wire preservation across large height differences. Failures were observed before their corresponding corrections. All ten pass. The two agent pixel checks also pass at display densities 1.5 and 2.

The existing geometry, runtime packaging, real browser controls/save/import/overlays/cache checks, native Chromium touch events, 36 pan/tree-isolation checks, foreground terrain/agent occlusion, growth artwork, simulated city/traffic, and workflow simulation smoke tests pass. Source syntax and whitespace checks pass.

The APK is built with versionCode 4 / versionName `0.2.2-isometric-preview`, retaining `com.narmanb.metroforge.isometricpreview` and the existing debug signing certificate. ZIP integrity, every runtime SHA-256 receipt, current source bytes, flat tile mappings, and APK signature are verified before delivery.

The added agent canvas uses one viewport-sized RGBA backing store. Desktop render checks are observations in Chromium, not measurements on Android. Device acceptance remains with the user's Android test; no connected Android device is available here. Managed Chromium still blocks direct file-URL navigation, while the packaged resource layout passes with nonlocal requests blocked.

Independent final review found no remaining Critical or Important issues. Both agent regressions passed independently at densities 1/1.5/2, and five mixed scenes with multiple cars, a train, trees, civic buildings, stacked offices, varying elevations, and overlays produced zero pixel differences with invisible agents across scales 7–100.

Final APK size: 771,076 bytes. SHA-256: `792a4415b9107fcf8aef61c66db31b43fbd6a24d2d3e759f46456e9eae2e597b`.

Delivery: `/workspace/artifacts/MetroForge-Android-Isometric-0.2.2-debug.apk`. Save the city before updating and install over the existing preview without uninstalling.
