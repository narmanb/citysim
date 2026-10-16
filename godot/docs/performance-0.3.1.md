# Native preview performance validation — 0.3.1

Baseline: migration commit `d27eec9394a750ecd63a6e78dd31f73bbe78e5bd` (0.3.0).
Candidate: 0.3.1 source on `feature/godot-migration`. Both use official Godot 4.6.3.

## Measured work and desktop results

The old view deleted/recreated every static tile layer after construction and simulation refreshes. Each terrain tile also submitted redundant fill, outline and texture commands. Retaining nodes alone left the 13,839-draw-call zoomed-out bottleneck intact.

The candidate caches tile commands, invalidates changed tiles and their terrain/network/parcel dependencies, retains depth buckets, and batches adjacent textured quads without changing painter order. Terrain caps blend transparent edge texels over the terrain color within one shader draw. Simulation changes skip irrelevant utility candidates and reuse environment fields while preserving Float32 intermediate rounding.

| Probe | 0.3.0 | 0.3.1 |
| --- | ---: | ---: |
| Full-city draw calls, median | 13,839 | 596 |
| City child nodes, fresh seed 4242 | 2,925 | 172 |
| Tile records regenerated, isolated zone placement | 2,704 | 5 |
| Software-GL frame interval, median | 91.926 ms | 23.981 ms |
| Software-GL frame interval, p95 | 111.126 ms | 42.329 ms |
| Fresh-city full recalculation, median desktop CPU | 67.361 ms | 35.501 ms |
| Empty-city full recalculation, median desktop CPU | 63.974 ms | 31.682 ms |
| Developed month-12 recalculation, median desktop CPU | 68.740 ms | 37.171 ms |

The rendering probe uses a 1280×591 viewport, seed 4242, whole-city fit, fixed pan/zoom movements, five initial warmup frames and 60 measured frames. Rendering uses Xvfb, Mesa 25.0.7 llvmpipe (LLVM 19.1.7), GL Compatibility, VSync disabled where supported. Model probes use two warmups and eleven samples per workload. Runs share a cloud host; timings vary with scheduling. The draw-call/node/dirty-tile counts establish reduced work independently of that timing variance.

**These are desktop CPU/software-rendering measurements, not Android frame rates or evidence that the reported Galaxy S25+ freeze is resolved on-device.** Device placement latency, panning, pinch zoom and sustained simulation still require the tester's APK run. No claim of 60 FPS is made.

## Correctness and visual checks

- The native model suite retains JavaScript parity checks and adds exact Float32 park, service, traffic and road-condition expectations.
- Six timed-workload state snapshots and sixteen stress snapshots (four synthetic cities, recalculation plus three months) match the baseline exactly. Hash inputs include serialized city, derived fields, demand and network state.
- Cache regressions cover isolated edits, neighboring terrain/network dependencies, parcel roots, water-field coverage, overlays, full-map retention, stable layer counts and pan/zoom without static regeneration.
- An imported developed-city fixture was captured at whole-city and district zoom. Mean channel differences from the baseline remained below 0.7/255; transparent ground edges remain filled. An edit sequence involving parcel expansion, elevation, trees, lines, power and distant water coverage produced **pixel-identical incremental and full-rebuild images**.
- Native UI/controller checks cover the restored two-row header, larger 854×394 logical viewport, pop-up tool categories, demand meters, selection/cost updates, paint/pan and pinch without unintended spending.
- An independent code review found no demonstrated Critical or Important regression; it reran view, cache and UI checks.

## Reproduce

From the repository root, with Godot 4.6.3 installed:

```sh
python godot/tools/check_project.py
godot --headless --audio-driver Dummy --path godot --script tools/profile_model.gd
godot --audio-driver Dummy --rendering-method gl_compatibility --path godot --script tools/profile_render.gd
```

The last command needs a display (or Xvfb). For a baseline comparison, run the same probe scripts against an imported checkout of the baseline commit, with its original project sources. Do not run baseline and candidate timing probes concurrently. Tests and tools are excluded from the Android export.

Live wallpaper and background simulation remain outside this patch.
