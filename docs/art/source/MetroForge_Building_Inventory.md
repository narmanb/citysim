# MetroForge — Existing Building Asset Inventory

**Source:** `isotiles2.zip` (original uploaded asset archive). Inspected archive paths and counts, Kenney preview/sample illustrations, and representative individual source PNGs. This is an **asset feasibility audit**, not a claim that every component has already been composed, visually tagged, or tested in the game.

## Executive findings

- **1,185 building-related PNGs**, but most are modular parts, material variants, or viewing angles—not 1,185 complete buildings.
- **Isometric Tiles Buildings:** 129 tile images, in the same approximately 132-pixel building/city visual family. The pack's sample depicts storefronts, multi-story buildings, roof modules and low-rise structures combined into a cohesive city block. This is the **recommended starting family** for MetroForge's current 132-ish city tiles.
- **Isometric Modular Buildings:** 101 numbered part identities, each with four camera-facing variants = 404 files. These are primarily roofs, building volumes, wall/facade and architectural details, rather than 101 pre-designed buildings. The instructions give a **180×115 footprint** on a **224×206 image**; not plug-compatible with the smaller city tiles.
- **Isometric Vector Buildings:** 155 numbered shapes across **four materials** (concrete, sand, stone, wood), plus **32 awning PNGs** = 652 files. Individual components are frequently only 50 pixels wide and are best used as a distinct coherent miniature building visual family, unless carefully scaled and stylized.
- **Supporting infrastructure:** 128 `cityTiles` PNGs and 11 city detail images enable lots, streets and urban decoration in the smaller family. Other terrain and roadway packs offer further choices, but must be matched to a consistent projection/tile footprint.

**Critical distinction:** A visually generic building can stand in for a hospital, school, office or factory, but it does not become a convincing specialized building without additional identifying artwork. Do not claim an explicit hospital, power plant, fire station or industrial tower prefab exists where the files contain only generic modules.

## Pack-by-pack observations

### A — Isometric Tiles Buildings (`Isometric Tiles Buildings/PNG/buildingTiles_000.png` … `_128.png`)

- Exactly **129** standalone transparent PNGs.
- Actual inspected examples:
  - `buildingTiles_000.png`: small single-floor building block with windowed walls and a parapet/flat roof.
  - `buildingTiles_060.png`: low pyramidal/hip roof piece.
  - `buildingTiles_080.png`: higher pitched roof piece.
  - `buildingTiles_100.png`: shop-like structure with front detail on its own terrain foundation.
  - `buildingTiles_128.png`: flat roof or cap plate.
- Original `Sample.png` shows several multi-story buildings, red/beige wall finishes, storefront awnings and street blocks combined convincingly. The arrangement is a showcase; every apparent finished building is not necessarily a single file.
- Typical transparent image canvases vary. Some are around **132×127 pixels**, others around **99×60–85 pixels**. Separate ground/base tiles from upper floors and roof plates.
- **Best uses:** low-rise residential, apartments, shops, offices; potentially generic civic buildings; multiple growth levels.
- **Weaknesses:** relatively few unique silhouettes and branded/special-purpose architectural cues, no verified finished dedicated power-plant/hospital/stadium sprite.

### B — Isometric Modular Buildings (`Isometric Modular Buildings/PNG/modularBuildings_001_0.png` … `_101_3.png`)

- Exactly **101 numbered parts** × **4 rotations** = **404** images.
- All images use a **224×206 pixel canvas**; `Tile information.txt` specifies a **180×115 pixel tile footprint**.
- Individually inspected modules include `001_0` (flat roof parapet), `020_0` (flat cap with color trim), `040_0` (plain solid building mass), `080_0` (single aperture/frame), `090_0` (wide rectangular frame), `100_0` (pair of narrow vertical elements). Other elements include roof pitches, floor sections, façade/window and door variants as seen in the pack preview.
- **Best uses:** customizable 1–3 story shops, homes, rowhouses, offices; height-scaled urban growth after alignment tests.
- **Weaknesses:** four views of one component are not four different models. A tall building made by stacking floors still needs careful depth ordering. Mixing directly into the smaller 132px tile family requires grid conversion and potentially changes the perceived art density.

### C — Isometric Vector Buildings (`Isometric Vector Buildings/PNG/...`)

- **155 same-index shapes** repeated in `Concrete buildings`, `Sand buildings`, `Stone buildings`, `Wood buildings` (620 files) + **32 awnings**.
- Observed `concrete000.png`: plain low cube/parapet module. `concrete154.png`: windowed wall/roof unit. Other shapes include roof/wall/window pieces as shown by the source preview.
- **Best uses:** a large number of palette/material variants, simple skyline diversity, procedural changes in color/texture.
- **Weaknesses:** image sizes commonly **50px wide**, strongly different from the main city family. This is a separate low-detail vector set; scaling can magnify stylistic differences.

## Proposed MetroForge building archetypes

| Building / game archetype | Existing material to start with | Usability | Additional art for an identifiable final result |
|---|---|---|---|
| Cottage / starter house | Small roof + low building sections; modular pitched roof | Good composite | Optional gardens, porch |
| Detached suburban house | Same with window/front variant and terrain decoration | Good composite | Driveways or garages optionally |
| Duplex and townhouses | Adjacent wall modules, varied roof/cap | Good composite | Front doors and color details |
| Low-rise apartments | Stack 2–4 windowed floor elements | Good composite | Optional balcony variants |
| Mid-rise apartments | Stack regular floors; alternate façade colors | Good composite | Roof equipment, balconies for variety |
| Small shops and retail | Existing small storefronts, awnings | Good composite | Store signs, window displays |
| Restaurant/café | Shop with awning | Good placeholder | Food signage, awnings / outdoor seating |
| Offices | Repeated regular windows and flat roof | Good composite | Rooftop HVAC, lobby details |
| Towers / dense office core | Repeat window modules; vary height/roof | Partial | Distinctive tops and facades, shadow/height checks |
| Warehouse / storage | Box mass + plain roof | Partial | Loading docks, rollup doors, trucks |
| Light industry | Plain flat-roof modules | Partial | Vents, chimneys, machinery, industrial doors |
| Heavy factory / refinery | Generic mass only | Poor dedicated art | Smokestacks, tanks, cranes, conveyors |
| Police station | Generic low-rise civic-looking building | Partial | Blue signs, garage, insignia |
| Fire station | Generic low-rise block | Partial | Large vehicle-bay doors, tower/signage |
| Hospital / clinic | Generic office/low-rise medical-sized building | Partial | Medical cross, ambulances, roof details |
| School / library | Generic multistory block | Partial | School entrance, campus yard/signage |
| Town hall | Generic office façade | Partial | Civic portico, clock, ornamentation |
| Power plant | Generic box only | Poor | Complete generation of facility elements |
| Water-treatment plant | Generic box only | Poor | Tanks, filtration pools, pipes, pumps |
| Waste / recycling facility | Generic box and grounds | Poor | Dumpsters, sorting equipment, trucks |
| Rail station | Generic commercial façade | Poor | Platform, canopy, rails, signs |
| Stadium / university / landmarks | No distinct prefab found | Poor | Purpose-made large-footprint sprites |

`Good composite` means **visually feasible after tested assembly**—not an implemented or premade prefab. `Partial` means a generic placeholder can be assembled but lacks character. `Poor` means dedicated artwork is needed for a convincing result.

## Development-level variety without buying additional packs

**Residential**: small low-roof house → medium/two-story house → rowhouse/duplex → three-story apartment → mid-rise apartment. Add palette/roof/porch/garden alternatives after a consistent alignment system is proven.

**Commercial**: small street-front shop → double storefront/restaurant → mixed-use two- or three-story building → low office block → mid-rise office → tower. Vary awnings, window patterns, wall materials, roof features and building footprint.

**Industrial**: shed/storage → warehouse → light factory → manufacturing complex → heavy factory. The first three can begin with generic shapes, but steps 4–5 **need targeted custom industrial sprites** to look convincing.

These are **design possibilities**, not counted variations currently furnished as exported assets. The practical number of convincingly different buildings depends on composition rules, accepted repetition and style coherence.

## Priority list for Retro Diffusion, using existing art as reference

1. **Power infrastructure:** coal/gas plant, substation, solar lot, wind turbine, electrical transformers and power-line attachments.
2. **Water and waste infrastructure:** elevated water tank, pumping station, treatment tanks, sewage plant, waste/recycling center.
3. **Civic buildings:** distinct firehouse with firetruck door, police department, hospital with ambulance bay, primary school, city hall.
4. **Industrial variety:** silos, chimneys, loading docks, storage tanks, factory roofs, industrial pipes, refinery units.
5. **Residential/commercial flair:** corner shops, apartment balconies, garages, rooftop antennas/HVAC, signs, markets.
6. **Landmarks:** stadium, train station, university, museums, monuments.

**Recommended workflow:** first choose the `Isometric Tiles Buildings` + `Isometric Tiles City` source family. Feed the website 2–4 **original Kenney sprite images** rather than a screenshot, and describe the desired new asset in that exact flat-colored, minimally shaded geometric low-poly vector style. Ask for 4–6 **separated objects** in the first sheet. The reference-image feature may help but cannot guarantee exact projection and footprints. Do a small 3-building ground-alignment test in the game before bulk generation.

## Sprite atlas/build manifest rules for MetroForge

- Keep **separate** authored building `type` from underlying **visual variant**, `asset file`, base footprint, layer order, and offsets.
- Use the small tile family as the default, unless an actual comparison demonstrates the modular/180px family produces a better full city at phone viewing size.
- Organize by zoning (`residential`, `commercial`, `industrial`, `civic`, `utilities`) and visual growth stage; represent different styles of the same building using variants.
- Generate composite variants offline during a build step (or cache rendered variants) rather than recomposing hundreds of layers every frame.
- Enforce asset anchors on the ground diamond, not canvas width/height. Classify module layer as ground/base, repeated floors, cap/roof, façade accessory and taller occluders; verify each image ID before asserting a specific classification.
- Treat roads, vehicles, and parks as separate art systems from building composites.
- Preserve the CC0 license/readme files with source assets and document any externally generated additions separately.

## Attached machine-readable index

`MetroForge_Building_Asset_Index.json` contains **417 canonical inventory entries**: 129 numbered small-building tiles, 101 modular identities, 155 vector-shape identities and 32 awnings. Every entry lists its actual PNG file paths and image canvas/visible alpha bounds; multi-view or multi-material records list their related files. This is a useful foundation for Codex to build a searchable asset manifest. Because every individual file was not manually visually classified, `semantic_label` explicitly says so rather than pretending to identify every sprite.
