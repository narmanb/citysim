# Three Valleys — a city, two towns and varied terrain

Import this region into **MetroForge Godot 0.3.19 or newer**. It uses the current
52 × 52 map and save format 14. A larger-map engine update is not required.

## Import

1. Export your current city first if you want to keep it.
2. Download **MetroForge-Three-Valleys-0.3.19.json**, or extract the ZIP to get it.
3. In the game, choose **City / Files → Import JSON file** and select that JSON.
   Do not select the ZIP or a preview image.
4. Save the imported city if you want it to reopen next time.

This is a city file, not an APK. Use your installed 0.3.19 game; no reinstall is
needed. The ZIP contains exactly one JSON city file, this guide and six previews.

## Explore

- **Granite City:** a dense city at one end of the region, with 4,179 residents,
  large apartment properties, offices, shops, colorful building palettes, parks
  and four civic campuses. A separate work district supplies additional jobs.
- **Riverbend:** a small town across the northern river, with 163 residents,
  detached houses, local shops, a park square, its own services and a modest
  workshop outside the housing blocks.
- **Lakehaven:** a second small town beside the southern lake shore, with
  159 residents, beach coves, shops, parks, services and a separate workshop.
- **Whitecap Ridge:** a broad snowy mountain range with a real visible +40 summit,
  exposed rock, linked ridges and green foothills. There is a small wooded pond
  between the mountains and the city.
- **Water and terrain:** a large lake with an island, a meandering northern river,
  a western tributary, a southern outlet, sandy shores, grassland, rolling hills,
  rocky bluffs, sandstone ground and a dry ravine down to -5. Bridges connect the
  three settlements. The valley arterial includes a short parallel bypass.
- **Moderate vegetation:** 97 terrain trees, concentrated in the foothill woodland
  and around the island; park artwork adds a little more planting.

In the overview, the large city is at the back, mountains are on the left,
Riverbend is on the right and Lakehaven is in the foreground. Previews have the
terrain grid switched off; use the game's grid control to choose your own view.

## A working sandbox

The region opens in January 2022 with **4,517 residents, 4,603 jobs, $2,407,801**
and **+$11,501/month**. Every developed property has power and water. All three
settlements share a legal connected road network; each has road-accessible,
powered and watered police, fire, school and hospital facilities.

Automatic growth remains on. Random disasters are off for exploration. Terraform
is free in the current APK, and the example starts with no active challenge.

**Report → History** already contains 25 genuine monthly samples: the completed
layout was simulated from January 2020 through January 2022. No past history was
invented. Start an optional challenge yourself if you want one.

## Verification

The generator ran 31,695 content checks with no failures on native Godot 4.6.3 and
the 0.3.19 game model. Checks cover native import/export, numerical preservation
of tile/history values (1e-12 tolerance for JSON float parsing), valid terrain
metadata, level multi-cell foundations, clear building/tree footprints, legal
road joins, every property's road access and actual service-source connectivity.
All sea-level water cells belong to one connected river/lake/outlet system; the
small upland pond intentionally sits at a separate elevation.

After importing the distributed file and simulating a further 24 months, the
region retained 4,492 residents, +$11,411/month, no abandoned properties and zero
unpowered or unwatered developed properties. Both towns stayed populated, and
cash increased. These figures describe that deterministic run, not a guarantee
about subsequent player edits.

The native game imported the actual file through its file-selection callback.
All preview and history captures preserved the city state. Retained and fully
rebuilt terrain captures were pixel-identical. Desktop Mesa captures do not
measure Android FPS.

Reproduce from the repository root:

```sh
godot --headless --audio-driver Dummy --path godot --script "$PWD/examples/build_three_valleys.gd" -- /tmp/three-valleys
# With an X11 display:
godot --audio-driver Dummy --path godot --script "$PWD/examples/capture_three_valleys.gd" -- /tmp/three-valleys
```
