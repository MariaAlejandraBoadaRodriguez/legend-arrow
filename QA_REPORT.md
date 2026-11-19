# QA report — Legend Arrow 0.2.0 (versionCode 3)

Statuses:
- **PASS**: executed with assertions; the evidence is cited.
- **FAIL**
- **BLOCKED**: cannot run without something outside this repository (here, the owner's tablet).
- **NOT RUN**

A workflow file is not evidence; every PASS points at an executed run or log. The v0.1.0 report is in git history (`git show 7835016:QA_REPORT.md`).

**Final evidence run:** [CI PR run 44470278817](https://github.com/MariaAlejandraBoadaRodriguez/legend-arrow/actions/runs/44470278817) on `a0b8717`: **all jobs green**, including emulators API 26 / 34 / 36. Also green: [push run 44464519633](https://github.com/MariaAlejandraBoadaRodriguez/legend-arrow/actions/runs/44464519633) on `8a4b555`. API 26 emulator history (honest note): it passed on the default ~1.5 GB AVD in two runs, then failed twice. Run 44466657570: `fresh_install` results check. Run 44467837397: low-memory-killer storm, with the app dying together with the launcher and Play services. It now runs with 3 GB RAM, the spec's low-tier device, and passes. Results-check diagnostics and adb retries were added at the same time.

## 9.1 Content and rules
| Check | Result | Evidence |
|---|---|---|
| Roster = `docs/ART_PROMPTS.md` verbatim (10 worlds × 10 dragons, ids, names, order) | PASS | `tools/roster.py --check` in CI `godot-tests` |
| 100 puzzles, one per dragon, all certified (validator, solvable, legal first move, recorded solution replays) | PASS | `tests/content/test_packaged_content.gd`, inside the 236 tests |
| Difficulty rises world by world (depth and blocked-at-start strictly increase) | PASS | strict monotonic test (never relaxed); table below |
| English only (no Spanish locale, strings or store text) | PASS | `tools/check_english_only.py` (self-test + scan), CI |
| Every UI string key exists | PASS | `tools/check_strings.py`, CI |
| Save migration v1/v2 → v3 with a **real v0.1.1 save** | PASS | `tests/fixtures/save_v0_1_1.json`, migration tests |
| Timer: holds (pause, dialogs, ad, background), tick clamp, 10 h cap; stars 3/2/1 by par and hints; bests only improve | PASS | unit tests + E2E `replay_times`, `background_resume` |

### Difficulty and par by world (`tools/campaign_report.gd`)
| World | Arrows | Avg depth | Avg blocked at start | Par (s) | Seeds |
|---|---|---|---|---|---|
| 1 Mistwood | 6–12 | 4.4 | 5.5 | 20–28 | 110, 130, 138, 36, 73, 79, 89, 102, 122, 114 |
| 2 Moorland Hollows | 10–17 | 5.4 | 7.4 | 25–36 | 1, 73, 75, 124, 30, 113, 114, 17, 30, 81 |
| 3 Riverstone Gorge | 14–23 | 5.7 | 9.4 | 31–44 | 114, 26, 86, 133, 36, 86, 115, 122, 134, 117 |
| 4 Cloud Peaks | 18–28 | 6.5 | 10.9 | 38–54 | 104, 202, 221, 160, 63, 168, 224, 112, 189, 87 |
| 5 Frostfall Reach | 22–33 | 6.7 | 14.0 | 45–60 | 108, 14, 61, 2, 15, 9, 42, 51, 75, 14 |
| 6 Ashen Wastes | 25–39 | 6.8 | 15.0 | 48–68 | 211, 106, 9, 42, 34, 24, 71, 217, 6, 23 |
| 7 Tidewrack Coast | 29–44 | 7.2 | 19.0 | 53–75 | 233, 183, 48, 51, 53, 52, 128, 19, 33, 10 |
| 8 Stormcrown Heights | 33–49 | 7.3 | 21.9 | 60–84 | 17, 9, 51, 131, 39, 176, 184, 162, 224, 27 |
| 9 Obsidian Depths | 37–55 | 7.6 | 25.0 | 66–91 | 6, 207, 12, 82, 108, 152, 192, 11, 229, 40 |
| 10 Ancient Highlands | 41–60 | 7.9 | 29.3 | 71–99 | 11, 43, 6, 117, 223, 4, 220, 190, 39, 57 |

Par = 5 s + 1.4 s per arrow + 1.2 s per dependency level, rounded up to a whole second (D-46). 3★ = within par with no hints; 2★ = within 2× par; 1★ = completed.

## 9.2 Automated tests
| Area | Result | Detail |
|---|---|---|
| Import + compile all scripts | PASS | 92 scripts, 0 errors (`check_scripts`) |
| GUT unit, property, content and integration tests | PASS | **236 / 236**; 0 failed, pending or assertion-free; empty discovery fails the gate |
| Line coverage: puzzle, solver, progression, timer, stars (target 90%) | PASS | 94.3% |
| Line coverage: save and reward (target 80%) | PASS | 95.0% |
| Kotlin ads plugin: JUnit + lint | PASS | CI `android-ads-plugin` |
| Art import checks | PASS | `tools/art/test_import_art.py`, 10 tests, CI `store-assets` |
| Desktop E2E, phone 720×1280 and tablet 1200×1920 | PASS | 11/11 journeys each (incl. `replay_times`, `world_unlock`, `memory_transitions`); CI artifacts `e2e-desktop-phone`, `e2e-desktop-tablet`, gameplay video |

## 9.3 Android emulator E2E (journeys 1–9 of the prompt, and more)
Journeys:
- `fresh_install`
- `partial_a` → force-stop → `partial_b`
- `blocked_undo`
- `hint_ad`
- `awakening_replay`
- `settings_a` → `settings_b`
- `replay_times` (slow → fast → slow: bests only improve)
- `background_resume` (Home key, ~8 s away)
- `rotate` (forced landscape)
- `world_unlock`
- `memory_transitions`
- the first-launch smoke check with the real UMP + Google Mobile Ads start-up (Google test IDs, nothing clicked)

| Emulator | Result | Evidence |
|---|---|---|
| API 26 (Android 8.0) / P1 720×1280 @320, 3 GB RAM | **OPEN (intermittent)**: 13/13 + smoke in runs 44470278817 and 44472596603. But in 44472596603 the measurement run's `fresh_install`, right after `pm clear`, showed 3 stars on the results screen while the save file on disk had **no record** for the level ("stars shown 3, saved { }"). Run 44466657570 failed at the same step. Never seen on API 34/36 or desktop. Diagnostics added (save source, files, last write result); investigating as a possible save issue on Android 8 | run 44464519633 job 135361615436 (also run 44462316343), artifact `e2e-android-api26-P1` |
| API 34 (Android 14) / P3 Pixel 6 1080×2400, punch-hole | **PASS**: 13/13 journeys + smoke | run 44464519633 job 135361615190, artifact `e2e-android-api34-P3` |
| API 36 (Android 16) / P6 1600×2560 @320 tablet | **PASS**: 13/13 journeys + smoke | run 44464519633 job 135361615219, artifact `e2e-android-api36-P6`. Earlier fail (run 44462316343): `background_resume` read the clock when it *asked* for the Home key, which CI presses up to 2 s later. It now reads the clock at the app's own pause and resume and requires ≤ 300 ms drift across ≥ 5 s away (stricter than the old 2.5 s). |

Harness issues CI found and fixed in this milestone:
- `logcat -c` fails on the API 26 image, which ended the run. Logs are now read from a device timestamp.
- The emulator save carries over between journeys, so a launch can (correctly) replay an unwatched awakening. Journeys now watch it out first (`reach_home`).

## 9.4 Screens on every profile
| Check | Result | Evidence |
|---|---|---|
| 19 screens × P1–P7, with simulated status bar, cutout or notch, and nav or gesture bar | PASS (captured and reviewed) | `docs/qa/screens/`, `docs/qa/screen_matrix.png`, CI artifact **screen-matrix** (job 135352925942) |
| Review: nothing under system bars, no clipping or overlap, Larger text, tablets, tall phones | PASS after one fix | `docs/qa/VISUAL_QA.md`. Fixed: with Larger text, the level-select title ran into the "Worlds" link (`Ui.top_bar`). |
| Touch targets on the largest boards | PASS (by design) | Cells ≥ 40 dp with a 48 dp touch band; big boards open zoomed with pan on phones (D-48) |

## 9.5 Performance, memory and size
Emulator numbers are **indicative only**: x86_64 emulators with the SwiftShader *software* GPU, not device evidence.

| Check | Result | Detail |
|---|---|---|
| Only the current dragon's full image in memory; thumbnails cached; freed on leaving detail | PASS | unit test (detail frees its texture) + `memory_transitions` |
| Memory settles over 20 level-list / dragon-detail / bestiary transitions (≤ 10% over warmed baseline, no node growth) | PASS | `memory_transitions` on desktop (55.1 → 55.1 MB, nodes flat), API 26/P1 and API 34/P3 |
| Cold start to first frame (budget 5 s) | indicative PASS | API 26: 581–701 ms; API 34: 891–1102 ms; API 36 tablet: 1066–1205 ms (`am start` TotalTime) |
| Peak PSS (budget 300 MB puzzle / 400 MB awakening) | indicative | API 26: 149 MB; API 34: 185 MB; API 36 tablet: 192 MB |
| Frame time p95 (budgets 16.7 ms puzzle, 33.3 ms awakening) | **BLOCKED** (device) | Software GPU: API 26 puzzle 66.9 / awakening 36.0 ms; API 34 123.5 / 64.9 ms. These say little about a real GPU; needs the Lenovo run. |
| arm64 download ≤ 120 MB with all 100 images | PASS | bundletool `get-size`: arm64-v8a **48.8 MB** (with ads), 45.6 MB (without ads); armeabi-v7a 50.2 / 47.0 MB; x86_64 50.2 / 47.0 MB |
| Debug APK (all test ABIs incl. x86_64) | info | 177 MB; SHA-256 `548c88f2…07389b3` |

## 9.6 Physical device (owner's Lenovo tablet)
| Check | Result |
|---|---|
| Install via Google Drive, manual checklist (3 worlds, timer and stars, results, photoreal awakening, bestiary, pause/background/resume, sound, 15-minute session, battery/heat) | **BLOCKED**: waiting for the owner (`docs/DEVICE_TEST.md`) |
| `scripts/measure_device.sh` on the tablet (frame time, memory, start-up) | **BLOCKED**: optional USB run, `docs/DEVICE_TEST.md` Part B |

## 9.7 Release build checks
Both AAB rehearsals: with ads (throwaway key, test ads config) and without ads (the `release.yml` "without-ads" path). Results from `aab_report.txt` (run 44462316343 job 135352925998; confirmed in run 44464519633 job 135359988799).

| Check | With ads | Without ads |
|---|---|---|
| bundletool 1.18.1 `validate` | PASS | PASS |
| versionCode 3 / versionName 0.2.0, package `com.mariaalejandraboada.legendarrow` | PASS | PASS |
| targetSdk 36 (Play needs ≥ 35) | PASS | PASS |
| arm64-v8a + armeabi-v7a native libs | PASS | PASS |
| 16 KB page size (ELF segments + zip offsets) on the universal APK built from the bundle | PASS | PASS |
| Not debuggable | PASS | PASS |
| No AD_ID / Privacy Sandbox permissions | PASS | PASS |
| **Merged-manifest permissions within the v0.1 baseline** (new check, `tools/permissions_allowlist.txt`) | PASS: INTERNET, ACCESS_NETWORK_STATE, VIBRATE, WAKE_LOCK, FOREGROUND_SERVICE | PASS: INTERNET, ACCESS_NETWORK_STATE, VIBRATE |
| No AdMob app id / ads code packaged | n/a | PASS |
| Release refuses Google test ad IDs | PASS (unit tests + `export_release.sh` guard for real releases; the rehearsal uses test IDs by design) | n/a |
| No keystores, keys or `ads_release.json` committed | PASS (`check_no_secrets`, CI `godot-tests`) | |
| Signing-certificate SHA-256 printed (and checked) | PASS: rehearsal key `28:C9:AD:F8:…:F2:AC:1B` | PASS: `22:05:70:67:…:AC:42:67:39` (throwaway keys; your upload key prints its own) |
| AAB checksums | `28db1588…be055432` (ads), `3a7309e9…72f75416` (no ads), run 44464519633; rehearsal keys only, **not for upload** | |

**Privacy and Data Safety:** v0.2 adds one thing, best times and star ratings. They stay in the local save as personal records, with no leaderboard, account or upload. `docs/privacy.html`, `docs/PRIVACY_POLICY.md` and `docs/DATA_SAFETY.md` are updated. **Play Console: no Data Safety answer changes**, since data kept only on the device is not "collected". Update the policy URL's page with the new `docs/privacy.html` (effective date and the sentence on best times).

## 9.8 Store graphics
| Check | Result | Evidence |
|---|---|---|
| 20 English files named by Play Console field: icon 512, feature 1024×500, 8 phone 1080×1920, 5 × 7" 1200×2133, 5 × 10" 1440×2560 | PASS | `tools/store_assets.py`: 20 expected, 20 present; sizes, format, no alpha, limits. CI artifact **play-store-assets** |

## Known limitations
- **Open:** intermittent screen/save mismatch on the API 26 emulator right after a data clear (see 9.3). It is not explained yet, and it blocks "Ready for Play upload" until it is understood.
- Frame-time budgets are unverified on real hardware (software-GPU emulators only) until the Lenovo run.
- Puzzle silhouettes resemble their dragon only loosely; accepted for v0.2 (D-50, `docs/ART_STATUS.md`).
- The live UMP consent form and live ads have never been shown or clicked in CI (test IDs, nothing clicked). Check manually before a with-ads release.
