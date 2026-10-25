# Civic, Utility and Variety Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Track progress in /workspace/scratch/civic-utility-update/progress.md.

**Goal:** Deliver the user's three approved artwork groups in one verified native Android APK.
**Architecture:** Offline compositions from existing verified small-family modules plus clearly recorded procedural signage/equipment, packed in one retained atlas. Pure deterministic catalogs select cosmetic recipes without simulation or save mutations.
**Tech Stack:** Godot4.6.3 GDScript, existing retained CanvasItem renderer, official Android export.
**Spec:** docs/superpowers/specs/2026-10-25-civic-utility-variety.md

## Global Constraints
- Save13, three zoning buttons, automatic growth and six palettes remain.
- Terraform free; terrain bounds-5..40. Existing capacities/costs remain.
- One1024x2048 atlas budget; no external packages or new agents.
- Native Android0.3.18/code19, same package/orientation/signing workflow.

## Review Focus
- Civic foundations on graded cells and adjacent tall-object depth.
- New aliases resolve for all palettes and every growth level.
- Abandoned industrial properties tint consistently.
- Old saves render new art with identical model serialization.
- Phone zoomed-out performance: prevent per-frame composition/node growth.

### Task1: Civic and utility compositions
- [ ] Add offline civic helper and meaningful tests; verify RED before implementation.
- [ ] Compose recognizable police/fire/school/hospital/plant/pump/tower (station optional), explicit derivation metadata and ground anchors.
- [ ] Render facilities as retained atlas sprites at Civil.build_height; check flat, raised, gentle ground, no model changes.

Files: godot/tools/bake_civic_art.gd, godot/view/civic_catalog.gd, godot/view/isometric_view.gd (_draw_civic only), godot/tests/test_civic_art.gd.
Interface: static BakeCivicArt.add(images:Dictionary,descriptors:Dictionary)->Dictionary metadata; images already contain selective building module variants. CivicCatalog.sprite_for(kind:String,seed:int,index:int)->String returns atlas alias. All helpers pure/offline as applicable.

### Task2: Housing/business/industrial variety
- [ ] Add offline property helper/recipe extension and tests, initial RED evidence.
- [ ] Curate additional visual silhouettes/frontages/industrial profiles with six palettes and stable selection.
- [ ] Validate every alias, growth stage and provenance; preserve original material masks.

Files: godot/tools/bake_property_art.gd, godot/view/building_catalog.gd, godot/tests/test_development_art.gd. Agent must not edit renderer or atlas builder to avoid concurrent conflicts.
Interface: static BakePropertyArt.add(source_images:Dictionary,images:Dictionary,descriptors:Dictionary,recipes:Dictionary)->Dictionary containing recipes and provenance. Report renderer recipe field contract to parent before integration.

### Task3: Integration, native evidence and APK
- [ ] Parent integrates helpers into atlas builder, property recipe fields into renderer, new suites into check_project.
- [ ] Run all native checks; inspect detailed facility/utility/property screenshots, save neutrality and exact cached/full rendering.
- [ ] Run matched populated-city baseline/candidate probe sequentially with frozen source.
- [ ] Review full change with fresh reviewer; fix important findings, repeat affected tests.
- [ ] Bump0.3.18/code19 and unique release/artifact paths, run CI/export checks.
- [ ] Publish new preview; download anonymously, verify hash/signature/ABI/alignment before user link.
