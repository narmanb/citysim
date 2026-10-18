# MetroForge 0.3.7: rounded terrain follow-up

A flat height5 plateau raised with Rounded previously had reference heights6,
but its cap edges averaged with height0 neighbors and fell to1.5. New conversions
from Flat/Cliff during Raise, Hill or Mountain retain an optional integer
`roundedBase`. Those caps add a shared nonnegative cubic relief field above that
foundation rather than filtering the whole terrace down toward neighboring land.
Each cap filters `max(reference-base,0)` relative to its own foundation;
this keeps it below the highest contributing reference even across different
terrace levels. Natural water/channels/Cliff coefficients remain excluded. Equal bases share exact relief edges; different bases remain
deliberate terrace walls. Reference and visible heights stay within -5..12.
A plateau already at12 cannot receive a taller mountain under the existing cap.
Lower/Smooth keep the base no higher than their new reference; non-rounded
Shape, Flatten and channel digging remove it. All metadata is in normal tile
snapshots, so Undo/Redo and save/import restore it exactly.

Existing unbased Rounded cities retain their previous height field. Save version9
adds the optional foundation; valid v6/7/8 imports preserve geometry. Older0.3.6
can accept unknown metadata but renders its old absolute field, so use0.3.7 for
new foundation cities and keep exported backups.

The visible square patches were caused by a single normal/light color per patch.
The same analytic normalized spline now supplies vertex gradients, and adjacent
triangles interpolate shared vertex colors. The 4×4 subdivision and32 triangles
per tile remain unchanged. A vertex-colored polygon command joins the same
ordered texture batches; Fit bounds include this command too. Steeper flanks
blend toward muted stone colors. Grass/sand use their original sampled palette;
world-space procedural detail adds subtle variation without the atlas tile grid.
Fine detail fades at small zoom to reduce shimmer. No new image assets or passes,
no per-frame terrain mesh regeneration, and no new source artwork.

Checks: new726-check foundation suite covers plateau Raise/Hill/Mountain,
all rendered sample positions, single-cell/repeated Raise, Lower, exact history,
import, invalid metadata and Flatten/Cliff conversion. Rendering tests cover
shared vertex lighting, retained cache equality, curved picking and north-corner
Fit margin. Actual GL captures compare plateau before/raised and grass/sand at
close zoom, plus full-city fit; cached/full pixels match. The material probe now
compares average color (rather than demanding identical textured pixels): each
mean channel remains within0.005 of the flat palette, and mean pixel variation
must remain below0.02. This continues to reject old whole-surface darkening.
Desktop software-GL measurements do not establish Android FPS.

Phone checks:

1. Export your current city before installing; the unchanged test-signing
   fallback can produce another certificate, requiring uninstall/reinstall.
2. Raise a Flat3×3 plateau to5; choose Rounded and raise by1. Its walls/base
   should stay intact and a small rounded cap should appear above it.
3. Try Create Mountain on a Flat plateau below12. Undo/Redo the whole action,
   then save/reopen/import and compare its base and cash.
4. Inspect grass and desert hills at district/close zoom. The checker lighting
   should be gone; detail should stay attached while panning/pinching.
5. Use Fit with a tall Rounded corner, Flatten a cap and build on it. Check
   Harbor City's FPS and editing response on your Galaxy S25+.

This is a Phase4 correction. Phase5 hydrology/shoreline art and civil-engineering
work have not begun; building sprite additions and showcase-city work remain held.
