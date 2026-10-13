# MetroForge 2000

The existing city-builder now has a Canvas isometric renderer using the supplied Kenney CC0 starter assets. City simulation, version-6 save JSON, older import defaults, zoning parcels, utilities, transport, events and construction history retain the existing implementations.

Open `MetroForge-2000.html` with its adjacent `assets/` and `src/` folders intact, or serve this directory with `python -m http.server 8765`. `isometric-preview.html` is a separate small art proof. Use City / Files → Export JSON and Import JSON when moving a city between browser origins, folders or devices.

Package a portable browser build:

```sh
python tools/package_runtime.py --browser-zip /tmp/MetroForge-Isometric-Browser.zip
```

Extract the entire ZIP and open `index.html`. Runtime scripts and images are local; there are no external libraries, API calls or asset downloads. The package preserves all four source CC0 license files.

The Android GitHub workflow invokes the same packaging script. Locally, with Android SDK 35, a full Java 17 JDK and Gradle 8.10.2 installed:

```sh
python tools/package_runtime.py --android-dir app/src/main/assets
gradle :app:assembleDebug --no-daemon
```

The debug APK installs as **MetroForge Isometric** (`com.narmanb.metroforge.isometricpreview`) alongside the existing app. Its version is `0.2.0-isometric-preview`; the release variant retains the original application ID. The APK is a device-test build; launch, persistence and performance on the target Android device still require manual verification.

Regenerate the asset mapping from the original supplied starter ZIP using `python tools/import_isometric_assets.py /path/to/MetroForge_Starter_Isometric_Assets.zip` (requires Pillow). Original atlas PNG/XML bytes are preserved; `assets/manifest.json` records source hashes, sprite crops and anchors. The matching `manifest.js` avoids fetching JSON under Android file URLs.

Verification commands (Python browser checks require Playwright and Chromium):

```sh
node --test tests/isometric-core.test.js
python tests/package-runtime.test.py
# With python -m http.server 8765 running:
python tests/browser_isometric.py
python tests/touch_offline.py
python tests/city_rendering.py
python tests/terrain_occlusion.py
python tests/building_growth.py
```

Plant, pump, tower, service buildings, industry and rail art use deliberate procedural composites and labels because the supplied subset has no dedicated sprites for these systems. The terrain renderer uses stepped elevations and shoreline edges; it does not add terrain mechanics. See [design and audit](docs/isometric-design.md) and [validation report](docs/isometric-validation.md) for measured results and device limitations.
