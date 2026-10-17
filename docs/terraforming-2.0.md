# Terraforming 2.0 — Phases 0–2

Approved scope: baseline audit, elevation range −5…+12, safe centered brushes and Flatten. Flat stepped terrain remains the only geometry. Directional slopes, rounded caps, smoothing, hill presets and shape metadata belong to later phases. No showcase city or release replacement is included.

## Phase 0 baseline and contract

Base: `31014d86aedcce38eefaa34bbf76a7ce62a42bdd`, clean `feature/godot-migration` worktree. The plan references `cb4d91c`, a subsequent CI-trigger comment with identical game sources. That remote commit is preserved when integrating this work; automatic growth and building palettes remain intact. The existing 13-suite `python godot/tools/check_project.py` baseline passes. The legacy-v6 fixture and current Harbor fixture are retained; internal fixtures do not replace examples.

Native terrain is retained 2D geometry: flat 132×66 source caps, procedural front retaining faces, a single packed runtime atlas and ordered mesh buckets. `_point(x,y,height)` shifts projected y by height×0.15 tile units. Picking formerly checked −3…+5; camera Fit used a fixed height margin. Both must share the model's new bounds without rebuilding the simulation.

The original five atlas hashes and four CC0 licenses pass. Exact selected terrain source crops from `assets/atlases/terrain.png` (1024×2048) are:

| Material | Source file | XML rectangle x,y,w,h | Use/status |
| --- | --- | --- | --- |
| Grass | landscapeTiles_067.png | 398,265,132,99 | Flat cap only; exclude baked foundation |
| Water | landscapeTiles_066.png | 398,364,132,83 | Flat cap only; existing water rules |
| Sand | landscapeTiles_059.png | 529,1009,132,99 | Flat desert cap only |
| Dirt | landscapeTiles_073.png | 397,1745,132,83 | Flat dry-channel cap only |

Their top diamonds use the original 132×66 UV region; PNG lower walls are never stretched into terrain. These are recorded original sprites, not directional slope art. The original later ZIP uploads are not present locally. Other numbered terrain crops are unclassified here; no waterfall, riverbank, embankment or slope direction is asserted from a filename. No source PNG, atlas generation or license is changed in this effort.

`godot/tools/preview_terrain.gd -- OUTPUT [PEAK]` captures an internal flat plateau/cliff, grass/desert, basin, waterfront, road/rail bridge and elevated buildings (with a GL display). Baseline uses PEAK=5; candidate uses 12. The unchanged Harbor profiling tool supplies full-city/dense-district comparisons. Desktop software GL is not a Galaxy S25+ FPS result.

## Schema and geometry contract

Keep version 6 and the existing 52×52 tile array. Integer `elev` is authoritative; centralized model constants are −5 and +12. Reject unsupported or fractional imported heights rather than clamping. Valid old saves keep occupancy, autoGrow, parcels, cash, calendar, network tiles, biome and channels. No generated geometry is serialized. A new city remains flat at zero.

Corner order for later shape work is `(x,y), (x+1,y), (x+1,y+1), (x,y+1)` (NW,NE,SE,SW). Current flat/cliff tops have four identical heights. No slope metadata is advertised or generated in Phases 1–2.

| Internal future geometry fixture | Reference elevations | Current result / later constraint |
| --- | --- | --- |
| 3×3 peak | 0,1,0 / 1,3,1 / 0,1,0 | Nine flat caps with retaining faces |
| 3×3 valley | 0,−1,0 / −1,−3,−1 / 0,−1,0 | Nine flat caps; no automatic flooding |
| 2×2 ramp | 0,1 / 0,1 | Stepped now; future connected ramps must share edge samples |
| Plateau/cliff | 12,12 / 0,0 | Flat buildable tops with explicit retaining faces |
| Water/desert border | water=0 beside dry sand=2 | Water stays level; sand cap stays sand |

Later smoothing must not alter reference heights or protected lots implicitly. Connected smooth edges must share exact samples; hard boundaries require explicit faces. The Phase-3 corner/edge design gate remains pending.

## Phase 1 acceptance checklist

- All elevations −5…+12, map edges/corners and visible cliff faces can be selected; hidden background surfaces do not win picking.
- Fit derives actual retained geometry bounds, including roofs and retaining faces, instead of reserving a global maximum-height margin on every map.
- Bound edits cost nothing and create no history. Valid v6 and expanded-height exports round-trip.
- Natural water sources and connected channels at elevation ≤0 retain the existing reflow rule; a raised channel dam disconnects downstream channels without flooding ordinary land.

## Phase 2 transaction contract

Brushes are centered squares with radius 0/1/2 (1×1,3×3,5×5), clipped at map borders. Height steps are 1/2/4. Raise/Lower clamp deliberate targets; Flatten uses the first touched tile's height or an explicit target in range. One changed cell costs $20 regardless of height delta, unchanged/protected cells cost zero. Protected structures, zones, power lines, underground pipes and natural water are skipped with a visible reason. Existing channel bed edits are allowed so old channel reflow remains useful.

Planning is pure: determine affected cells, targets, reasons and total cost before changing the world. Overlapping stamps use one stroke-start state and deduplicate cells. Reject an unaffordable transaction in full. Capture edited cells and every changed channel; reflow once, recalculate once, refresh once and record one undo action. During a staged terrain stroke, the city clock is held so costs and protected state cannot change under the preview. Two-finger/canceled gestures discard their pending footprints.

The compact Terraform popup exposes only implemented operations/settings. A live footprint/cost preview follows mouse/touch; the selected tool summary always shows brush/step or Flatten target. Flat stepped geometry is explicitly labeled. No disabled placeholder slope/smooth controls are shown.

## Phase 1 result

The new bounds suite first failed 269 of 431 assertions against the baseline, then passed 431/431 after the bounds/picking/Fit changes. All 14 registered suites pass, including the untouched automatic-growth, color asset, persistence, UI, cache and FPS checks. Picking tests all 18 heights and four corners; front retaining faces use the exact same polygons for drawing and hit-testing. Fit scans retained command extents only when requested. Existing world bound assertions now test +12/−5 and reject −6/+13 imports.

Source changes: centralized `CityWorld` limits, validated imports and placement; shared visible-face geometry and actual command bounds in `isometric_view.gd`; corrected help text; a dedicated terrain-bounds suite and expanded existing view tests. No shape metadata or art changed. Version-6 exports containing heights outside −3…+5 require this updated build; old builds will reject those new heights rather than read them incorrectly.

## Phase 2 result and how to test

Open Terraform, choose Raise, Lower or Flatten, then reopen Terraform to adjust the selected operation's settings. Height step appears only for Raise/Lower; Flatten offers First touched tile or Set height. Settings remain for the current app session and do not enter save files. Other terrain tools keep their earlier single-cell behavior. The lower map status shows the active brush/step or target and the preview's exact cost/skipped reasons.

`model/terrain_editor.gd` owns pure footprint/target/cost planning and a single validated commit. `ui/terrain_settings.gd` owns the compact popup controls. The controller stages a set until release and uses the returned transaction for existing construction history. The view draws current/target footprints and blocked cells without changing terrain. Protected zones/structures, roads, rail, power lines, underground pipes and natural water are skipped; legal neighboring cells can change. Insufficient total funds rejects the entire set. Trees remain attached to their reference ground height. Channels keep existing connectivity rules and all resulting channel changes participate in history.

The 16-suite runner includes 431 terrain-bound checks, 130 planner/history checks, 39 controller/gesture/UI checks and the existing 746 automatic-growth checks. A 5×5 edit performs one model recalculation and one channel reflow; a 3×3 edit regenerates at most 25 local records. Camera movement reuses retained meshes. Valid expanded heights round-trip through actual JSON encoding; original source artwork and licenses still pass receipt checks.

Independent review reproduced two important bugs before completion: retraced paths could interpolate an extra unpreviewed cell, and native magnify/pan events could retain queued mouse paint. New native-input regression tests failed in all three cases before the fixes, then passed. Terrain now commits the exact traversed center set and discards pending edits when these gestures begin.

Two minor limitations remain: Tap + pan holds do not pause the city clock before release (the edit is freshly planned/validated at release); at widths ≤720 the header's tool summary is hidden, so settings/preview status provide brush details, and the status shows the edit result after release. Paint previews/staged controller strokes hold simulation time. Android behavior still needs on-phone testing; desktop tests do not establish Galaxy S25+ FPS.

## Paired rendering probe

Godot 4.6.3 compatibility renderer, Mesa 25.0.7 llvmpipe LLVM 19.1.7, unchanged Harbor fixture (4,371 residents), unchanged `tools/profile_city.gd`, 1280×591 output/854×394 logical viewport, sequential baseline/candidate runs. Timings are 30 frames after warmup. Baseline is `31014d8`. New Fit uses actual retained geometry (scale 4.654 versus the old fixed-margin 4.246); district/close scales match exactly.

| Case | Baseline / candidate draw calls | Baseline / candidate median frame ms |
| --- | ---: | ---: |
| Full city static | 589 / 589 | 49.129 / 47.161 |
| Full city moving agents/pan | 590 / 590 | 54.345 / 54.090 |
| District moving agents/pan | 447 / 447 | 76.289 / 79.006 |
| Close moving agents/pan | 258 / 258 | 78.696 / 77.468 |

Rendering submissions are unchanged and measured cost stays similar in this paired software-GL run. This does not establish a small speed change or mobile FPS. Source atlases, generated color atlas, shader and mesh-batching implementation are unchanged. No new APK has been built, no download/release replaced and no signing identity changed.

Phase 2 is the stopping boundary. Next, only with a new instruction, Phase 3 would introduce verified shape metadata, deterministic corner/edge geometry, directional ramps/cliffs and shape-aware picking. Rounded hills and smoothing remain later work.

## Android test packaging

The user subsequently authorized an APK of these completed Phases 1–2. Version 0.3.3 (`0.3.3-terraform-preview`, Android version code 4) retains the native package identity and includes both terrain phases plus the earlier building variety. No later terrain phase is added. Build receipts now identify the exact source commit as well as source-file hashes. CI verifies the full suite, official release runtime, ARM64/ARMv7 contents, Android signing and alignment, then attaches the APK/source/checksums to a separate unpublished terrain-test draft. Uploads do not replace earlier preview assets.

The repository's existing preview-signing workflow uses its configured keystore secret when available, otherwise a temporary test certificate. An APK signed by another test certificate cannot update an installed preview in place. Export city JSON before any uninstall; expanded-height exports need the new build. This remains test signing, not production/store publication.
