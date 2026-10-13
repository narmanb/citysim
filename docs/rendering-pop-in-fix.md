# Camera-dependent terrain pop-in — 0.2.1

The Android screenshots showed dirt-colored strips on flat grass and existing map content changing appearance after a camera pan. A deterministic flat-forest scene reproduced those strips.

The base terrain pass draws complete PNGs, including their dirt undersides, then buries those undersides with neighboring ground tiles. The later occlusion pass replayed selected complete PNGs without repainting all their neighbors. Those buried walls were therefore painted over visible neighboring ground. Selection depended on visible objects, so viewport movement changed the artifact.

The occlusion replay now clips each terrain texture to its ground diamond. The initial terrain pass retains complete sprites, and actual exposed cliff geometry still draws outside that surface clip. This keeps map boundary foundations and elevation behavior while preventing buried PNG walls from covering other tiles.

Verification:

- Before the fix, adding one tree at scale 28/DPR 1 changed 910 flat-ground pixels outside the tree's bounds, with color deltas up to 96.
- After the fix, nine tree-isolation and 27 camera-translation checks pass across scales 28/33/66 and display densities 1/1.5/2. The forest includes eleven empty residential plots, matching the reported empty-zoning context. Checks compare tile interiors and exclude antialiased tile edges; rendering also leaves logical tiles unchanged.
- Existing geometry, packaging, browser controls/save import, native touch event, foreground cliff/agent occlusion, building growth and simulated city/traffic checks pass. JavaScript syntax and whitespace checks pass.
- Gradle built the updated APK successfully. APK signature, package identity, version metadata, ZIP integrity, packaged fix and runtime-file hash receipts pass.
- The APK keeps the previous preview application ID and signing certificate, and increments versionCode to 3 / versionName 0.2.1-isometric-preview. Save the current city before updating, then install over the previous preview without uninstalling.
- The original 0.2.0 APK remains available. No changes were made to simulation, city serialization, input controls or native MainActivity.

Updated APK: `/workspace/artifacts/MetroForge-Android-Isometric-0.2.1-debug.apk` (764,442 bytes).

SHA-256: `208977dfc94b4e9b6adbf721e81e2a1eef62435f52a5b0f1efd15a72525e54be`.

The fix is reproduced and verified in Chromium using the same renderer bundled into the APK. Verification on the user's Android device remains pending.
