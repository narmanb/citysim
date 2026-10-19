# Terrain construction and water/biome joins

Approved by the user's request to implement roads on slopes and foundations,
then shorelines, riverbanks and grass/desert transitions. Base cc1b048; native
Godot 4.6.3, migration worktree. Implementation proceeds here without additional
approval checkpoints. Existing APKs, signing and sprite additions stay untouched.

Construction begins with Gentle directional slopes (total rise 1). Rounded and
steeper ground still requires Flatten. Roads retain terrain reference heights,
freeze Auto direction when built, follow the surface and join neighboring roads
only when facing edge samples differ by at most half a height unit. Shared deck
corners use the higher edge, with fill underneath; this permits a shallow join
to an integer-height flat tile without burying asphalt. Existing flat-only road
links keep their previous behavior. Traffic routing and rendered car heights use
the same joins/deck as roads. Rails/bridges keep their existing flat-only rules.

New zones and civic buildings on Gentle slopes receive a level foundation at
the highest terrain corner; the pad and downhill retaining walls cover the full
tile. Buildings remain upright and the terrain stays unchanged. Save an optional
foundationHeight and freeze slope direction. Reject unsupported/malformed pads.
Large buildings require a same-height usable rectangle, including level pads;
different-height pads cannot become a single stretched large building. Undo,
Redo, bulldozing, insufficient funds and imports preserve complete metadata.
Save version12 reads valid v6–11 cities; old builds cannot read new slope roads.

Water elevation is a visible surface separate from its stored channel bed:
ordinary sea/lake/channel water renders at zero; positive authored natural water
retains its existing positive level. Channel connectivity and filling stay
unchanged. Cap drawing, faces, picking and bridges use this convention. Earth
banks meet that surface; shore strips appear only near water level, not high
cliff tops. Water-facing drop walls use neighboring earth material. Dry negative
land remains dry. Grass/desert vertex colors blend across shared corners using
only natural dry neighbors, preserving explicit painted surfaces and water.

Rendering remains retained and locally invalidated. Flat single-biome cities
retain the fast path. No per-frame terrain generation, new source art, hydrology,
snow simulation, Mountain redesign or signing work. Use native tests, actual GL
captures (including incremental/full equality), dense-city before/after probes,
then a distinct version0.3.13/code14 APK with exact source receipts. Phone FPS
and physical touch/rotation remain user checks.
