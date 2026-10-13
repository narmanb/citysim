# MetroForge isometric conversion

The supplied `MetroForge_Isometric_Conversion_Plan.md` is the design brief and milestone order. Convert the existing renderer while preserving the 52×52 simulation, version-6 JSON saves and older import defaults, parcel identity, infrastructure, disasters, history, touch controls and offline Android use. Work locally on `feature/isometric-renderer`; do not merge main.

## Audit, 2026-10-13

Baseline main: `163a698275c2c4250a6d9b095902c5adca3dffe4`. Chromium launches without page errors. The actual Save/Load and Export/Import controls preserve test-city tiles, seed and cash. A baseline export and screenshot are retained under `/workspace/scratch/baseline/`.

The supplied starter archive contains 972 entries, 957 PNGs and four CC0 packs: Base, City, Buildings and Vehicles. It is not the complete twelve-pack archive described in the brief. The 180-pixel modular and 100-pixel vector families are absent, so a comparison with them cannot be performed with the supplied files.

Use the compatible 132-pixel family on a 132×66 ground diamond. PNG height includes walls, raised terrain, curbs or building height and cannot serve as tile pitch. Use explicit anchors per sprite. Preserve original atlas PNG/XML bytes and all four licenses, with source hashes in the manifest. Keep five atlas textures (terrain, city, buildings, details, utility vehicles), not hundreds of independent image requests. Road layouts use the City asphalt and pavement textures with explicit adjacency geometry; these connections are constructed, not claimed as distinct supplied road sprites.

## Implementation boundaries

Projection, inverse coordinates, road masks, culling and parcel footprint selection belong in a pure shared core. A separate renderer consumes existing world tiles, fields and agents through an explicit dependency object. No simulation or serialization class changes. Use ground diamonds for overlays, parcel edges, selection and placement feedback. Elevated tiles shift their ground surface and picking must account for that shift. Draw overhanging objects in ground-depth order; cull by their complete screen rectangles.

Multi-tile parcels remain one property and use a contained rectangular building footprint, leaving irregular parcel portions as yard. Growth types and levels choose building components; abandonment and fire add visual state. Missing plant/pump/tower, civic, industry and railway art use labeled procedural composites; no external assets or generation jobs.

First prove an interactive small scene before connecting the renderer to the real city. The proof is explicitly an asset test, not a replacement game. Then wire the actual CityRenderer and InputManager together, retain the existing simulation and controls, and package all runtime resources for browser and Android. Use ordinary scripts and Image loading so Android file URLs do not depend on fetch or a server.

## Acceptance and evidence

Verify forward/inverse projection over all tiles and multiple zoom levels, elevated picking, masks at map edges, parcel containment, atlas crop bounds and hashes. Exercise real browser placement, pan, zoom, paint/history, export/import, overlays and touch gestures. Run the existing workflow simulation smoke checks. Check packaged resources offline. Record desktop measurements separately from Android device performance. A device APK launch and measured Android responsiveness require Android tools/device availability; never infer them from browser results.
