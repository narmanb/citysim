# Terrain follow-up performance

Sequential0.3.6 baseline vs0.3.7 candidate, same243-Rounded-tile saved fixture, same1280×591 viewport and deterministic profile_city.gd sequence. llvmpipe software OpenGL on a shared CPU-limited host. No Android FPS inference.

| Case | Draw calls before/after | Median frame ms before/after | Input+agents CPU ms before/after |
|---|---:|---:|---:|
| fit_static | 202 / 202 | 42.022 / 35.27 | 0.0 / 0.0 |
| fit_agents | 202 / 202 | 43.195 / 32.802 | 0.053 / 0.042 |
| district_agents | 155 / 155 | 38.654 / 51.727 | 0.048 / 0.054 |
| close_agents | 124 / 124 | 34.184 / 32.431 | 0.051 / 0.042 |
| fit_ground_only | 198 / 198 | 42.522 / 34.693 | 0.0 / 0.0 |
| fit_objects_only | 99 / 99 | 33.7 / 23.936 | 0.0 / 0.0 |
| fit_without_poles | 201 / 201 | 43.212 / 41.405 | 0.0 / 0.0 |

All draw-call and visible-object counts are unchanged. Retained layers106; geometry remains32 triangles per Rounded tile. Vertex tint interpolation and world-space detail use the same batch/pass. Median software-frame timings vary in both directions (district slower, other cases faster); these data do not demonstrate a consistent speedup or establish phone frame pacing.

Full Harbor City (population4371) remains360 retained layers, identical command dictionaries and draw calls588 static fit /589 agents /446 district /257 close. Input+agents CPU medians0.970 /1.083 /1.127ms in those moving cases. Its original flat terrain uses the legacy shader branch. Local mesh cache equality and no terrain rebuild on camera movement remain tested.

Performance release gate is unchanged calls/topology/cache behavior plus phone retesting, not a claim that all software-GL timings match. Raw JSON reports accompany the test bundle.
