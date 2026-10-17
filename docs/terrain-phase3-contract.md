# Phase 3 geometry contract

Reference: the uploaded Terraforming 2.0 plan. Scope: planar slopes and
intentional cliffs; no rounded surfaces, smoothing, hills or water physics.

Map corner order is NW=(x,y), NE=(x+1,y), SE=(x+1,y+1), SW=(x,y+1).
The names are map directions, not the screen's slanted axes:

```
NW ----- N ----- NE
 |                |
 W      tile      E
 |                |
SW ----- S ----- SE
```

`elev` remains the integer reference. Flat and cliff corners all equal it.
Slopes have a total rise of 1, 2 or 3 units (Gentle, Medium, Steep), centered
on that reference and clamped to -5..12. N/E/S/W selects the HIGH edge:
N=[+, +, -, -], E=[-, +, +, -], S=[-, -, +, +], W=[+, -, -, +].
Corners are bilinearly sampled (these four patterns are planes).

Auto compares E-W and S-N reference-height differences. The dominant axis
wins; ties choose X, then sign selects its high edge. Missing boundary
neighbors use the current reference. An existing Auto slope on a zero
neighbor gradient uses N deterministically. Creating a new Auto slope on a
level neighborhood refuses for free and asks for a manual direction; it
never creates invisible metadata. Raise/Lower computes all candidate
heights first: zero-gradient interiors remain flat, with sloped edges.

Example: adjacent E, Gentle ramps with references 0 and 1 have corner
heights [-.5,.5,.5,-.5] and [.5,1.5,1.5,.5]. Their shared E/W edge is
exactly [.5,.5]. Equal-reference E ramps instead form separate hard steps;
these are intentional incompatible patches, joined by retaining faces.
No global neighbor height changes are made to force arbitrary ramps to fit.

Every visible front edge (E and S) compares both corner heights with the
neighbor's opposite edge. Positive differences produce a wall. A crossing
edge is split at the exact linear intersection, producing a triangle.
Coincident edges produce no wall. Border walls retain the previous zero
base for old flat terrain, extending down to a negative shaped edge when
needed. Caps, UVs, faces, picking, previews and object anchors use this same
helper. Grass/sand sample the original 132x66 cap without its sprite walls.
No source artwork is changed.

Version 7 adds optional `terrainShape` (flat/slope/cliff), `slopeDir`
(auto/N/E/S/W), `shapeStrength` (1/2/3). Missing version-6 fields normalize
to flat/auto/1. Unsupported metadata is rejected. Save round trips retain
all authored choices. Older builds ignore unknown fields and will display
new ramps as flat; use the updated build for shaped saves.

Shape terrain changes shape without changing reference height. Raise and
Lower also apply the selected shape when height changes; Flatten always
creates flat caps, including at the same reference height. Flat/cliff
canonicalize direction and strength to auto/1. Each changed cell costs $20,
no-op cells are free. Natural water, channels, occupied terrain and utility
cells are protected from shape edits. Existing flat channel height editing
and reflow are retained. Digging a new channel restores flat metadata.

New buildings, zones, roads and rails require a flat/cliff top; a slope
returns a Flatten-first warning. Existing cities are not regraded. Trees
and utility bases use sampled surface heights. Utilities may cross slopes;
new shaping cannot disturb utilities already present. Water stays level.

Retained rendering preserves the old flat fast path. A changed tile also
invalidates adjacent Auto slopes and the walls touching those slopes (two
local rings only when required), never a per-frame global mesh rebuild.
