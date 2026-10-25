# Services, utilities and building variety —0.3.18

All three approved artwork groups are included in this Android update. Existing
save13 cities, including Summit Bay, receive the art automatically. There are no
new zoning buttons, density controls, capacities, dispatch mechanics or agents.
Automatic growth, costs, free Terraform and terrain bounds-5..40 remain.

## Facilities

Eight offline composites replace the colored placeholders: police, fire station,
school, hospital, power plant, pump, water tower and rail station. Supplied Kenney
windowed floors/roof modules provide their shells. Matching geometric artwork
adds service cues: shield/antenna, shutter bays, school clock/flag, medical cross
and canopy, stacks/intake, basin/pipes, elevated tank/supports and a platform canopy.
These details are newly authored, rather than claimed as dedicated source prefabs.

Each facility is one static atlas sprite with measured ground contact. It renders
upright at Civil.build_height, preserving existing Gentle-grade pads. Existing
parks, service vehicles, road/rail decks and capacities are unchanged. Station
construction still requires flat rail; this update does not enable sloped tracks.

## Development variety

41 deterministic recipes replace the original24:10 houses,6 apartments,7 shops,
6 offices,6 light-industrial and6 heavy-industrial. Six existing palettes remain.
New floor/roof combinations extend residential, apartment and office silhouettes.

Three verified complete storefront sources (buildingTiles_018,100,124) produce
18 palette variants. Their original ground pedestals and side ledges are removed;
the measured facade-ground anchor is(width/2,57.25). A level1 shop uses one complete
frontage; level2 adds an upper floor/roof using the existing35.5 lift. The source
canopy is retained, so a second procedural awning is not added over it.

Industries now select shed, warehouse with rooftop equipment, sawtooth works or
processing/tank-yard profiles. Heavy industry keeps chimneys. These remain retained
geometric composites, with roofs sourced from the supplied family; they are not
external factory prefabs. Abandoned bodies and glazing dim consistently in all
six palettes. Appearance uses city/property identity without simulation RNG.

## Assets and performance constraints

Five original atlas PNGs and four CC0 license receipts are unchanged. All174
previous runtime sprite crops, dimensions and anchors remain byte-identical.
The runtime atlas now has200 entries and stays1024x2048(8MiB RGBA), with two-pixel
filter borders. No external package or paid asset generation was used.

Source crop receipts, palette derivations, selected modules and authored details
are recorded in building_styles.json. Rebuild from the full repository with:

    godot --headless --audio-driver Dummy --path godot --script tools/build_render_atlas.gd

Composition happens offline, not while panning. New facility artwork uses one
sprite instead of primitive shapes/text, and all artwork uses existing retained
buckets. Factory geometry is regenerated only when the retained tile changes.

## Validation and phone checks

40 native suites pass, including51186 development-art checks, all source/material
receipts, anchors, palette resolution, stable selection, save neutrality,
construction foundations, camera-cache reuse and incremental/full record equality.
The new integration test covers every facility on flat/raised/Gentle ground,
storefront growth levels, four different industrial silhouettes and abandoned
glazing across all palettes. Native captures also compare incremental/full pixels
and verify rendering does not mutate the city. Review found and corrected the
brightness-dependent industrial glazing tint before delivery.

On your phone, import Summit Bay and inspect its civic campuses, power plants,
lakeshore pumps/towers, town shops and work district. Zoom close to compare old
and new silhouettes, then Fit/pan to compare FPS. Try a service on Gentle ground;
it should sit upright on its existing level pad. Save/reopen after edits.

Android package stayscom.narmanb.metroforge.godotpreview, version0.3.18/code19,
userLandscape orientation. Previous releases are retained. Persistent signing
setup remains deferred; export a wanted city before replacing an app if Android
requires reinstalling because its test certificate differs.

## Matched desktop rendering probe

Same52x52 saves, Godot4.6.3,1280x591 output, Mesa llvmpipe and the unchanged
profile_city.gd scenario; baseline9714c93 and candidate ran sequentially after
other test/capture processes finished. These measurements are desktop evidence,
not Galaxy S25+ FPS predictions. Both retain70 cars; no new simulation agents.

| City/view | Draw calls before → after | Median frame ms before → after |
|---|---:|---:|
| Summit / fit_static | 504 → 459 | 40.83 → 57.81 |
| Summit / fit_agents | 506 → 459 | 40.02 → 38.55 |
| Summit / district_agents | 375 → 346 | 63.14 → 61.11 |
| Summit / close_agents | 233 → 215 | 64.75 → 65.21 |
| Harbor / fit_static | 600 → 525 | 41.63 → 35.42 |
| Harbor / fit_agents | 601 → 525 | 45.18 → 39.34 |
| Harbor / district_agents | 452 → 385 | 66.11 → 66.26 |
| Harbor / close_agents | 261 → 227 | 67.93 → 67.76 |

Facility text/primitive replacement lowers draw submissions; software-rendered
frame timings still vary by view. Device FPS remains a phone test.
