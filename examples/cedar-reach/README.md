# Cedar Reach — MetroForge terrain variety city

For MetroForge Godot **0.3.14 or newer**. This is a 52×52 playable city save,
format 13, using the new Smooth edges geometry. Earlier APKs do not interpret
its graded corners correctly.

## Import

1. Export your current city if you want to keep it.
2. In the game, choose **City / Files → Import JSON file** and select
   **MetroForge-Cedar-Reach.json**.
3. Save the imported city in the app if you want it as your last-open city.

If you downloaded the ZIP, extract it first. It contains only one city JSON;
the README and PNG files are guides/previews. Do not import the ZIP itself.

## Explore

- **Main city:** a dense mixed-use center, a higher terrace, parks and civic
  campuses, apartments, offices, shops and varied building recipes/colors.
- **Hillside homes:** detached plots on Gentle grades, with real level pads.
  Roads climb the graded approaches rather than flattening the whole city.
- **Lakeside town:** a distinct low-rise neighborhood on another part of the
  map, separated by the lake, forest and valley road. Forty small developed
  plots keep it visually different from the tower district.
- **Work district:** light/heavy industry and offices, buffered from housing
  by woods. Four power plants, four pumps and two towers supply the settlements.
- **Transport:** a connected road network, a two-cell river bridge with dry
  landings, a lower-city rail loop and four stations. The save has 70 cars and
  two trains; it uses the existing road/rail simulation and assets.
- **High country:** snowy/rocky peaks and forested foothills, with the highest
  terrain reference at +30. There are 61 tiles at +20 or higher.
- **Water:** a large irregular lake with a wooded island, a northern river with
  negative channel beds, an elevated forest pond, beaches and low grassy banks.
  The eastern lake also has higher rocky cliff banks.
- **Dry country:** sandstone mesas, dunes, stepped cliffs, exposed Medium/Steep
  tilted strata and a dry terraced quarry reaching −5. The dry quarry stays
  dry under the existing channel-connectivity rules.
- **Materials:** grass/biome, sand, rock and snow caps; brown, gray, sandy and
  grassy slopes. Original game artwork is used throughout.

Across 2,704 cells: 329 water, 776 trees, 691 Rounded terrain, 120 marked Cliffs,
544 Gentle graded cells and 22 Medium/Steep slope cells. There are 18 level
foundation records. Flat land is concentrated around settlements, clearings,
shores and the deliberately flat desert terraces.

## Starting city

Population **3,786**; jobs **3,459**; idle workers **9%**. All 100 developed
properties and all non-plant civic facilities have power and water.
Power: 1,162 / 2,200. Water: 1,122 / 2,440. Monthly budget: **+$9,580**.
Treasury: **$2,147,845**. There are no abandoned properties at the starting state.
The central traffic is busy, so this is also useful for comparing FPS at different
zoom levels. Random disasters are off for exploration; automatic growth remains
active. Enable disasters in-game if desired.

## Things to test

- Follow the road from the main city to the town; inspect graded joins, bridges,
  cars and the small foundations on the hillside homes.
- Compare the flat city tops, Gentle shoulders, Rounded mountains, cliffs and
  the steeper exposed strata. Try construction on different ground types.
- Raise/Lower clear ground with Edges Smooth, then Undo/Redo. Check the expanded
  preview, cost and protected plots; the supplied city has ample testing funds.
- Inspect low shores versus high cliff banks, the river and pond water levels,
  the dry quarry and the different mountain/mesa materials.
- Toggle the grid, pan and zoom. Save/reopen and export/import after edits.

## Validation

Generated and matured through 24 months of the real native simulator, then
imported/exported and checked through a further 24 months. **21,288 checks pass**,
including every tile's JSON round trip, road access, connected city-to-town
routes, road edge compatibility, valid corners, level multi-cell foundations,
clear construction footprints, utilities and positive finances.

After the extra 24 months: population 3,775; jobs 3,444; idle workers 9%; no
unpowered/unwatered developed buildings; +$9,529/month. Treasury grows to
$2,381,191. Actual native file-import callback and all six previews pass, and
cached/full rendering matches pixel for pixel in the native OpenGL capture.

Validation used Godot 4.6.3 with the 0.3.14 game source
0ef8260b19c71852783127b1f24424e0b8b90e29. Screenshots use desktop Mesa llvmpipe;
they do not establish Galaxy S25+ FPS. Preview captures pause FPS sampling and
simulation for deterministic images; the normal game counter is unaffected.

The map is new content. It does not change game code, signing or older example
cities. Reproduce it from the repository root:

    godot --headless --audio-driver Dummy --path godot --script /absolute/path/to/examples/build_cedar_reach.gd -- /absolute/output/folder

For native captures with a working OpenGL display, run
examples/capture_cedar_reach.gd with the same output folder.
