# MetroForge 0.3.8: terrain art alignment

Rounded terrain now uses clean, solid colors from the existing grass/sand
palette. Fine procedural noise is removed. Shared vertex lighting remains
continuous, so the old square patch shading does not return. Steep areas blend
into broad brown rock using the same two face colors as regular cliffs, with a
lighter brown top. Directional shading interpolates toward those face colors.

Exposed land edges receive a narrow rock transition on the curved cap. The rim
uses actual sampled edge drops, skips water/channel shores, and reconciles all
caps sharing a boundary vertex. A cliff terminating beside two curved tiles
therefore cannot leave a brown/green color seam at their common edge. Equal
curved edges stay grass unless nearby exposed rock reaches that vertex.
This is material blending; deliberate terrace walls stay vertical and geometry,
foundations, placement, picking, Undo/Redo and save version9 are unchanged.

The same retained4×4 cap meshes,32 triangles per Rounded tile and ordered texture
batches are used. No image assets, additional draw passes, scene nodes or
per-frame terrain rebuilds are introduced. The fragment shader does less work
by removing the two-frequency noise. Desktop software-render timings do not
establish Android FPS. The243-Rounded-tile probe retains202/155/124 draw calls
at fit/district/close, matching0.3.7.

Verification:24 isolated native suites plus original art/license receipts;
actual GL mixed-cliff/grass/desert captures, edited-neighbor invalidation,
cached/full pixel equality, fit/district/close and narrow controls. The native
rock palette/rim tests failed before implementation and passed afterward. The
terminating-cliff test reproduced independent review's seam, then passed after
boundary reconciliation. Level Rounded material color range fell from0.0667
to0.0; mean color remains within0.005 per channel of ordinary flat grass.

Phone checks:

1. Export your city before installing. The unchanged CI test-signing fallback
   can produce a different certificate, requiring uninstall/reinstall.
2. Inspect existing grass and desert hills near trees/buildings. They should
   look clean, with brown exposed rock and no speckled grain or patch grid.
3. Combine Rounded mountains and Flat/Cliff terraces. Inspect contacts,
   especially where a cliff ends beside two connected curved tiles.
4. Raise/Lower a tile at that contact, then Undo/Redo. Check that colors update
   without gaps or changes to the surrounding terrain's heights.
5. Pan/pinch and check FPS in Harbor City. Existing v6/7/8/9 cities still import;
   save version9 remains unchanged, so this update adds no schema migration.

Scope decision: selectable Grass/Snow summit cover remains a later feature,
as sequenced in the approved plan. Snow settings, hydrology/road grading,
new building sprites and showcase-city work were not implemented here.
