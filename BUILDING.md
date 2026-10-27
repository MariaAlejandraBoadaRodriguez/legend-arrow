# Building and testing Legend Arrow

## Pinned toolchain
| Tool | Version | Pinned by |
|---|---|---|
| Godot (editor/headless) | **4.7.2-stable** (`ed1daf0bf`) | `scripts/install_godot.sh` (download URL + SHA-256 `cadd3204…29e4`) |
| GUT test runner | **9.7.1** (`aeb5d4f3f7f0a6c9b5e178876d6c99b791fda605`) | vendored in `addons/gut/` (`VENDORED_VERSION.txt`) |
| Python | 3.x (stdlib only) | JUnit gate `scripts/check_junit.py` |
| GitHub Actions | checkout v7.0.1, cache v6.1.0, upload-artifact v7.0.2 | commit SHAs in `.github/workflows/ci.yml` |
| Godot export templates | 4.7.2-stable (Android only extracted) | `scripts/export_android.sh` |
| Android | JDK 17 (Temurin in CI), SDK from runner, debug keystore generated | `.github/workflows/ci.yml` job `android-debug-apk` |
| Typeface | Inter 4.1 (OFL) | `assets/fonts/` |

## Run all checks (Linux / CI)
```bash
scripts/verify_all.sh          # downloads pinned Godot on first run
GODOT=/path/to/godot scripts/verify_all.sh   # use an existing binary
```
Steps: headless import → compile every project script (`tools/check_scripts.gd`) → all GUT tests → JUnit gate.
Exit code is nonzero on any failure, parse error, empty discovery, pending test, assertion-free test, or a test file that reports nothing.
Reports: `build/reports/` (`junit.xml`, `summary.json`, `gut.log`, `import.log`, `check_scripts.log`).

## Run tests in the editor (any OS)
Open the project in Godot 4.7.2 → Project Settings → Plugins → enable **Gut** → GUT panel → Run All. Config: `.gutconfig.json`.

## Run a single test file
```bash
$GODOT --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gselect=test_puzzle_board
```

## Ads plugin (Kotlin)
```bash
scripts/build_ads_plugin.sh          # core tests + Android unit tests + lint + AAR -> addons/legend_ads/bin/
scripts/build_ads_plugin.sh --core   # SDK-free core tests only (works without Google Maven)
```
Gradle 8.11.1 wrapper, AGP 8.6.1, Kotlin 2.1.21, JDK 17, compile/target SDK 36, min SDK 24 (matching Godot 4.7.2's Android template). Deps: `play-services-ads:24.4.0`, `user-messaging-platform:3.2.0`, `org.godotengine:godot:4.7.2.stable` (compileOnly).

## Android debug APK
```bash
scripts/build_ads_plugin.sh
ANDROID_HOME=/path/to/sdk JAVA_HOME=/path/to/jdk17 scripts/export_android.sh
```
Gradle build export (`--install-android-build-template`), bundling the LegendAds AAR.
Downloads the 4.7.2 export templates once (Android files only), writes Godot editor settings for the SDK/JDK, creates a throwaway debug keystore in `build/`, exports `build/android/legend-arrow-debug.apk`, then runs `scripts/check_apk.sh` (package id, label, SDK levels, permissions incl. no advertising-ID/Privacy Sandbox, plugin registered and packaged, test app id in debug, arm64-v8a + x86_64 libs, 16 KB page size via `scripts/check_page_size.py`, signature) and writes the SHA-256.
Resolved by the template: **minSdk 24, targetSdk 36** (DECISIONS D-20). Release signing keys and real AdMob IDs are owner-supplied and never committed.

To install on the Android Studio emulator: drag the APK onto the emulator window, or `adb install -r build/android/legend-arrow-debug.apk`.

## Screenshots and creature renders (needs a display; Xvfb on Linux)
```bash
xvfb-run -a $GODOT --path . --rendering-driver opengl3 --audio-driver Dummy -s res://tools/capture_screens.gd -- phone en
xvfb-run -a $GODOT --path . --rendering-driver opengl3 --audio-driver Dummy -s res://tools/render_creature.gd -- forest_drake
```
Output: `build/shots/`. Curated sheets are committed under `docs/screenshots/`.

## Level authoring
```bash
$GODOT --headless --path . -s res://tools/generate_level.gd -- --creature forest_drake --slot 2 --arrows 8 --difficulty tutorial --max-len 5 --min-depth 3
```
Searches seeds 1..400 for the best silhouette coverage, validates, writes `data/levels/<creature>_<slot>.json` (deterministic).
