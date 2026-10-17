# MetroForge 0.3.3 terrain test city

Use **MetroForge Godot 0.3.3 Terrain Test**. This is a focused test map, not the later showcase city. The original Harbor City and small test city are unchanged.

Import `MetroForge-Terraform-Test-City-0.3.3.json` through **City / Files → Import JSON file**. If using the ZIP, extract it first. It contains exactly one city JSON, this checklist and a preview. Back up your current city first, then **pause the simulation** after importing. Re-import this file whenever you want to reset the tests.

The map is 52×52 and starts with **$1,000,000**, **247 residents**, **219 jobs**, eight cars and two rail stops. Its neighborhood has working power/water and current building styles. No game code or APK changes are needed to import it.

## Find the test areas

The screenshot uses the normal isometric view. The large road-framed grass field is central; the town is on its right; the desert patch is in front/right; the lake/bridges/channel are left/front. The tall bare plateau is behind/left of the field and the deep basin is just outside its left/front edge. Pan/zoom freely; Fit shows the complete map.

Coordinates below are the game's one-based tile inspection coordinates (x, y):

| Landmark | Useful tile | Starting state |
| --- | --- | --- |
| Open grass inside the road frame | (22, 22) | Height 0; clear 3×3 brush area |
| Stepped desert pad | (36, 29) | Eight-by-eight sand area, heights 0/2/4/6 |
| Bare high plateau | (11, 19) | Height +12; editable, no zoning |
| Deep basin | (18, 33) | Height −5; editable dry ground |
| Channel gate beside lake | (13, 39) | Height −1; downstream channel starts filled |
| Separate buried pipe / power pole | (27, 21) / (27, 22) | Protected utility cells inside grass field |

## Phone checklist

1. **Brush and cost.** Choose Terraform → Raise terrain, reopen Terraform, set **3×3** and height step **2**. Tap clear grass near (22,22). Preview should show nine cells and **$180**. One tap raises them two levels. One Undo should restore all nine and refund $180; Redo should reapply all nine. Keep the city paused when comparing cash.
2. **Paint overlap and gestures.** Switch to Paint drag. Paint a short line, then a loop that crosses itself. Each touched cell should change once per stroke; retracing should not add unexpected cells or cost. One Undo restores the entire stroke. In Tap + pan, dragging pans without spending. A two-finger pinch during a pending paint stroke should zoom/pan and discard the pending edit. If the phone cancels a touch, no queued edit should appear later.
3. **Flatten.** Choose Flatten, reopen Terraform, set **5×5**, **Set height → 3**, then tap the center of the stepped sand patch. The complete 25-cell area should become flat at +3 for **$500**, while staying sand. Undo restores its original steps. Also try First touched tile: its height becomes the target for the rest of that footprint.
4. **Limits, selection and Fit.** With **1×1**, Raise on top of the bare +12 plateau and Lower in the −5 basin. Both should make no change or charge. Try selecting/editing visible plateau tops and cliff sides; taps should not edit hidden land behind a wall. Fit should include the full map and tall buildings. Existing cliffs remain vertical; slopes/rounded terrain are not in this update.
5. **Protection and water.** Try a larger brush across the town, roads/rails and utility cells. Buildings, zones, infrastructure and natural lake water should be marked blocked and remain intact; eligible neighboring ground can change. For the optional channel test, use 1×1 Raise/step2 on the first channel tile beside the lake at (13,39): −1 becomes +1 and downstream channel water dries. One Undo restores both the gate and distant channel water. Ordinary grass should not flood.
6. **Save and performance.** Export your edited city to a new JSON filename, import it again, and check your heights/biome/buildings. Compare FPS at Fit and close zoom while panning and after a 5×5 edit. Report any freeze, misplaced edit, unexpected charge, floating object or import failure. Include a screenshot, selected operation, brush/step/target and FPS if visible. Unpause afterward to check the neighborhood still simulates normally.

## Verification and reproduction

The generator uses the existing native model and export schema, then validates the result with `CityStore` and the game's actual native file-import callback. It also checks brush/Flatten costs, bounds, protected cells, channel reflow, Undo/Redo and an unaffordable edit on separate copies. Construction Undo preserves terrain/infrastructure and cost; occupancy remains derived by normal city recalculation.

Run from the repository root:

```sh
godot --headless --path godot --script "$PWD/examples/build_terrain_test_city.gd" -- /absolute/output/folder
```

With an X11/Wayland display and `--rendering-method gl_compatibility`, the same generator additionally captures `Terrain-Test-City-Preview.png`. Tested against the game source used in APK commit `43979e90c0a0e268c2cdac244c4e6c6393074aab`: **392 checks passed**. This proves the generated data/import paths on desktop, not phone touch behavior or Android FPS.
