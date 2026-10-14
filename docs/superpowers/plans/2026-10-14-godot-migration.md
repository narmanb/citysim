# MetroForge Godot Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Port the existing playable MetroForge Android game to native Godot and deliver a tested APK and source.

**Architecture:** Separate a RefCounted city model from the Godot view and controller. Preserve old JSON data and reuse verified CC0 atlases. Android wallpaper is deferred; the model has no screen lifecycle dependencies.

**Tech Stack:** Godot 4.6.3, GDScript, native Godot Controls/CanvasItems, Android export templates, SDK 35+, Java 17.

**Spec:** `docs/superpowers/specs/2026-10-14-godot-migration.md`

## Global Constraints

- Original WebView project and main remain intact in their current workspace.
- New worktree `/workspace/citysim-godot`, branch `feature/godot-migration`.
- All shared signatures and city keys follow the spec.
- Android ID `com.narmanb.metroforge.godotpreview`, version 0.3.0.
- No wallpaper implementation, paid providers, or external project publishing.
- Preserve source PNG bytes and package their CC0 licenses.

## Review Focus

- Legacy cities with null/missing optional fields load without silently resetting valid values; persistence task tests this.
- Touch drags and pinches never spend money accidentally; view/controller task tests this.
- Terrain texture geometry matches elevated picking and zoning; view task tests this.
- Disconnected utilities and irregular parcels do not receive phantom services; model task tests this.
- Invalid/corrupt saves leave the active city available and a recoverable backup intact; persistence task tests this.

## Task 1: Native model and simulation

Files: `godot/model/*.gd`, `godot/tests/test_world.gd`.

Consumes the original `MetroForge-2000.html` classes and the documented world API. Produces `CityWorld` and all required methods/properties. Port all current systems and preserve source formulas where possible.

- [x] Write headless tests for placement/costs/tree rules, parcel connectivity/capacity, utility propagation, terrain channels, growth/economy, and legacy round trips. Run to observe missing model failure.
- [x] Implement the model and simulation without UI dependencies; eliminate JavaScript coercion assumptions explicitly.
- [x] Run tests using `godot --headless --path godot --script tests/test_world.gd`; compare deterministic legacy fixtures and report intentional differences.

## Task 2: Native isometric scene and interaction

Files: `godot/view/*.gd`, `godot/tests/test_view.gd`.

Consumes `CityWorld`, selected source atlases/manifest, and the exact `IsometricView` contract in the spec. Produces a resizeable native view with correct depth/elevations and interaction signals.

- [x] Write geometry/gesture tests and observe failure before implementation.
- [x] Implement native drawing, camera, tile picking, object ordering, overlays, selection, and agent animation. Use retained CanvasItem ordering where practical.
- [x] Check tile-center round trips across zoom/elevation and exercise native mouse/touch gestures without accidental construction.

## Task 3: Native game screen, tools, and history

Files: `godot/ui/main.gd`, `godot/main.tscn`, `godot/tests/test_game.gd`.

Consumes model/view/store APIs. Produces the playable game scene with categories, tools, status, speeds, overlays, budgets, events, files, guide, and undo/redo. Native scene is the main scene.

- [x] Write scene/integration checks for construction, stroke history, pause/speed, save/import failure safety.
- [x] Implement controller and landscape touch layout, including connected road/rail drag placement and safe gestures.
- [x] Run scene checks headlessly and inspect a real rendered capture at phone and desktop sizes.

## Task 4: Persistence, Android build, and integration

Files: `godot/project.godot`, `godot/export_presets.cfg`, `godot/persistence/city_store.gd`, `godot/tests/test_store.gd`, build/documentation tools.

Consumes all preceding interfaces. Produces legacy-compatible JSON import/export, verified Android APK, and portable source ZIP.

- [x] Write failing store tests for legacy import, atomic save/backup, and invalid input.
- [x] Configure Godot project and byte-identical source artwork, implement store, and install official matching export templates if needed.
- [x] Integrate all files, fix parser/API mismatches, and run every Godot test plus source-asset validation.
- [x] Export Android; verify ZIP, package/version, signature, native library/PCK content, and installability metadata.
- [x] Request independent whole-change review, resolve Important issues, archive source, and report device-testing limits and any parity gaps precisely.
