# MetroForge0.3.10 — seamless mountain feet and terrain to30

The thin south/east mountain border was real geometry. Rounded spline samples
were still up to0.1041667 above adjacent flat land at the edge of a Sharp5×5
preset. This triggered tiny vertical retaining faces. Hiding the grid could not
remove that wall. A world-space C1 taper now brings added rounded relief and
its analytic derivatives to zero at dry flat cells sharing the foundation.
Multiplying the smooth distance masks keeps corner transitions continuous.
This adjusts mountain-foot geometry, not saved reference heights, neighbor
cells or the brush footprint. Preview, render, picking and utility anchors use
the same Geometry contract. Deliberate Cliffs, water shores and different-height
foundations retain their walls. No source PNGs or material controls changed.

The upper elevation bound is now30; the lower bound remains-5. Raise, Lower,
Flatten, slope sampling, Peak selector, import validation and height-ray picking
share the bound. Mountain defaults to12, with selectable heights up to30; Size
still offers3×3/5×5/9×9 and Profile offers Broad/Balanced/Sharp. Peak is the
reference/control height; rounded spline smoothing can produce a visibly lower
summit than its highest reference tile. Use Size9×9 for a wider large mountain.

Saves now use version11. Existing versions6–10 import normally. Height30 and
all lower legal integer values survive export/import. Older releases reject
heights above12; retain backups before downgrade testing. Optional surface
materials, foundations and automatic city resume continue unchanged.

Verification includes28 native suites, original atlas/license hashes, a328-
check mountain-foot regression (109 failures before fix,0 after), and an828-
check bounds suite through30 (464 failures before range change,0 after).
Native Peak30 control/preview, visible height30 cliff picking and Fit with a
building at the high map edge are covered. Actual OpenGL before/after12 and
height30 captures check exact cached/full raster equality and no render-time
world mutation. Shared curved-edge heights/normals and intentional walls are
checked. Neighbor shape changes are included in mesh signatures, because the
foot taper depends on Flat versus Rounded even at equal height. No per-frame
mesh rebuilding, additional nodes or subdivision increase. Desktop software
rendering does not establish GalaxyS25+ FPS or Android shader appearance.

Phone checks:

1. Export your city before installing; signing setup is still deferred and
   the temporary test key may require uninstall/reinstall.
2. Create a Sharp5×5 mountain on level ground, grid off. Inspect its south/east
   foot at close zoom. There should be no thin straight brown perimeter wall.
3. Set Peak30, try Size5×5 and9×9. Compare with Peak12; smaller peaks remain.
4. Tap raised terrain, use Fit, inspect cliffs/shores, then Undo/Redo.
5. Save/reopen and export/import. Check that heights and material colors stay.

No new showcase city, hydrology, seasonal systems or building artwork.
Stop after this update and await phone feedback.
