# Conversion progress

Binding brief: user-supplied MetroForge_Isometric_Conversion_Plan.md; local refinement in isometric-design.md.

M0: complete — baseline run/save round trips, main retained, feature branch created.
M1: complete — supplied subset inventoried, licenses/hashes preserved, coherent interactive art proof.
M2–M4: browser milestone complete — separate renderer, projection/picking, cache/culling, depth and terrain occlusion, overlays/input, adjacency roads/bridges, actual agents, contained parcels, growth/abandonment/fire and honest procedural art for uncovered systems.
M5: resource packaging and browser/touch regressions complete. Follow-up installed official Android build tools and a full Java 17 JDK, compiled and verified a signed debug APK. Device acceptance remains unverified because no Android device is attached. Managed browser file URL policy blocks direct offline navigation.

Decisions: use the available 132×66 family; absent modular families cannot be compared. Use asphalt/pavement texture clipping for complete road masks instead of implying the archive has uniquely named adjacency tiles. Keep simulation/save classes unchanged. Keep the local feature branch for user review, without publishing or merging.

Independent whole-change review found no Critical issues and identified bridge rail orientation, cliff culling, and raised-ground occlusion. All were fixed with geometry or pixel regressions. A final requirement check also added visibly distinct house/industrial growth levels. No review minors remain deferred.

Final verification commands and their measured outcomes are documented in isometric-validation.md. Runtime and source ZIPs are produced separately under /workspace/artifacts.

Android follow-up 0.2.1: reproduced reported pan-dependent empty-ground artifacts, clipped the occlusion replay to terrain surfaces, and passed 36 camera/tree-isolation checks plus the existing regression suite. Rebuilt and verified an APK signed with the same preview certificate and application ID; versionCode 3 supports an in-place preview update. See rendering-pop-in-fix.md.
