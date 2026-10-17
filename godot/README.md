# MetroForge — native Godot preview

Open `project.godot` with **Godot 4.6.3 standard edition** and press Play. This project runs the city simulation and renders its scene natively with GDScript and Godot 2D. The earlier browser/WebView game is retained separately in the repository.

## Changes in 0.3.2

Populated cities now batch roads, railways, utility strokes, terrain and sprites in ordered meshes. Harbor City's full-view submissions drop from 20,134 draw calls to 598 in the desktop probe. Local amenity influence updates reduce monthly simulation CPU work. A visible FPS / frame-time display above the zoom controls reports real rendered frames, including stalls. Existing sprites and depth order are preserved; the APK uses the release engine with preview signing.

See [the populated-city performance report](docs/performance-0.3.2.md) for measurements, limits and reproduction steps. Actual Galaxy S25+ readings still require testing this APK.

## Earlier changes in 0.3.1

Placement refreshes retain static scene layers and rebuild only affected tile commands. Terrain quads are batched, including an opaque cap shader to preserve seamless ground edges. Utility and environment calculations skip irrelevant work while preserving simulation results. The interface restores the earlier stat badges, single tool bar, pop-up palettes, demand meters and larger touch scale.

Desktop CPU/software-GL measurements and regression checks are recorded in [the performance report](docs/performance-0.3.1.md). These measurements do not establish frame rate on Android; Galaxy S25+ testing is still needed.

## Android

The preview is named **MetroForge Godot**, package `com.narmanb.metroforge.godotpreview`, version `0.3.2-godot-preview`. It installs alongside MetroForge Isometric. Android 7.0/API 24 or later and OpenGL ES 3 support are required by this Godot template. The APK includes ARM64 and ARMv7 libraries.

Install the matching official Android export templates in Godot. Configure Java 17 and the Android SDK in Editor Settings → Export → Android. The standard, non-Gradle Android preset uses the template's target SDK 36. Then run:

```sh
python tools/build_android.py
```

The APK uses the release engine template signed with a testing certificate. Configure a release keystore in the export preset or provide `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER` and `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD` when building locally. CI supplies its preview keystore through these environment variables.

The testing certificate is for preview installs. Public release signing and store publication are separate actions.

The build helper records source SHA-256 receipts in the APK and validates its native scripts/libraries. It uses the same export command available directly through Godot's Android export preset.

The `Build native Godot Android preview` GitHub Actions workflow builds the migration branch, runs the native tests, and provides an APK/source download under the run's Artifacts. It also attaches those files to the existing unpublished `v0.3.2-godot-preview` draft release. The workflow checks the draft status before replacing any attachments.

CI can use an Android debug keystore supplied through the repository Actions secret `GODOT_ANDROID_DEBUG_KEYSTORE_BASE64` (alias `androiddebugkey`, password `android`). Without that optional secret, each run creates its own testing key; Android then requires uninstalling a differently signed previous preview before installing that build. Export city JSON before uninstalling. Production signing keys are not part of this workflow.

## Move an existing city

1. In the old Android app, save the city and use City / Files → Export JSON.
2. Open MetroForge Godot → City / Files → Import JSON. Select that file with the native file picker, or paste its JSON text in the import panel.
3. Save the imported city in the Godot app.

The two apps use different private storage, so existing browser local storage does not automatically appear in Godot. Valid legacy city tiles, elevations, parcels, treasury, calendar, taxes, funding, stored occupancy and historical accounting are imported. Derived networks and statistics are rebuilt. Older tree/power-line overlaps are normalized. Invalid imports leave the current city intact. Saving retains a previous-valid `.bak` file for recovery.

## Controls

Tap with a construction tool to place one tile; dragging in Tap + pan mode moves the camera. Paint mode commits a connected stroke on release. Two fingers pan and pinch without spending money. Fit shows the whole city; +/− and pinching zoom into a district. The native controls include all current tools, overlays, budgets, events, guide, pause/speeds, selection details, files and construction-only undo/redo.

## Tests

```sh
python tools/check_project.py
```

This first imports source textures and registers script classes, then runs the native model/environment, persistence, mixed mesh/atlas, view/gesture, render-cache, game/controller, UI layout and FPS tests with timeouts. It rejects GDScript runtime errors even if the engine returns exit code zero. `tests/test_view.gd -- --capture` can capture the rendered fixture when run with a real display and `--rendering-method gl_compatibility`.

The model tests compare deterministic results against the original JavaScript at months 1, 6, and 12, as well as all 2,704 generated terrain/tree tiles for a known seed. Tests and software-rendered captures do not establish behavior on a particular Android phone.

## Structure and scope

`model/` owns the UI-independent city and simulation; `view/` owns the isometric scene and gestures; `ui/` owns controls and construction history; `persistence/` owns JSON storage. The model has no scene-tree or Android dependencies, so a future wallpaper controller can reuse it.

Live wallpaper, continuous background simulation, and smooth corner-height slopes are **not implemented** in this preview. All existing simulation systems have been ported; some civic, railway, and industrial artwork still uses the same procedural composites as the previous version.

Source artwork is Kenney CC0. Original source PNG bytes and the four license texts under `assets/licenses/` are preserved. Godot's MIT license is also included there as `Godot-MIT.txt`; further engine license information is available at https://godotengine.org/license/.
