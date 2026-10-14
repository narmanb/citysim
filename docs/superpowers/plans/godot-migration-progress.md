# Migration progress — plan: 2026-10-14-godot-migration.md

Worktree `/workspace/citysim-godot`, feature branch starts at `0a9eee7`; design commit `e933fa6`. Existing renderer branch and APK 0.2.2 remain unchanged. Baseline: ten existing Node checks pass.

Tasks 1–4 are complete. Model, renderer and UI implementations were integrated with native persistence, regression corrections, documentation and Android packaging. All commits are on `feature/godot-migration`.

Interface preflight: model produces World/state methods consumed by view, UI and store; view produces interaction signals consumed by UI; store produces safe import/save consumed by UI. File ownership is disjoint. The Godot renderer's map zoom property is `tile_scale`, because inherited Control.scale is already a Vector2.

Scope: user explicitly deferred live wallpaper. No wallpaper service, permission, or Android background execution is implemented. The UI-independent model is retained for that later feature.

Verification on Godot `4.6.3.stable.official.7d41c59c4`: world 99 checks / zero failures, store 31 checks PASS, view zero failures, game PASS. The runner rejects runtime errors as well as nonzero exits. Original JavaScript seed-4242 terrain/tree generation and district simulation at months 1, 6 and 12 match the recorded baseline. Five atlas PNGs and four CC0 license hashes match the original game.

Native software-rendered captures were inspected at 854×394 and 1280×720, including dialogs. The final preview image is a populated city imported from the original JavaScript game. No Android phone is connected; device performance, Android file-picker behavior and real touch hardware remain unverified.

Independent whole-change review identified malformed-import and disconnected-diagonal-stroke defects. Both were corrected with failing-first regression tests. Scoped re-review confirmed those corrections and found an additional legal road/rail/station import regression. Its guard and real-placement round-trip test were corrected; root independently reproduced successful import after the final change. No reported Critical or Important finding remains unaddressed.

Final APK: `/workspace/artifacts/MetroForge-Godot-0.3.0-debug.apk`, 57,662,770 bytes, SHA-256 `330ecd8c1a1c07efc58b758a54840c874d531b200413f3061b88881392cc62c5`. It contains compiled GDScript, ARM64/ARMv7 Godot libraries, matching source receipts and source-art licenses; no HTML or JavaScript game payload. ZIP integrity, debug signature, package/version, API 24 minimum / API 36 target and 16 KB ZIP alignment passed. Export uses the official matching Godot Android template; the available SDK build tools fall back to 34.0.0 with a warning, and signature/alignment checks pass.

Intentional behavior corrections: diagonally dragged construction now inserts orthogonal connector cells and charges each placed cell; no-op terraforming costs nothing; unknown tools and invalid city tile states are rejected; missing legacy fields receive explicit defaults. Local seeded randomness does not promise identical stochastic agent/disaster sequences. Smooth corner-height slopes and wallpaper remain deferred. Atomic JSON saves keep a previous valid backup; the new package uses separate storage and imports old cities through JSON.

A clean source-only copy also passed all four suites after the check helper generated its Godot import/class cache. Source, reproducible build/check helpers and the Android APK are ready for handoff. The original worktree and main branch remain unchanged.
