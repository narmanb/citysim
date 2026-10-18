# Phase 4 performance probe

Sequential software OpenGL (llvmpipe), same 1280×591 viewport, same paused Harbor City (population4371) and fixed agent/pan sequence. Baseline c3b29d6 versus Phase4 source. Desktop CPU quota and software raster timing vary; these results do not establish Android FPS or a wall-clock speedup.

| Case | Draw calls before / after | Frame median ms before / after | Input+agents CPU median ms before / after |
|---|---:|---:|---:|
| fit_static | 588 / 588 | 59.954 / 53.817 | 0.0 / 0.0 |
| fit_agents | 589 / 589 | 54.744 / 48.323 | 1.02 / 1.002 |
| district_agents | 446 / 446 | 75.273 / 88.613 | 1.057 / 1.124 |
| close_agents | 257 / 257 | 81.573 / 65.877 | 1.063 / 1.064 |
| fit_ground_only | 241 / 241 | 46.687 / 45.235 | 0.0 / 0.0 |
| fit_objects_only | 480 / 480 | 38.541 / 41.24 | 0.0 / 0.0 |
| fit_without_poles | 446 / 446 | 45.497 / 41.634 | 0.0 / 0.0 |

Harbor command dictionaries, retained static layer count360 and all draw-call counts are identical. Fit/district/close movement does not rebuild retained geometry. Frame medians vary in both directions; measure on the Galaxy S25+ to assess mobile frame pacing.

The internal mixed fixture with243 Rounded tiles, a negative basin, desert hill, Cliff platform and utility anchors used202/155/124 draw calls at fit/district/close and106 retained layers. Its geometry comprises10520 polygon commands but stays batched. A later capture adds a four-tile coastal island (247 Rounded tiles total), separately checked for correctness. The fixture is not a populated-city scaling benchmark.

Renderer regression asserts a reference edit rebuilds at most49 nearby tile records and that incremental records/pixels match a full rebuild. Bound is independent of city extent. No new atlas, per-frame full-map mesh generation or per-tile scene nodes introduced.

Reproduce with tools/profile_city.gd under an actual GL display, using the same city JSON for both source revisions. Raw JSON and logs accompany the phase test report.
