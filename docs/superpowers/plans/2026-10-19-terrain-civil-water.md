# Terrain Construction and Water Joins Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable safe Gentle-slope construction and coherent water/biome joins.
**Architecture:** Pure shared engineering rules beside terrain geometry; retained
view consumes those rules for roads, pads, picks and cars. Water/biome transition
helpers affect presentation while existing channel hydrology remains authoritative.
**Tech Stack:** Godot4.6.3/GDScript, retained2D meshes, Python Android packaging.
**Spec:** `docs/superpowers/specs/2026-10-19-terrain-civil-water.md`.

## Global Constraints

- Work only in feature/godot-migration, Godot4.6.3; preserve valid v6–11 imports.
- Heights -5..30; Gentle directional rise1 only for new construction.
- Preserve source art, signing workflow, package identity and earlier releases.
- No hidden terrain regrading, hydrology changes or per-frame mesh rebuilds.

## Review Focus

- Auto-direction neighbors edited after placement cannot move roads/foundations.
- Flat/ramp joins and road corners cannot leave cracks or bury traffic.
- New imports reject invalid construction metadata; legacy parcels stay intact.
- Repainting biome/bulldozing invalidates neighboring joins with cached/full parity.
- Water beds belowzero and dry basins stay separate, including bridge alignment.

### Task 1: Engineering rules and model integration

Files: create model/civil_engineering.gd, tests/test_civil_engineering.gd;
modify city_world.gd, UI placement warnings/history, check_project.py.
Produces Civil.gentle(tile), build_height(tile), foundation_height(tiles,index),
road_link(tiles,a,b), road_corners(tiles,index), road_sample(tiles,index,u,v).

- [ ] Write/run failing tests for Gentle N/E/S/W roads and pads, incompatible
      joins, frozen Auto, no-charge rejection, JSON/Undo/Redo, malformed metadata,
      same-height versus stepped development, preserved legacy fixtures.
- [ ] Implement pure rules and integrate placement/import/routing; version12.
- [ ] Run targeted tests and the complete native suite; commit.

### Task 2: Grade-aware drawing, pads, picking and agents

Files: isometric_view.gd, tests/test_civil_view.gd, tools/preview_civil_water.gd.
Consumes Task1 rules, produces actual road/pad geometry shared with picking/cars.

- [ ] Add/run failing geometry tests for road edge agreement, pad faces, picking,
      car samples, footprint heights and bounded cache invalidation.
- [ ] Implement road deck/fill rendering, pads and building anchors; update help.
- [ ] Capture GL fixture, compare incremental/full pixels and verify tests.

### Task 3: Water surface and bank/biome transitions

Files: terrain_geometry.gd, new view/terrain_transitions.gd, isometric_view.gd,
tests/test_terrain_transitions.gd; extend actual GL fixture.
Consumes shared geometry; produces water_height(tile), biome_color(...) and
shore-band eligibility used by retained caps/strips and picking.

- [ ] RED then GREEN: varied channel beds share surface0, dry neighbors remain
      dry, high banks have no sand stripe on top, opposite biome corners match,
      explicit surfaces/water are preserved, no hidden model mutation.
- [ ] Compare negative-bed/raised-bank/bridge and grass/desert native GL captures;
      exact cached/full output after edits, dense-city baseline/candidate metrics.
- [ ] Full suite; commit verified changes.

### Task 4: Review and separate Android preview

- [ ] Fresh whole-change code review; resolve important findings with regressions.
- [ ] Complete suite, GL captures and performance evidence; document limitations.
- [ ] Version0.3.13/code14, source receipts; retain orientation fix and signing.
- [ ] Push migration branch, verify CI, download separate draft APK/source assets,
      verify checksums/signature/alignment/runtime/source and report phone tests.
