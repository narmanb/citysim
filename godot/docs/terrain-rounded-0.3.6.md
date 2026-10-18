# MetroForge 0.3.6: Terraforming Phase 4

Rounded terrain now uses a shared cubic reference-height field, rendered as
retained 4×4 patches (32 triangles per tile). Connected Rounded edges match;
flat, sloped, Cliff and water tiles preserve their existing surfaces. Mixed
edges use retaining walls. Shore ribbons follow the cap triangles. Grass and
desert sample the original atlas; no artwork or building palettes changed.
Reference height is not necessarily the curved surface's maximum height.

Smooth uses a frozen stroke snapshot and bounded Gentle/Medium/Strong passes.
It preserves occupied tiles, infrastructure, natural water, channels and marked
Cliffs. Create Hill/Mountain provides Size 3/5/9, absolute Peak (-5..12),
Broad/Balanced/Sharp profiles and Rounded/Cliff shape. Presets raise land toward
the selected peak; they do not excavate depressions. One stroke is one atomic
priced action and one Undo. Repeated samples within that stroke do not stack.
Cliff presets mark only raised cells. Settings stay in the compact right panel.

Use Flatten before placing buildings, zones, roads or rail on Rounded land.
Trees, power lines and pipes can follow sampled curved terrain. Construction
never changes the underlying height field. Deliberate water-surface conventions,
riverbanks, civil-engineering grading and further art polish remain Phase 5.

Valid version-6/7 cities import without forced reshaping; new saves use version8.
Earlier previews cannot import Rounded cities. Export a backup before installing:
unchanged CI test-signing configuration may produce another certificate, which
requires uninstall/reinstall. This separate preview uses versionCode7 and leaves
all earlier release assets intact.

Phone checks (Galaxy S25+):

1. Select Create Hill, keep Rounded and 5×5, place one on open land. Inspect
   full-city, district and close zoom; look for seams or disconnected diamonds.
2. Change Peak/Profile/Size from the persistent right panel, close Terraform,
   and place another preset. Undo/Redo must restore the entire action and cash.
3. Smooth a raised area with each strength. Check that nearby Cliff markers,
   occupied land and water remain unchanged. Smooth on level land costs nothing.
4. Try a negative valley and a coast. Pan, pinch and cancel a pending stroke;
   cancelling must leave cash and terrain unchanged.
5. Flatten part of a hill, then zone/build on it. Place a tree or power line on
   curved land and confirm its base follows the visible surface.
6. Save/reopen/import the edited city and compare with the original. Monitor
   the in-game FPS counter while viewing Harbor City and while editing terrain.

Automated commands:

- `python godot/tools/check_project.py` (22 isolated native suites + art receipts).
- `godot --path godot --script tools/preview_terrain_phase4.gd -- OUTPUT` on a
  GL display: actual fit/district/close captures and cached/full raster equality.
- `godot --path godot --script tools/test_rounded_lighting.gd` on a GL display:
  zero-grade Rounded versus flat material comparison.
- `tools/profile_city.gd` on the same GL display, fixture and settings for the
  previous source and this source. Desktop software-GL results are not phone FPS.
