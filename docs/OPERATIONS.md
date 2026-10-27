# Operations: diagnosing, reproducing and updating

## Reproduce any build
Everything is pinned: Godot 4.7.2-stable (SHA-256 checked by `scripts/install_godot.sh`), GUT 9.7.1 vendored, Kotlin/AGP/Gradle versions in `android/plugins/legend_ads`, GMA 24.4.0 / UMP 3.2.0, bundletool 1.18.1 (checksum), GitHub Actions pinned by commit SHA. `git checkout <tag>` + the commands in `BUILDING.md` rebuild the same artifacts; compare with the `.sha256` files published by CI (APK/AAB bytes can differ only by signing).

## Diagnose a failure
| Symptom | Where to look |
|---|---|
| CI red | The failing job's log; `test-reports` artifact (`gut.log`, `junit.xml`, `summary.json`, coverage); E2E artifacts contain per-journey logcat, in-app result files and screenshots (`e2e-android-api34/app/e2e/result_*.txt`) |
| Crash on a user's phone | Play Console → Android vitals (crashes/ANRs, native stack traces). Godot logs go to logcat with tag `godot`: `adb logcat -s godot:V` on a test device |
| "Progress lost" report | The game restores from `save.json.bak` automatically and shows a one-time message; damaged files are kept as `save.json.corrupt` in the app's files dir. On a test device: `adb shell run-as com.mariaalejandraboada.legendarrow ls files` (debug builds only) |
| Ads never show | Expected when consent is refused/unavailable, offline, or in a release without valid `ads_release.json` (by design, D-28). Debug builds log `ad_result` events locally |
| A level seems impossible | It cannot ship that way: every packaged level is validated, solved and checked for deadlocks in CI. Reproduce with `godot --headless -s res://tools/generate_level.gd` options recorded in the level file |

Logs are sanitised by design: no names, ages, identifiers, consent strings or tap streams are logged (`EventLog`, spec §17). There is no remote telemetry in v1; enabling any would need a privacy review for a child audience first.

## Update content
1. Change the plan in `tools/build_content.py` (grid, arrow count, difficulty) or a creature rig.
2. `GODOT=… python3 tools/build_content.py <creature>` regenerates the silhouette mask and level deterministically.
3. `scripts/verify_all.sh` (content tests validate, solve and deadlock-check all levels) and `scripts/desktop_e2e.sh`.
4. Ship through `docs/RELEASE.md`. Level ids must stay stable once released (saves reference them); add new ids instead of renaming.

## Save compatibility
Bump `SaveSchema.VERSION` only together with a migration step and a test in `tests/unit/test_save_repository.gd` (pattern: `test_migrates_v1_save`). Saves from a newer version are refused safely, not overwritten.

## Corrective release
See `docs/RELEASE.md` → Rollback / recovery (always a higher version code; halt staged rollout first).
