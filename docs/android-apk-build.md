# Android APK delivery

The Android follow-up builds the real WebView app with all isometric runtime resources bundled locally.

- Gradle 8.10.2, Android Gradle Plugin 8.7.3, compile/target SDK 35, minSdk 26, Temurin full JDK 17.
- Build: `python tools/package_runtime.py --android-dir app/src/main/assets`, then `gradle :app:assembleDebug --no-daemon` with the full JDK and Android SDK configured.
- Build succeeded, 32 Gradle tasks executed. Existing MainActivity deprecation notes are nonfatal.
- Debug package: `com.narmanb.metroforge.isometricpreview`; launcher label: MetroForge Isometric; versionCode 2; versionName 0.2.0-isometric-preview. This preview installs alongside the original app. Release package identity remains unchanged.
- APK signing verification passes using APK Signature Scheme v2, with a local Android debug certificate.
- aapt confirms SDK metadata and launch activity `com.narmanb.metroforge.MainActivity`.
- APK CRC, native DEX, isometric renderer initialization, all runtime-file hash receipts, five source atlases and four CC0 license hash receipts pass.
- Output: `/workspace/artifacts/MetroForge-Android-Isometric-debug.apk` (764,298 bytes).
- SHA-256: `dd6ede92682b29ca55273cc00e72ccfb826e237d6efd04d52b6f2768548dd637`.

Device launch, touch behavior in actual WebView, Android persistence/import/export and memory/performance remain unverified. Existing browser and touch regressions validate the embedded game's behavior in Chromium; these do not replace on-device checks. No hosted website was created.
