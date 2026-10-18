# Alpine Lake — MetroForge sample map

Use MetroForge Godot 0.3.10 or newer. This is a playable 52×52 city save, format 11;
it uses peaks above 12, so earlier previews cannot import it. No APK update is
needed if 0.3.10 is already installed.

Import `MetroForge-Alpine-Lake.json` through City / Files → Import city.
If downloading the ZIP, extract it first and choose that JSON file.
Export your current city first if you want to keep a separate backup.

Explore:

- Five snowy peaks along the western side, connected by rocky highland and
  forested foothills. Highest terrain reference 30; 151 cells are at 20 or higher.
- A developed city beside the mountains, with varied building recipes/colors,
  apartments, offices, shops, gardens, schools and other civic services.
- A divided, tree-lined valley road connecting city and lakeside town, plus
  a bridge/causeway over the northern inlet. It uses the existing road system;
  it has no separate highway speed, one-way traffic or interchange mechanics.
- A 319-tile irregular lake, beaches, a wooded island, and a lower-rise town on
  the southern shore. Single-tile housing lots keep the town from becoming
  another tower district under automatic growth.
- Wooded hills throughout open land, low banks and southeastern sandy mesas.
  There are 719 trees, 1,555 curved tiles and only 74 bare flat dry tiles, mostly
  beaches/road verges, among 2,704 map cells.

Starting state: population 3,745; jobs 3,491; 7% idle; power 1,095/1,650;
water 1,065/1,920; monthly budget +$9,901; treasury $1,073,129. 95 developed parcels:
41 central-city, 16 foothill-garden, 30 lakeside-town and 8 employment parcels.
All developed buildings have road access and utilities. Automatic growth remains
active. Random disasters are off so this can be explored; enable them in-game
if desired. The landscape was authored, and neighborhoods then matured through
24 months of the real simulator.

Validation: 9,954 checks pass, including native import/export with every tile
value preserved, legal flat building foundations, clear construction footprints,
road access, utilities and positive finances. A further 24-month simulation ends
with population 3,724, jobs 3,469, 7% idle, full utilities and +$9,821/month; treasury
rises to$1,313,483. Actual file-import callback and screenshots were checked in
Godot 4.6.3 desktop OpenGL. This does not establish Android FPS. Previews suspend
FPS sampling for deterministic captures; the game's FPS counter works normally.

Reproduce from repository root:

    godot --headless --path godot --script /absolute/path/to/examples/build_alpine_lake.gd -- /absolute/output/folder

With an OpenGL display, run examples/capture_alpine_lake.gd the same way with
the output folder to capture the actual game. This map does not change game
code, the APK, existing sample maps or signing configuration.
