# MetroForge 0.3.13 — roads, foundations and terrain joins

## Construction contract

Shape → Sloped → Gentle permits roads, Housing/Business/Industrial zones and
civic buildings. Medium/Steep and Rounded ground retain Flatten-first rules;
rail stations and rail still require flat ground. Auto slope direction freezes
when construction is placed, so later edits to neighbors cannot rotate it.

Roads follow shared triangulated decks. Facing terrain edges may differ by no
more than half a height unit; corner road groups obey the same bound. Their
shared deck uses the highest supporting height, with retaining fill beneath.
Road routes/masks reject disconnected shaped edges. Cars sample the same deck,
including their lane offset. Existing flat-only stepped streets remain intact.
Bridges retain their level deck/guards; put a flat landing between a ramp and
water. No new rail grading or bridge artwork is added.

A building foundation is level at the highest corner of its Gentle slope.
The underlying terrain/reference elevation stays unchanged. Pads render full
tile tops with downhill retaining faces; zone fill, overlays, selection and
picking agree. Each small building uses its member pad; larger recipes require
a same-height usable rectangle and automatic growth still checks services,
demand, utilities, roads and lot size. No slopes are secretly flattened.

Existing costs remain: road $18, zone/civic normal tool cost, no extra pad charge.
Rejected/unaffordable construction changes nothing. Undo/Redo restores full shape,
direction, pad and cash metadata. Bulldozing a building retains its zoning/pad;
removing zoning or a civic removes its pad. Terrain editing protects construction.

## Water and biome appearance

Stored channel elevation remains its bed; water draws at0 above negative beds.
Existing authored positive natural-water levels are preserved. Caps, picking,
bridge/rail surfaces and vehicles use that water height. Channel connectivity,
waterSource and reflow rules are unchanged; a dry basin does not flood because
its neighbor contains water. Earth faces close high banks and drops beside dry
low ground. Beach strips apply only when both bank-edge endpoints are within
0..0.75 of the water level; high cliff tops no longer receive a beach ribbon.
Shore water receives a restrained lighter tint in the existing palette.

Natural grass/desert caps share blended vertex colors, including Rounded caps.
Explicit surface paint, water, channels and constructed plots keep their own
appearance. No source PNG, new texture, seasonal or hydrology system is added.

## Saves and validation

Save12 adds optional foundationHeight. New pads require a Gentle fixed-direction
slope and a height exactly equal to its highest corner. Malformed/unsupported
construction is rejected. Valid v6–11 cities still import. New slope roads/pads
cannot be loaded in older APKs; export backups before testing/downgrading.

Native regression suites cover N/E/S/W, grades, road joins, flat bridge landings,
unaffordable edits, frozen Auto, pads, invalid imports, history, traffic samples,
picking, cached/full geometry and water/biome joins. Actual desktop OpenGL
captures use tools/preview_civil_water.gd, compare exact cached/full pixels before
and after a biome edit and import the fixture through the real save decoder.
Alpine Lake and Harbor geometry/material fields are checked across all 5,408 tiles.
Source artwork/license receipts and the full simulation/UI suite are retained.

Road decks are cached with local tile invalidation. Flat cities skip per-car
slope searches; camera changes do not regenerate terrain. Harbor draw calls are
unchanged:588 fit/static,589 fit/agents,446 district,257 close. Desktop software
GL timings do not establish Galaxy S25+ FPS; on-phone testing remains necessary.

## Phone checks

1. Export the current city before installing; deferred persistent signing means
   this preview's temporary certificate may require uninstall/reinstall.
2. Shape empty ground as a Gentle directional slope. Zone small plots and place
   a road along compatible edges. Inspect pads uphill/downhill and at close zoom.
3. Try Medium/Steep/Rounded land and incompatible road heights: expect rejection
   without cash loss. Use a flat landing before a bridge.
4. Build a connected ramp with references increasing 1 per tile in its high-edge
   direction. Inspect road joins and cars moving both ways; try a turn.
5. Undo/Redo, bulldoze the building then its zoning, save/reopen, export/import.
6. Inspect negative-bed channels, raised banks, dry basins and grass/desert
   borders. Repaint a border, pan/zoom and toggle the grid.
7. Compare Harbor/Alpine FPS and verify both landscape directions with Android
   Auto rotate enabled, including after Fullscreen/background resume.

Mountain preset height behavior and small Rounded brush attenuation are unchanged.
Sprite expansion, wallpaper and persistent signing remain deferred.
