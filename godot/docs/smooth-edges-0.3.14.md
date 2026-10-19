# MetroForge 0.3.14 — smooth platform edges

## Controls and behavior

Choose Terraform → Raise terrain or Lower terrain → Shape Flat → Edges Smooth.
The Edges control stays in the compact right dock after closing the tool menu.
Sharp remains the default and retains the previous one-tile/brush behavior.
Smooth hides the redundant Shape row; switch back to Sharp to select other shapes.

Smooth creates one flat, buildable top across the selected brush or paint stroke.
Raise chooses a whole level above its highest original corner, plus the selected
step. Lower chooses below its lowest corner, minus the step. Heights remain
within -5..30. On uneven ground, leveling the whole top can move some cells more
than the selected step. This feature grades construction platforms; the separate
Smooth terrain tool and Rounded mountain tools retain their existing behavior.

The perimeter blends into unchanged ground with continuous Gentle grades, at
most one height unit across each tile. Corner bevels use matching triangles in
rendering, sampling, roads, picking and overlays. It does not flatten the city
back to ground level or add detailed mountain textures. Existing materials and
the optional grid retain their appearance.

Grading can extend beyond the selected brush. The preview shows all affected
tiles and the full price ($20 per changed tile), including this transition.
A 5×5 platform raised four units on level empty ground affects a 13×13 area.
A paint stroke uses its deduplicated selected cells as one level core, not a
separate repeated raise for every pointer sample. One commit, recalculation,
cash transaction and Undo/Redo cover the whole operation.

Occupied plots, roads, rail, utilities, natural water, channels, marked Cliffs
and Rounded ground are protected. If the transition needs to change protected
land or cannot meet a compatible boundary, the edit is rejected in full without
spending. Unchanged outside Auto slopes and Rounded dependencies cannot deform.
Use a smaller brush, more clear ground, or Sharp edges in those situations.
The map edge clips the transition; its outer retaining edge remains visible.
Bound/no-change previews are free. Touch cancellation and pinching discard pending
construction. Stale changed tiles and unchanged terrain dependencies reject before
mutation or spending.

Roads can climb the generated Gentle perimeter. Buildings remain upright with
level foundations on the grade, and the central top remains flat and buildable.
Rail and Rounded/steeper construction restrictions are unchanged. A single
building on a grade can still need its own small retaining pad.

## Saves and implementation

Save13 adds optional gradeCorners: NW,NE,SE,SW finite corner heights, within the
terrain bounds and with range at most1 on a fixed-direction Gentle slope.
Integer elev stores the rounded midrange reference. All grade triangles use the
NW–SE diagonal. Validation rejects malformed combinations. Valid v6–12 saves
remain readable; older APKs cannot interpret the new grade metadata correctly.
Export backups before testing or downgrading.

Flatten, manual shape changes and incompatible sculpting clear the explicit
corners; material painting preserves them. The grading planner is pure and
bounded to the52×52 map. Read-only terrain dependencies are guarded separately
from changed/charged/history tiles. Retained rendering and local invalidation
remain in place; there is no new per-frame terrain generation.

## Validation and phone checks

The native suites cover Raise/Lower, all brush sizes and steps, shared edges,
monotonic heights, map corners, bounds, costs, blocked/insufficient/stale edits,
serialization and malformed metadata, roads, level pads, exact rendering
triangles, persistent narrow controls, touch cancellation and pinch cancellation.
The native GL fixture tools/preview_smooth_edges.gd compares Sharp/Smooth, places
real roads and houses, imports/exports, and compares cached/full pixels exactly.
Original source atlas and license receipts remain checked.

Harbor's seven draw-call cases are unchanged from0.3.13 (588 fit/static,
589 fit/agents,446 district,257 close). Local software-renderer preview planning
medians for9,49,169 changed cells were2.42,9.73,36.23ms; these are desktop measurements,
not Galaxy S25+ frame rates. Large continuous strokes can involve more ground.

1. Export the current city before installing. Persistent signing is still deferred;
   the temporary preview certificate may require reinstall rather than update.
2. On clear level land, compare Sharp and Smooth with the same brush and step.
   Look for a level top and a continuous green perimeter without brown walls.
3. Lower land too. Check the preview's expanded area and price, then Undo/Redo.
4. Place roads over the ramp and houses on the top; inspect cars and foundations.
5. Try near construction, water and existing Rounded/Cliff ground: expect a clear
   rejection without spending when the transition cannot fit.
6. Pinch during a pending paint stroke; verify no construction or cash change.
7. Save/reopen and export/import, then compare Harbor FPS and both landscape
   orientations with Android Auto rotate enabled.

Sprite expansion, live wallpaper, mountain preset revisions and persistent
signing remain deferred. Stop after testing this feature; await the next request.
