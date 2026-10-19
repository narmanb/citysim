# Smooth Edges Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans inline; user approved implementation.

**Goal:** Optional seamless Gentle grading around a level Raise/Lower platform.
**Architecture:** Pure corner-based grading planner delegates existing atomic
commit/history; Geometry consumes validated gradeCorners and all render/civil
paths share it. Compact session control chooses Sharp/Smooth.
**Tech Stack:** Godot4.6.3, GDScript retained2D, native test/export tools.
**Spec:** docs/superpowers/specs/2026-10-19-smooth-edges.md.

## Global Constraints

- Migration branch; heights -5..30; save13 reads v6–12.
- Sharp stays default. No terrain/art/signing or hydrology rewrite.
- Protect occupied land, marked Cliffs, Rounded and water; no partial charges.
- Preview every transition cell, $20 per changed cell, one Undo/recalculation.

## Review Focus

- Corner bevel samples, retaining faces and road triangles must agree.
- Repeated/overlapping paint uses one frozen footprint and level target.
- Protected/Auto/Rounded neighbors cannot change outside the transaction.
- Old foundation imports stay valid while graded foundations use real corners.
- Grade metadata is removed by incompatible edits, preserved by painting/history.

### Task1: Planner, geometry and validation

Create model/terrain_grader.gd and tests/test_smooth_edges.gd; modify terrain_editor,
terrain_geometry, sculptor, civil_engineering and city_world. Geometry validates
gradeCorners and samples exact triangles; Grader.plan(world,indices,operation,step,
protection) produces the existing proposal contract, with level_top and core_count.

- [x] RED: Raise/Lower platform edges match, Gentle maxrange, monotonic corners,
      extra cell costs, bounds, protection, stale/affordability, corner cases.
- [x] GREEN: bounded wave planner, shared grade metadata and save13 integration.
- [x] Verify grading roads/foundations, old saves, manual metadata cleanup.

### Task2: Controls, previews and native captures

Modify terrain_settings/main; create tests/test_smooth_edge_controls.gd and
tools/preview_smooth_edges.gd. Use existing sculpt_settings_changed bool flag.

- [x] RED/GREEN: default Sharp, persistent Edges setting, compact dock, frozen
      preview/commit cost equality, one Undo/Redo, native cancel, error messages.
- [x] Actual GL Sharp/Smooth shots, no internal dirt faces, construction samples,
      exact incremental/full pixels, local retention and bounded preview timings.

### Task3: Review and APK

- [x] Fresh review; fix material findings with failing regressions.
- [x] Full suite/art receipts and captures; document limits and phone checks.
- [ ] Separate0.3.14/code15 build, preserve signing/orientation, verify downloaded
      APK/source receipts, signature/alignment and report actual results.
