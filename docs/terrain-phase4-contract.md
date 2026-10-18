# Phase 4: rounded terrain, Smooth and radial presets

Scope is Terraforming 2.0 Phase4 only. Keep existing native saves, transactions,
flat/cliff foundations, source artwork and retained rendering. No water physics,
road grading or showcase city. Baseline c3b29d6, feature/godot-migration.

## One continuous surface

Rounded samples use a global tensor cubic B-spline field of integer tile-center
reference elevations. At position (X,Y), q=(X-.5,Y-.5). For each axis, let k=floor(q)
and t=q-k. Weights of centers k-1..k+2 are:

    [(1-t)^3, 3t^3-6t²+4, -3t^3+3t²+3t+1, t^3] / 6

The product weights form a convex average, normalized after excluding off-map,
water, channels and explicit Cliff coefficients. This stays in -5..12 without
overshoot. Every tile evaluates the same global coordinates, so adjacent Rounded
edges agree exactly, including intermediate samples. Same-level land stays flat.
A +12 reference summit may have a lower visible curved apex after filtering.
No reference heights change just to draw a surface. Fields never depend on
buildings, zones, roads, utilities, trees or biome: ordinary construction cannot
reshape neighboring terrain. Flat, Slope and Cliff keep their Phase3 cap rules.

The cap uses a fixed 4×4 subdivision, 32 triangles, retained in existing depth
buckets. The 2×2 subdivision is available to internal probes as a bounded quality
option; camera movement does not rebuild meshes. All visible edge segments,
previews, overlay fills and picking share the tessellated samples. Mixed edges
are deliberate retaining faces; crossing segments close with clipped triangles.
Flat/cliff/water caps are never smoothed by a neighbor. Original132×66 grass/sand
UVs are sampled per patch. Rounded lighting is shader tinting, not new artwork.

Only natural ground is rounded. New zones/civics/roads/rails require Flatten;
utilities and trees can still follow the sampled center. Geometry derivatives
have two-cell support; edited references invalidate nearby Rounded caps and
one additional ring of walls. Flat cities retain their existing fast path.

## Frozen deterministic editing

Smooth uses a frozen stroke-start reference grid, one/two/three Jacobi iterations
for Gentle/Medium/Strong, weighted self2 + each available cardinal neighbor1.
Only editable natural non-Cliff/non-channel cells participate; protected cells
are excluded as averaging inputs. Values outside the brush stay fixed. Final
references round to integers and change by at most strength1/2/3 per action.
Eligible changed cells become Rounded. An all-flat level brush is a free no-op;
equal-height shape conversions are charged only when the visible geometry changes.
Smoothing never modifies a deliberate Cliff or an occupied/infrastructure cell.

Create Hill/Mountain uses previewed square footprints3/5/9 (radii1/2/4), default5.
Peak is an explicit absolute reference height, default6 for Hill and12 for Mountain.
For each frozen stamp, r=distance/(radius+.5), weight=smoothstep(1-r)^exponent,
with exponents .7/1/1.6 for Broad/Balanced/Sharp. Target=max(original,
round(lerp(center_original,peak,weight))). A stamp whose peak does not exceed its
center is free. Multiple stamps combine by maximum, never cumulative raising.
Both default Rounded; an explicit Cliff preset gives stepped flat caps. Protected
cells, natural water, channels and marked Cliffs are skipped. Each changed cell
costs$20, one validated commit/recalculation and one Undo for the entire stroke.

The right panel keeps its compact layout. Smooth shows Brush and Strength;
presets show Size, Peak, Shape(Rounded/Cliff), Profile. Radius/peak/profile and
Smooth strength are session settings separate from Raise/Lower step and slope
strength. Existing tap/pan, native pinch, cancellation and pending previews apply.

## Saves and checks

Version8 adds Rounded to the existing optional shape schema; valid v6/v7 files
still normalize and import without regrading. No mesh/cache/UI data is saved.
Earlier builds reject cities containing Rounded tiles; export a backup before
installation and use the updated build for shaped cities.

Tests cover exact shared edge samples, constant planes, bowls/saddles/peaks,
negative and boundary cases, construction-invariant samples, frozen no-op and
protected Smooth, radial monotonic profiles, bounds/cost/stale commit, complete
Undo/Redo and native cancellation. Actual GL captures compare cached/full pixels;
dense flat and rounded fixtures measure draw calls and bounded cache rebuilds.
