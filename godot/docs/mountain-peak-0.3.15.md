# 0.3.15 — rounded preset summit correction

Rounded Hill/Mountain presets previously set only the center control tile to the
selected Peak. The shared rounded field averages surrounding controls, so the
visible summit fell short. A 5×5 balanced Peak30 on level ground displayed about
23.11. Small stamps suffered more attenuation.

New presets provide a 3×3 control neighborhood at the peak, with the selected
profile tapering the remaining shoulder. The visible center now reaches the
selected absolute elevation on clear, level ground, including raised plateaus.
The selected 3×3,5×5,9×9 footprint, bounds −5..30, $20/changed-cell cost and atomic
history remain. The smallest preset has steeper sides to reach its peak within
its selected footprint. Larger sizes give wider shoulders.

Peak is an absolute elevation, not height added to the tapped tile. On a plateau
at7, Peak12 makes the summit12, not19. Repeating a stamp at its existing Peak is
free; select a higher Peak or use Raise Terrain to raise it further. Higher
existing ground is preserved. Protected plots, roads, utilities and marked Cliffs
still block their own cells; a partially obstructed stamp can fall short of its
ideal summit. Clear ground is needed for the complete preset profile.

No renderer, existing save geometry, authored examples, materials, signing,
orientation, or save schema changed. Existing v13 cities retain their heights;
valid prior saves remain supported. The correction applies to newly made rounded
presets. Cliff presets retain their existing radial shape.

Verification: the new regression reproduced18 visible-height failures across all
three sizes/profiles and bases0/7. It now passes (582 total rounding checks).
All34 native suites and source-art/license receipts pass. Actual native OpenGL
captures compare23.11 before/30 after and exact cached/full pixels. Desktop
captures do not establish Galaxy S25+ performance.

Phone check: choose Create Mountain, Rounded, Peak30. Try each size on empty
flat land and on a raised flat plateau. Inspect the summit, shoulders, materials,
Undo/Redo and save/reopen. Confirm that a lower absolute Peak does not keep adding
height. Export the city before replacing the previous preview: persistent signing
is still deferred, so the temporary test certificate may require reinstall.
