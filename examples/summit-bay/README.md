# Summit Bay — streets and terrain showcase

For **MetroForge Godot 0.3.17 or newer**, using normal save format 13.
This is a refreshed Cedar Reach layout with a new appearance seed, taller
snowy mountains and the current park, street and vehicle artwork.

## Import

1. Export your current city first if you want to keep it.
2. Extract this ZIP. It contains exactly one city JSON.
3. Choose **City / Files → Import JSON file** in the game, then select
   **MetroForge-Summit-Bay-0.3.17.json**. Do not select the ZIP or an image.
4. Save the imported city to keep it as your last-open city.

The map does not install an update. Use APK 0.3.17 to see the newest sprites
and free Terraform tools. This example does not change your APK or signing.

## Explore

- **Terraced city:** 3,844 residents across a developed mixed-use center,
  colorful apartments, offices and shops. Gentle road grades and 18 building
  foundation records demonstrate hillside construction.
- **Parks and civic campuses:** nine fountain plazas and 14 planted gardens.
  Find parked police cars and ambulances beside accessible service buildings.
- **Work district:** factories and offices southwest of the city, including
  three parked work trucks. Service vehicles are decorative in this update.
- **Lakeside town:** 40 small developed properties on the opposite end of the
  valley, with its own school, hospital, police, fire station and park.
- **Transport:** 348 road cells, a river bridge, a four-station rail loop,
  70 moving taxis and two trains. 92 road cells have grades; 63 saved taxi
  routes include graded roads. Street details include 35 lamps and two
  end barriers, placed using the actual current renderer rules.
- **Landscape:** snow/rock mountains reaching a real visible +40 summit,
  open foothills, a large lake and island, riverbanks, beaches, a forest pond,
  sandstone mesas, cliffs, tilted strata and a dry quarry down to -5.
- **Moderate vegetation:** 162 terrain trees across the entire map, concentrated
  around one upland forest pond. Park sprites include some additional planting.

Random disasters are off for exploration; automatic growth is active.
The city has $2,178,359, 3,557 jobs and +$9,896/month, with all developed
properties and non-plant civic facilities supplied with power and water.
Traffic is busy (100 congestion), so managing it is a possible gameplay goal.
All Terraform actions are free in 0.3.17; construction and maintenance keep
their normal costs. Try modifying a clearing, then Undo/Redo or reimport this
file to reset. Grids are off in the previews and can be toggled in the game.

## Verification

21,309 content checks passed using the native 0.3.17 game source 802df45:
import/export, exact per-tile JSON roundtrip, legal terrain metadata, clear
construction footprints, level multi-cell foundations, compatible road
edges, the connected city-to-town route and coverage of every new art type.
The generator verifies that the visible summit samples at +40, rather than
just storing a high reference under a lower rounded surface.

The city was matured for 24 simulation months, then checked through a further
24 months: population 3,827, +$9,810/month, zero abandoned properties, no
unpowered/unwatered developed buildings and cash increasing to $2,419,173.
Actual native file import and retained/full render equality passed. Rendering
the previews leaves the saved city unchanged. Captures use desktop Mesa;
these checks do not measure Android FPS.

The ZIP contains this guide, one importable JSON and two in-game previews.
The repository also contains validation/capture reports and reproducible
examples/build_summit_bay.gd and examples/capture_summit_bay.gd scripts.
