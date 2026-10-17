# Building variety and automatic growth — unreleased source

The zoning palette stays at Housing, Business and Industrial. One connected Paint stroke creates a property; individual taps create individual properties. Existing properties are preserved when painted with the same zone family. Logistics remains removed. This change does not build or publish an APK.

## Development rules

New generic-zone properties opt into automatic growth. Homes, shops and light industry are the initial low-density types. A suitable property can initially choose, or later promote into, apartments, offices or heavy industry. Existing manually specified/imported properties retain their explicit type unless rezoned.

Every automatic property needs power, water and road access to develop. Denser development also requires an actual flat usable square of at least 2×2, sufficient demand and growth score, and adequate road condition. A bounding box containing holes, terrain steps or a narrow strip does not count. Housing and offices also require school/health coverage; heavy industry requires multiple bordering road tiles.

| Denser subtype | Population | Zone demand | Growth score | Land value | Average school/health coverage | Road condition |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Apartments | 120 | 28 | 48 | 48 | 0.15 | 0.50 |
| Offices | 180 | 25 | 48 | 52 | 0.10 | 0.50 |
| Heavy industry | 80 | 42 | 46 | 22 | — | 0.65 |

These are eligibility thresholds, not guarantees. A stable city-seed/property suitability value preserves a mixture of building types. Larger usable squares and better conditions increase the chance, capped below certainty. There is no fresh random reroll each month, and growth never automatically downgrades a subtype. Existing developed properties become eligible for promotion at level two. At most two such promotions occur per month, sharing the existing overall development budget. Occupancy, job capacity, utility consumption and pollution continue to use the actual building subtype.

## Appearance and terrain

There are 24 curated recipes: six houses, four apartments, four shops, four offices, three light-industrial and three heavy-industrial compositions. Six palettes provide cream, stone, terracotta, sage, slate and ochre walls/roofs. Selection depends on city seed, property identity and unit position; it does not consume simulation randomness.

Homes and shops draw an individual building on each member tile at that tile's elevation. A flat 3×3 apartment property draws four wings around shared courtyard paving. Other blocks use the largest supported flat rectangle, up to 3×3. Buildings do not stretch across a terrain step. This does not introduce smooth corner-height terrain or parcel subdivision.

The art combines existing Kenney CC0 modules, selectively recolored walls/roofs, storefront awnings and industrial shells/loading doors/chimneys. Factory bodies remain procedural composites. Windows, unselected pixels, transparency and source shading ratios are preserved. Original atlas PNGs and license receipts remain unchanged.

The generated render atlas contains the original 17 entries plus 132 color variants from 22 source modules. It remains one texture: 1024×2048, approximately 301 KiB PNG and 8 MiB uncompressed RGBA. `assets/building_styles.json` records recipe IDs, source rectangles/hashes, palettes and material masks. Rebuild with `godot --headless --path . --script tools/build_render_atlas.gd`.

## Validation

`python tools/check_project.py` runs the model, automatic-growth, persistence, asset, layout, cache, input, UI and performance-display suites. Automatic growth includes an actual connected young-town monthly development test and a mature-town promotion test with occupied neighbors, roads, power plants, pumps, schools, hospital and parks. The mature fixture promotes a level-two 3×3 housing property through a real monthly step and retains identical state across save/reload.

Asset tests verify all generated variants against recorded source material masks and preserve the original 135,317 atlas/source-border texels exactly. Layout tests cover nine-house properties, apartment wings, ground/object ordering, uneven terrain and camera-cache reuse. With a GL display, `godot --path godot --script tools/preview_buildings.gd -- /absolute/output/directory` captures the six building types and the apartment complex, then compares incremental apartment promotion/elevation edits with a complete rebuild pixel for pixel (run from the repository root).

## Desktop performance comparison

Paired runs used the same Harbor City fixture, the unchanged `tools/profile_city.gd` probe and a frozen source baseline at `a9fedbe`. Both used Godot 4.6.3 compatibility rendering, Mesa llvmpipe, 1280×591 output and sequential runs. Each sample measures 30 frames after warmup; these are software-rendered desktop measurements, not Android FPS.

| View | Previous draw calls | New draw calls | Previous median frame (ms) | New median frame (ms) |
| --- | ---: | ---: | ---: | ---: |
| Full city, static | 598 | 589 | 47.202 | 50.124 |
| Full city, moving agents/pan | 599 | 590 | 53.182 | 52.319 |
| District, moving agents/pan | 444 | 447 | 81.672 | 82.252 |
| Close, moving agents/pan | 250 | 258 | 77.526 | 77.447 |

The expanded art retains batching and similar measured rendering cost. This single paired run cannot establish a phone frame rate or a small speed difference. The existing FPS display remains available for the next Galaxy S25+ APK test.
