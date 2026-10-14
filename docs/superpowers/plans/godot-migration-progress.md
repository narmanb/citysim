# Migration progress — plan: 2026-10-14-godot-migration.md

Worktree `/workspace/citysim-godot`, feature branch starts at `0a9eee7`; design commit `e933fa6`. Existing renderer branch and APK 0.2.2 remain unchanged. Baseline: ten existing Node checks pass.

Tasks 1–3 are being implemented in separate owned files against the shared interface spec; root owns task 4 and integration. Model agent `godot_model`; renderer agent `godot_view`; UI agent `godot_ui`. They do not own each other's files and do not commit independently.

Interface preflight: model produces World/state methods consumed by view, UI and store; view produces interaction signals consumed by UI; store produces safe import/save consumed by UI. File ownership is disjoint. The Godot renderer's map zoom property is `tile_scale`, because inherited Control.scale is already a Vector2.

Scope: user explicitly deferred live wallpaper. No wallpaper service, permission, or Android background execution is implemented. The UI-independent model is retained for that later feature.

Implementation in progress; do not treat scaffold or migration as complete until native tests, rendered inspection, Android export and independent review finish.
