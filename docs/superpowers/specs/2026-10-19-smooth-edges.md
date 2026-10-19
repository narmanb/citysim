# Optional smooth edges for Raise/Lower

User approved the proposed optional Smooth edges setting: preserve a flat,
buildable edited top and grade its perimeter into clear neighboring ground.
Base ddaa32d, migration worktree, Godot4.6.3; original Sharp behavior remains default.

Edges Sharp/Smooth appears for Flat Raise/Lower in the existing persistent dock.
Smooth hides the redundant Shape row. Other shapes/modes retain prior controls.
The selected brush/stroke becomes one level top: Raise chooses a whole level
above its highest original corner by the selected step; Lower chooses below the
lowest corner. Clamp -5..30. Bound/no-change remains free. Graded transition land
may extend beyond the brush; preview and charge every changed tile at$20. One
atomic transaction, recalculation and Undo; no touching protected infrastructure.

A multi-source Chebyshev wave propagates one height unit per tile from the four
corners of the top. It stops where it meets unchanged ground, map limits or an
ineligible transition. Core vertices are exact level height; shared transition
vertices use identical values. Preserve monotonic Raise/Lower at all corners.
Nonplanar corner bevels use the same NW/SE triangle split for samples and drawing.
This is continuous low-poly Gentle grading, not Rounded mountain smoothing.

Store optional gradeCorners on Gentle fixed-direction slope tiles, four finite
bounded heights in NW/NE/SE/SW order with range<=1. Integer elev remains a rounded
midrange reference. Shared geometry, roads, foundations, picking and previews use
these exact corners. Save13 reads valid v6–12; malformed grades are rejected.
Manual Shape/Flatten/Sharp edits and Rounded sculpting clear obsolete grade data;
surface painting preserves it. Foundation validation uses actual corner maximum.

If a new transition cannot meet an existing/protected boundary, reject the whole
transaction with a clear-space message, no cash/history change. Do not silently
alter remote terrain. Explicit Cliffs, Rounded ground, water/channels, plots and
utilities block transitions that would change them. Reject edits that would
indirectly rotate outside Auto slopes or deform outside Rounded dependencies.

Verify shared edges/corners and no internal dirt faces, Raise/Lower/steps/bounds,
overlapping strokes, cost/stale/insufficient/protected cases, grade imports and
construction, cancellation and narrow persistent controls. Native screenshots
compare Sharp/Smooth and show buildable tops, roads and pads; cached/full pixels
must match. Preserve retained rendering, materials, water rules, source art,
orientation and signing. Separate0.3.14/code15 APK after full suite/review.
