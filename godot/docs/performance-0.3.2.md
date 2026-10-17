# Populated-city performance — 0.3.2

Baseline: `3b6220875d560c0e01085b8172846c0c201256b5` (0.3.1). Both probes use official Godot 4.6.3. Fixture: the unchanged Harbor City JSON in `examples/harbor-city/MetroForge-Harbor-City.zip`, SHA-256 `d499e3947edce20061b5ff2c3563c9fe8a82d25a8f4578dfba7299cd51a2191a` (4,371 residents, 108 developed properties, 70 cars, eight trains).

## Cause and changes

The 0.3.1 fresh-city benchmark missed the populated-city bottleneck. Harbor submitted 6,169 polygons, 5,428 polylines, 836 sprites and 60 labels across 353 static layers. Caching commands avoided rebuilding them every frame but still left roads, rails, pipes, poles and wires as thousands of separate GPU submissions. The full view submitted approximately 20,000 draw calls even with simulation paused.

The renderer now compiles mixed polygons, sprites and network strokes into ordered triangle meshes. It preserves painter order and existing depth buckets instead of sorting by texture. Analytic coverage keeps thin network strokes visible at overview zoom. Geometry has enough padding for antialiasing at the minimum supported zoom. Static meshes remain retained across camera movement; moving cars retain a direct sprite path.

A 512×512 render atlas holds the same 17 selected sprites instead of loading five source atlases totaling 6,389,760 pixels. The generator preserves the original imported RGBA pixels and extrudes each crop's border for linear filtering. It disables a second alpha-border processing pass on the compact atlas. Original source PNGs, manifest, anchors and licenses remain intact. This changes rendering resources, not the game's sprite selection.

Monthly simulation also scanned every tile against every park and station. Local integer influence deposition replaces those full-map amenity distance searches and preserves Float32 results and station radius boundaries.

The APK now uses the official Android **release runtime**, with preview/test signing. Godot's debug template enables GDScript stack tracking and additional VM validation/dynamic arithmetic checks. These CPU costs are absent from the release runtime. The build helper records the template hash and verifies both packaged native libraries against that release template. The desktop editor measurements below do not include this additional runtime change.

## Measured results

| Harbor probe | 0.3.1 | 0.3.2 |
| --- | ---: | ---: |
| Full view, static draw calls | 20,134 | 598 |
| Full view, agents + camera movement, draw calls | 20,133 | 599 |
| District view, agents + camera movement, draw calls | 16,119 | 444 |
| Close view, agents + camera movement, draw calls | 8,621 | 250 |
| Full view static frame interval, median / p95 | 101.993 / 124.533 ms | 49.261 / 62.401 ms |
| Full view agents + camera frame interval, median / p95 | 104.358 / 118.722 ms | 51.312 / 61.319 ms |
| District agents + camera frame interval, median / p95 | 114.679 / 142.608 ms | 84.617 / 102.688 ms |
| Close agents + camera frame interval, median / p95 | 93.107 / 101.835 ms | 77.059 / 87.272 ms |
| Environment update, median CPU | 71.551 ms | 29.237 ms |
| Full recalculation, median CPU | 136.796 ms | 83.841 ms |
| Monthly step, median CPU | 273.094 ms | 161.372 ms |
| Repeated housing tap controller CPU, median | 143.434 ms | 87.324 ms |
| Same taps through deferred view refresh, median | 150.872 ms | 93.782 ms |

Rendering: Xvfb, 1280×591 physical / 854×394 logical viewport, Mesa 25.0.7 llvmpipe LLVM 19.1.7, GL Compatibility. Simulation is paused; animated cases advance agents by a fixed 1/60 second and use deterministic camera movement. Each case has five warmups plus five discarded samples, then 30 measured frames. Baseline and candidate runs are sequential with no concurrent test/benchmark workload. The final candidate includes the imported-pixel and minimum-zoom fringe corrections.

Model timing uses one warmup and seven samples per stage, then six monthly steps. Housing timing uses eight identical successful edits on fresh Harbor imports; the first cold edit is excluded from medians (controller / refresh: baseline 136.658 / 181.989 ms, candidate 107.502 / 184.442 ms). The resulting complete serialized cities match byte-for-byte.

**These are shared-host desktop editor/CPU/software-GL measurements, not S25+ FPS.** Draw-call counts establish approximately 97% fewer submissions independently of host timing noise. The renderer remains fill/geometry limited in software GL, particularly at close zoom. Monthly simulation still runs synchronously. This report does not establish 60 FPS, zero phone stutters, or support for maps ten times larger. The map remains 52×52; large-map expansion is separate work.

A visible FPS / milliseconds-per-frame display now samples rendered frames over 0.75 seconds using monotonic wall time. It includes foreground stalls, resets on application pause/resume, and ignores touch input. It allows the next APK test to produce actual S25+ readings.

## Correctness

- All ten native check scripts pass, covering model parity, save/import behavior, environment boundaries, ordered batches, imported sprite pixels, gestures, retained terrain caches, construction/history, UI and the new FPS display.
- All 135,317 selected imported crop/border texels match the original imported source textures exactly. Original source/license SHA-256 checks pass.
- 42 complete baseline/candidate state snapshots match byte-for-byte across Harbor's 12 months, dense and boundary cities' six months each, and empty cities' two months. They include derived fields, demand, network, traffic, RNG and transient state, recalculation, agents and reload.
- An actual GL capture after parcel expansion, elevated terrain, tree clearing by a power line and distant power/water changes is pixel-identical between incremental rendering and a complete rebuild. Whole-city, district and close Harbor screenshots were inspected for sprite, terrain, wire and depth order regressions.
- Independent review found no remaining Critical or Important issue. Its imported-texture and minimum-zoom line coverage findings were fixed and regression checked.
- Local Android export passes signature verification and 16 KB ZIP alignment; packaged ARM64 and ARMv7 engine libraries match the official release template.

Raw paired rendering metrics, model metrics and deterministic snapshot hashes are in [performance-0.3.2-results.json](performance-0.3.2-results.json).

## Reproduce

Extract the Harbor ZIP to a working directory, then from the repository root:

```sh
python godot/tools/check_project.py
godot --headless --audio-driver Dummy --path godot --script tools/profile_city_model.gd -- /absolute/path/MetroForge-Harbor-City.json
godot --audio-driver Dummy --rendering-method gl_compatibility --path godot --script tools/profile_city.gd -- /absolute/path/MetroForge-Harbor-City.json /absolute/path/results
```

The render probe requires a display, such as Xvfb. Use the same scripts/fixture and sequential runs against an imported baseline checkout for a comparison. The performance probes are project-owned because the optional game-dev adapter/CLI is unavailable in this environment. They are not sealed adapter telemetry.

To regenerate the compact atlas, import the original textures first, run `tools/build_render_atlas.gd` headlessly, then reimport and run `tests/test_render_atlas.gd`. Tests and tools are excluded from Android exports. Wallpaper/background simulation and new sprite content are outside this patch.
