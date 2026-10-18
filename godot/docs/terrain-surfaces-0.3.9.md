# MetroForge 0.3.9: terrain surfaces and optional grid

Terraform → Terrain surfaces paints appearance without changing heights,
rounded foundations, shape or biome. Choose Top (Biome, Grass, Sand, Rock,
Snow) and Slopes (Brown rock, Gray rock, Sand, Grass) in the persistent right
panel. Brush sizes remain 1×1, 3×3, 5×5. The “…” button on sculpt controls
opens the same appearance choices for new rounded terrain. Existing rounded
terrain retains its painted appearance during height changes; use the surface
brush to repaint it. Protected infrastructure, zoned land and natural water
are skipped. Cosmetic painting is free, including in debt, with one Undo/Redo
action per stroke. Unchanged paint has no history entry.

Snow is cosmetic summit coverage, without weather or seasonal simulation.
It blends in above 55–80% of local relief, measured against the bounded radius4
rounded peak sharing the same foundation. Other top colors blend above10–35%.
Exposed rock still follows steep slopes and cliff contacts. Large brush strokes
can paint an entire hill; small brushes paint individual parts. The clean,
simplified palette comes from existing art, without generated texture files.

Natural full grass, sand, water and dirt caps now use solid original colors,
removing grid lines baked into the source caps. Original PNGs/licenses are
unchanged. Curved bases fade to the exact original biome green/sand with zero
relief matching flat ground pixel for pixel. Existing cliff wall geometry remains.
Overlays → Map grid enables a thin analytic map-space grid on these caps,
including curved land. It is off by default, saved in user://view.cfg separately
from cities. Switching grid updates one shader uniform, without mesh rebuilds
or extra draw calls. Road markings and building details are still sprite art.

Save format10 adds optional surfaceTop(auto/grass/sand/rock/snow) and
surfaceRock(brown/gray/sand/grass). Default auto/brown values are omitted.
Versions6–9 import normally; save/import preserves new appearance and rejects
invalid identifiers. Older game builds have no controls/renderer support for
these materials, so retain export backups rather than relying on downgrades.

Verification:27 isolated native suites and original five-atlas/four-license
hash receipts, plus actual desktop OpenGL captures. Checks cover free atomic
paint/Undo/Redo, geometry/foundation preservation, no-op Smooth, Auto slopes,
invalid imports/settings, compact 854/640 layouts, live grid/persistence,
distant-peak material cache invalidation, exact cached/full raster equality,
flat/zero-relief base equality and no world mutation during rendering.
Independent review found the debt affordability issue; targeted tests failed
before the fix and passed after it. Harbor draw calls remain588/589/446/257
(fit/static, fit/agents, district, close). The243-rounded-tile fixture remains
202/155/124 at fit/district/close. Desktop software-render timing does not
establish Android FPS; Galaxy S25+ validation is still needed.

Persistent signing setup was explicitly deferred. Signing configuration and
package identity remain unchanged; the test-key fallback can require reinstall.
Export the city before testing. This version has a separate0.3.9 draft APK and
does not replace older downloads. No new hydrology, road grading, seasonal
systems, building artwork or showcase city is included.

Phone checks:

1. Export your city, install0.3.9 and import the backup if needed.
2. Paint an existing hill with Snow/Gray rock; try Grass/Brown and Sand/Brown.
3. Undo/Redo; save, close and reopen. Verify colors and heights stay correct.
4. Use “…” while creating a new mountain, select colors, then place it.
5. Toggle Overlays → Map grid; restart and confirm the choice persists.
6. Inspect the foot of grass mountains with grid off, pan/pinch at several
   zoom levels, and compare Harbor FPS with your previous build.

STOP after this update and await phone feedback.
