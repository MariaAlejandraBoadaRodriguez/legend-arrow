# QA report — Legend Arrow 0.1.0

Statuses: **PASS** = executed with assertions, evidence cited · **FAIL** · **BLOCKED** = cannot run without something outside this repo · **NOT RUN**. A workflow file is not evidence; every PASS below points at an executed run or log.

Final CI run: see `docs/PROGRESS.md` (updated with each push). Runs cited here: [40558523080](https://github.com/MariaAlejandraBoadaRodriguez/legend-arrow/actions/runs/40558523080) (M5), [40561120231](https://github.com/MariaAlejandraBoadaRodriguez/legend-arrow/actions/runs/40561120231) (M6 AAB + device script), [40563199020](https://github.com/MariaAlejandraBoadaRodriguez/legend-arrow/actions/runs/40563199020) (download size).

## Automated tests
| Area | Result | Count / detail | Evidence |
|---|---|---|---|
| GDScript import + compile all scripts | PASS | 0 errors | CI `godot-tests`, `check_scripts.log` |
| Unit + property + content + integration (GUT) | PASS | 191 tests, 0 failed / pending / assertion-free; empty discovery fails the gate | CI `test-reports` (`junit.xml`, `summary.json`) |
| 1,000 seeded generated boards + 300 random-vs-brute-force | PASS | in the 191 | `tests/property/test_generated_boards.gd` |
| 24 packaged levels: valid, solutions replay, no deadlocks, full campaign unlocks each creature once | PASS | in the 191 | `tests/content/test_packaged_content.gd` |
| Line coverage, puzzle/solver/progression (target 90%) | PASS | 94.8% (601/634 statements) | CI `test-reports/coverage/coverage.md`, method D-38 |
| Line coverage, save/reward (target 80%) | PASS | 95.1% (270/284) | same |
| Kotlin plugin core JUnit + Android unit tests + lint | PASS | 15 core tests, `lintRelease` clean | CI `android-ads-plugin`, `kotlin-reports` |
| Desktop E2E, phone 720×1280 | PASS | 8/8 journeys | CI `e2e-desktop-phone` |
| Desktop E2E, tablet 1200×1920 | PASS | 8/8 journeys | CI `e2e-desktop-tablet` |
| **Android emulator E2E** (API 34, Pixel 6 1080×2400, debug APK) | PASS | fresh_install, partial_a → force-stop → partial_b, blocked_undo, hint_ad, awakening_replay, settings_a → force-stop → settings_b, cold_start_smoke | CI `android-emulator-e2e`, artifact `e2e-android-api34` (logcat, 22 in-app PNGs, 9 screencaps, junit) |

## Build artifacts
| Artifact | Result | Detail |
|---|---|---|
| Debug APK | PASS | package, label, minSdk 24, targetSdk 36, LegendAds registered, Google **test** app id, no AD_ID/ACCESS_ADSERVICES/notification/location/camera/mic/contacts permissions, arm64-v8a + x86_64, 16 KB ELF + zip alignment, signature; `legend-arrow-debug.apk.sha256` |
| Release AAB (rehearsal: throwaway key, ads disabled) | PASS | bundletool 1.18.1 `validate`; versionCode 1 / 0.1.0; targetSdk 36; not debuggable; no AD_ID; arm64-v8a + armeabi-v7a + x86_64; no tests/tools/docs packaged; universal APK passes `check_apk.sh`; `legend-arrow-release.aab.sha256` |
| Download size per device (bundletool `get-size`) | PASS | arm64-v8a 30.7 MB, armeabi-v7a 32.1 MB, x86_64 32.1 MB (budget 120 MB) |
| Gameplay + awakening video | see final run | `legend_arrow_gameplay.mp4` recorded by `screenrecord` during `fresh_install` (artifact `e2e-android-api34`) |

## Performance and memory
| Check | Result | Detail |
|---|---|---|
| Physical low-tier phone (spec §14 budgets) | **BLOCKED** | Owner has no Android phone (D-18). Run `scripts/measure_device.sh <debug apk>` on a 3 GB phone |
| Emulator measurement (not device evidence) | measured | API 34 x86_64 emulator, SwiftShader **software** GPU at 1080×2400: cold start TotalTime 1147–1634 ms (5 runs); peak PSS 209 MB during the tutorial → 2 puzzles → awakening journey; frame time puzzle p50 98 ms / p95 141 ms, awakening p50 69 ms / p95 129 ms |
| 20 screen transitions, no node leak | PASS | `test_twenty_transitions_do_not_leak_nodes`; leak gate in `verify_all.sh` |

**Risk to note:** on the software-rendered emulator the game runs at ~10 fps. That says little about real GPUs, but it means the spec's frame budgets (puzzle p95 ≤ 16.7 ms) are **unverified** until a physical-device run. If a low-tier phone misses them, the first levers are the awakening SubViewport size and polygon counts of the larger rigs.

## Ads and privacy
| Check | Result | Detail |
|---|---|---|
| Rewarded flow: success, no fill, offline, fail-to-show, early dismiss, duplicate/late callbacks, restart redelivery | PASS | `test_ad_service` (22), `test_ads_flow` (7), E2E `hint_ad` on emulator (mock provider) |
| Consent refused/error/offline never blocks play; one request per launch | PASS | unit + integration tests |
| Child/unknown treatment, interstitials disabled | PASS | unit tests + Kotlin `AdSettings` tests + manifest checks |
| Release refuses test or missing IDs | PASS | `test_release_build_rejects_test_ids`, `test_release_config_validation`, `export_release.sh` guard |
| Live ads / real UMP form against Google | **NOT RUN** | by design CI never contacts ad services; manual check with Google test IDs on a test device before release (`docs/RELEASE.md` step 4) |

## Visual review
| Check | Result | Detail |
|---|---|---|
| Phone and tablet screenshots, no clipping | PASS (human-reviewed by the agent from CI/desktop captures) | E2E screenshots of every journey at 720×1280, 1200×1920 and 1080×2400 |
| Creature art final quality | **NOT RUN** | stylised procedural art; human art review recommended (D-33) |

## Known limitations
See `docs/RELEASE.md` → Known limitations.
