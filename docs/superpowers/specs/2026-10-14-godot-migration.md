# MetroForge Godot migration

The user authorized migration of the playable Android city-builder to Godot. They explicitly deferred live wallpaper implementation. Keep that future use possible by separating the city model, simulation, persistence, and presentation. The working JavaScript Android preview and original main branch remain available.

## Deliverable

A native Godot 4.6.3 project under `godot/`, an installable Android preview APK, and its complete source archive. Port the existing playable systems rather than embedding the old page in Godot. Preserve the 52 × 52 city, original Kenney artwork, corrected flat terrain, placement costs and rules, parcels, utilities, services, demand/growth, economy, transport, disasters, and JSON city import/export. Keep native UI usable with touch in landscape. Do not claim device testing without an attached device.

Use a distinct Android preview package `com.narmanb.metroforge.godotpreview`, label `MetroForge Godot`, version 0.3.0. It installs alongside the existing app. Existing WebView local storage is not directly shared: users export their old city as JSON and import it into the Godot preview. Imported cities preserve stored tiles, elevations, types, parcel IDs, treasury, calendar, taxes, funding, and city progression; derived fields are recomputed.

## Structure

- `godot/model/city_world.gd`: UI-independent `RefCounted` city state and simulation. May split private helpers under `model/`. No scene-tree, Android, display, or input dependencies. The same model can later be driven by a wallpaper lifecycle.
- `godot/view/isometric_view.gd`: native Godot 2D city renderer, projected placement/picking, camera pan/zoom, and world-space interaction signals. Terrain surface, zones, and picking share elevation geometry. Preserve correct occlusion through CanvasItem ordering. No simulation ownership.
- `godot/ui/main.gd` and `main.tscn`: native Godot controls and controller. Simulation ticks, speeds/pause, tools/categories, overlays, construction history, budgets, events, guide, selection details, save/load, and import/export. No wallpaper service or background progression policy.
- `godot/persistence/city_store.gd`: atomic JSON save/load, validation, backup recovery, and legacy import. The source of truth is the shared model, not a screenshot or renderer state.
- `godot/assets/`: byte-identical selected atlas PNGs, manifest, and four CC0 license files from the existing game. The larger uploaded collection remains available for future art work; it does not need wholesale vendoring for the engine port.
- `godot/tests/`: headless model, persistence, geometry, and integration tests. Browser baseline fixtures can be used to check deterministic parity.

## Shared interfaces

`CityWorld` extends RefCounted; existing saved data keys/properties retain their JavaScript camelCase spelling. World properties: `tiles`, `cash`, `year`, `month`, `tick`, `seed`, `taxes`, `funding`, `randomDisasters`, `bondMonths`, `nextParcelId`, `stats`, `fields`, `demand`, `cars`, `trains`, `events`, `messages`, `network`. Constants `N=52`, `COUNT=2704`, `COST`, `CONFIG`, `ZONE_TOOL`, `TOOLS`, `CATEGORIES` mirror the source where useful.

Required world API:

```
CityWorld.new(seed_value: int = 0)
CityWorld.from_dict(data: Dictionary) -> CityWorld # null on invalid data
serialize() -> Dictionary
can_place(i: int, tool: String, bridge: bool = false) -> bool
place(i: int, tool: String, bridge: bool = false, parcel_id: int = 0) -> bool
recalculate() -> void
step() -> void
advance_agents(dt: float) -> void
road_near(i: int) -> bool
parcel_info(i: int) -> Dictionary # {} if none
parcel_capacity(parcel: Dictionary, level: int) -> int
parcel_has(parcel: Dictionary, field: String) -> bool
neighbors(i: int) -> Array
```

The UI can use validated `serialize()/from_dict()` snapshots for new/load/import and construction history, but undo must restore only edited tiles and construction spending rather than rolling back the simulation clock. Retain the tree-clearing rules from 0.2.2.

`IsometricView` extends Control. Properties `world`, `tool="pan"`, `mode="tapPan"`, `overlay="none"`, `selected=-1`, `scale=28.0`; signals `tile_pressed(index: int)`, `stroke_started`, `tile_painted(index: int)`, `stroke_finished`, `selection_changed(index: int)`. Methods `set_world(value)`, `refresh()` after static changes, `fit_city()`, `zoom_at(factor: float, at: Vector2)`, `tile_to_screen(index: int) -> Vector2`, `screen_to_tile(point: Vector2) -> int`. Its size is the available map rectangle, positions are local to that rectangle, and it owns map gestures. Tap builds one tile in tapPan mode; drag pans. Paint mode emits a continuous tile stroke. Pinching pans/zooms without placement. Selection in pan mode emits `selection_changed`.

`CityStore` exposes static `save_city(world, path: String = "user://city.json") -> Error`, `load_city(path: String = "user://city.json")`, `import_json(text: String)`, `export_json(world) -> String`, and static `last_error: String`. Invalid import returns null and leaves the running city untouched. Use native file dialogs when supported, with a clear text import/export fallback.

## Validation and limits

Headless tests cover real placement/spending, tree clearing/forest exclusion, undo/redo, elevated picking and camera behavior, legacy city round trips, invalid import, simulation utility/parcel/growth cases, and rendering smoke. Capture the native scene with software rendering/Xvfb when possible. Export Android and verify its package/version, signatures, native Godot libraries, PCK/runtime content, and absence of a WebView game dependency. Smooth terrain slopes and live wallpaper remain separate future work. Record remaining parity gaps honestly if any cannot be completed.
