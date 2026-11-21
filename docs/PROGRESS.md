# Progress

_Last updated: 2026-11-21 (0.2.1 in progress: save hardening, storage-full message, manifest, release cache)_

## 0.2.1 — in progress (versionCode 4)
Owner scope (2026-11-21), nothing else: (1) save hardening from `save-hardening-experimental` (verified write, retry now + in the background, real full-storage CI check `scripts/enospc_check.sh`); (2) non-blocking "Storage full. Free up some space to save your progress." message (`StorageStatus`, `StorageBanner`, 10 MB threshold, D-52) with tests and screen 20 in the matrix; (3) `android.hardware.screen.portrait` not required + release check for required features (D-53); (4) release workflow Gradle cache fallback (D-54); (5) promo video files (docs only).
- Local: 257/257 tests, coverage PASS, `enospc_check` PASS, screen matrix 20 x 7.
- PR #9 CI: all 10 jobs green ([push 44932357054](https://github.com/MariaAlejandraBoadaRodriguez/legend-arrow/actions/runs/44932357054), [PR 44932382693](https://github.com/MariaAlejandraBoadaRodriguez/legend-arrow/actions/runs/44932382693) on `8004176`); `enospc_check` PASS in CI, so RELEASE_CHECKLIST item 18 is PASS; device-feature check PASS (portrait not required).
- Next: 3 consecutive all-green runs on the PR head; owner merges and runs `release.yml` (version_code 4).

## v0.2 — current status
Owner prompt: `docs/prompts/03_V0_2.md` (decisions D-41…D-43). Milestones A–F in `docs/ROADMAP.md`. Branch `claude/upbeat-turing-4w8wzu`.

### Milestone F — gates 9.1–9.8: DONE (device checks BLOCKED on the owner)
Full results: `QA_REPORT.md`, `RELEASE_CHECKLIST.md`. Evidence run [44462316343](https://github.com/MariaAlejandraBoadaRodriguez/legend-arrow/actions/runs/44462316343) @ `8ebd53f`: everything green except emulator API 36/P6.
- Emulator matrix API 26/P1, 34/P3, 36/P6 with 13 journeys + first-launch smoke. API 26 and 34: **PASS 13/13**. P6: 12/13. `background_resume` read the clock when it asked for the Home key (CI presses it up to 2 s later); it now reads the clock at the app's pause/resume notifications (≤ 300 ms drift across ≥ 5 s away). Earlier harness fixes: logcat read from a device timestamp (API 26 cannot `logcat -c`), `reach_home` watches out a launch-time awakening.
- Screen matrix: 19 screens × P1–P7 (`docs/qa/`, CI artifact `screen-matrix`); fixed the Larger-text header overlap.
- Memory journey `memory_transitions` (desktop + emulators): 20 transitions, memory flat.
- Release checks: permission audit vs the v0.1 baseline (PASS); certificate SHA-256 print fixed (printed nothing before).
- Store graphics regenerated (20 files, photoreal); privacy policy and Data Safety note updated for 0.2.0 (no Play Console Data Safety change).
- `docs/DEVICE_TEST.md` for the Lenovo tablet; physical checks BLOCKED until the owner sends results.
- **Final run:** [CI push run 44464519633](https://github.com/MariaAlejandraBoadaRodriguez/legend-arrow/actions/runs/44464519633) on `8a4b555`: all 10 jobs green; emulators API 26/34/36 13/13 each; certificate SHA-256 printed and checked.
- API 26 emulator: two later failures on the ~1.5 GB default AVD (results check; low-memory-killer storm). It now runs with 3 GB (spec low tier), plus results diagnostics and adb retries; green in [run 44470278817](https://github.com/MariaAlejandraBoadaRodriguez/legend-arrow/actions/runs/44470278817) on `a0b8717`.
- API 26 save mismatch, owner verdict: **0.2.0 ships to CLOSED TESTING with this known limitation; the fix on save-hardening-experimental must ship in 0.2.1 BEFORE any production release.** Known limitation: on a completely full device the shipped save can report success while writing a 0-byte save (CI run 44577702952). Earlier: closed as a test-environment issue. The original save code passed 240/240 API 26 kill iterations, 150/150 on desktop and the owner's tablet test (all 15 items, incl. force-close/reopen). See `docs/qa/SAVE_INVESTIGATION.md`. Experimental save hardening is parked on branch `save-hardening-experimental` (possible v0.2.x).
- API 26 emulator /data fix (CI only, no game code): 10 GB data partition (`disk-size: 10G`, `-partition-size 10240`), `-wipe-data` on start, and `scripts/device_space.sh` prints `df -h /data` before/after the journeys and the repeat step, failing early below 1 GB free. Owner asked for 3 consecutive green runs of the API 26 job.
- API 36 tablet tutorial failure (run 44595886933): root cause was a game bug, quick taps dropped as long presses across slow frames (D-51). Fixed in `BoardView.held_seconds`, regression tests added; harness checks every board tap and logs TAPSTATS.
- **Owner tablet test: PASS** (all 15 `docs/DEVICE_TEST.md` items). **0.2.0: closed testing only**; production is blocked until 0.2.1 ships the save fix (`QA_REPORT.md`, `RELEASE_CHECKLIST.md`).
- **Next (owner):** Lenovo tablet run (`docs/DEVICE_TEST.md`), then the upload steps in `RELEASE_CHECKLIST.md`.

### Milestone D — DONE (CI pending at the time of writing); milestone E folded in
All 100 owner images were already in `assets/creatures/raw/`, so the final art integration (E) ran here; E now only means re-running `scripts/import_art.sh` + `tools/build_campaign.py` when an image is replaced.
- Import pipeline (D-49): `scripts/import_art.sh` → `tools/art/import_art.py`, pinned `tools/art/requirements.txt` (rembg 2.0.67, model isnet-general-use, SHA-256 checked). **100/100 imported, 0 rejected**, full images 11.4 MB WebP (+ thumbnails, masks, silhouettes); `build/art/report.json`, `docs/ART_STATUS.md`. Unit tests for the checks (`tools/art/test_import_art.py`, 10 tests, synthetic images) run in CI.
- Levels regenerated from the rembg masks and re-certified (all 100), then deepening passes so the difficulty curve still rises world by world.
- `PhotoRig`: photoreal awakening (arrows gather into the mask silhouette → image through mist → white rim light → breath; camera push + parallax; ≈ 5 s; reduced motion = dissolve), detail idle loop; grids use still thumbnails; leaving the detail screen frees the full image (test). Awakening backdrop trails off for photoreal dragons.
- `docs/store/art_review_sheet.png` (cut-out on dark | light + its puzzle silhouette, all 100).
- Fixes found here: `tools/roster.py --strings` had deleted the UI string `CREATURE_AWAKENED` (shown raw on the awakening screen) → it now only replaces rows it owns, and `tools/check_strings.py` (verify_all + CI) fails on any missing UI string key; proven on the broken table.
- Icon tweak (owner, D-44): Play icon head +15%, adaptive +6.2% (safe-zone limit), darker radial vignette; `docs/store/icon_final_preview.png`.

#### Difficulty curve after the art masks
| World | Avg depth | Avg blocked at start |
|---|---|---|
| 1 | 4.4 | 5.5 |
| 2 | 5.4 | 7.4 |
| 3 | 5.7 | 9.4 |
| 4 | 6.5 | 10.9 |
| 5 | 6.7 | 14.0 |
| 6 | 6.8 | 15.0 |
| 7 | 7.2 | 19.0 |
| 8 | 7.3 | 21.9 |
| 9 | 7.6 | 25.0 |
| 10 | 7.9 | 29.3 |
(arrow counts unchanged: world 1 6–12 … world 10 41–60.)

#### Verification (milestone D, local)
| Check | Result | Evidence |
|---|---|---|
| `scripts/verify_all.sh` | **PASS**: 236 / 236; English-only, roster, string-key checks pass | `build/reports/junit.xml` |
| Art import | **PASS**: 100/100, 0 rejected, 11.4 MB | `build/art/report.json`, `docs/ART_STATUS.md` |
| Import-check unit tests | **PASS** 10/10 | `python3 -m unittest tools/art/test_import_art.py` |
| Desktop E2E phone | **PASS** 8/8 | `scripts/desktop_e2e.sh` |
| Art review (cut-outs) | inspected: clean, consistent, none rejected | `docs/store/art_review_sheet.png` |
| Puzzle silhouettes resemble their dragon | **open (owner decision)**: loose resemblance (see ART_STATUS review notes) | same sheet |
| Milestone C CI | **PASS** (all jobs, incl. emulator + desktop E2E) | [push run 44449056026](https://github.com/MariaAlejandraBoadaRodriguez/legend-arrow/actions/runs/44449056026), [PR run 44449062351](https://github.com/MariaAlejandraBoadaRodriguez/legend-arrow/actions/runs/44449062351) |
| CI for this commit | **NOT RUN yet** at time of writing | — |

#### Next
1. Milestone F: quality gates 9.1–9.8 (emulators API 26/34/36 with P1/P3/P6, screen matrix P1–P7 + VISUAL_QA.md, performance/memory/size, DEVICE_TEST.md for the Lenovo tablet, release AAB rehearsals, store graphics 0.2.0, QA_REPORT/RELEASE_CHECKLIST).

Next command: `scripts/verify_all.sh`

### Milestone C — DONE (CI green: runs 44449056026 / 44449062351)
- `data/roster.json` from `docs/ART_PROMPTS.md` (`tools/roster.py`; `--check` in CI and verify_all; `--strings` writes the 10 world and 100 dragon names + lore).
- 100 certified levels from the dragons' real silhouettes (`tools/build_campaign.py` → `tools/generate_campaign.gd`, D-47); `data/campaign.json` schema 2 (worlds + dragons, level id = dragon id), `data/creatures/<id>.json`, `assets/creatures/silhouettes/<id>.png`. Deepening passes (`DEEPEN=1`) on the shallowest later-world boards so average dependency depth never falls.
- Worlds open in order; dragons one by one inside a world; one level awakens its dragon. Screens: `world_select` (atmosphere thumbnails; locked worlds show their dragons' silhouettes and what opens them), per-world `level_select` (silhouette tiles, stars, best time, Worlds button), bestiary grouped by world with still thumbnails, `SilhouetteRig` interim art (7 v0.1 rigs kept), per-world sound motifs.
- Multi-screen (D-48): centred ≤ 900 px column, board cells ≥ 40 dp (≥ 48 dp hit band) with zoom/pan and `BoardView.reveal()`, Larger text ×1.3, recovery message now shown before a pending awakening (bug found by the new tests).
- `tools/capture_matrix.gd` (profile + density + text scale) for the §9.4 screen matrix.

#### Difficulty curve (from `test_difficulty_curve_rises_world_by_world`)
| World | Arrows avg / min / max | Depth avg / min / max | Free at start avg (share) | Blocked at start avg |
|---|---|---|---|---|
| 1 Mistwood | 9.0 / 6 / 12 | 4.7 / 4 / 6 | 3.3 (37%) | 5.7 |
| 2 Moorland Hollows | 13.7 / 10 / 17 | 5.1 / 4 / 6 | 5.8 (42%) | 7.9 |
| 3 Riverstone Gorge | 18.5 / 14 / 23 | 5.9 / 5 / 7 | 9.6 (52%) | 8.9 |
| 4 Cloud Peaks | 22.9 / 18 / 28 | 6.2 / 5 / 8 | 11.6 (51%) | 11.3 |
| 5 Frostfall Reach | 27.4 / 22 / 33 | 6.7 / 5 / 8 | 12.8 (47%) | 14.6 |
| 6 Ashen Wastes | 32.0 / 25 / 39 | 6.7 / 6 / 8 | 15.1 (47%) | 16.9 |
| 7 Tidewrack Coast | 36.6 / 29 / 44 | 7.2 / 7 / 8 | 18.5 (51%) | 18.1 |
| 8 Stormcrown Heights | 41.3 / 33 / 49 | 7.6 / 7 / 9 | 18.8 (46%) | 22.5 |
| 9 Obsidian Depths | 46.0 / 37 / 55 | 7.6 / 7 / 9 | 21.6 (47%) | 24.4 |
| 10 Ancient Highlands | 50.5 / 41 / 60 | 7.6 / 7 / 8 | 22.8 (45%) | 27.7 |

#### Verification (milestone C, local)
| Check | Result | Evidence |
|---|---|---|
| `scripts/verify_all.sh` | **PASS**: 234 / 234, 0 failed / skipped; English-only + roster checks pass | `build/reports/junit.xml` |
| Certification of all 100 levels (validator, exact solver, legal first move, solution replays to empty) + full offline playthrough (each dragon once, worlds in order) | **PASS** | `test_packaged_content.gd` |
| Coverage | **PASS**: puzzle/solver/progression/timer/stars 94.3% (≥ 90); save/reward 95.0% (≥ 80) | `tools/coverage.py` |
| Desktop E2E phone 720×1280 | **PASS** 8/8 journeys | `scripts/desktop_e2e.sh` |
| Screen check P1, P3, P6, P7 (12 screens each, Xvfb) | Inspected; fixed: board zoom on unsized layout, bestiary names at ×1.3 | `build/matrix/` (local) |
| Safe-area cutouts, emulator profiles | **NOT RUN**: milestone F (emulators) | — |
| CI | **NOT RUN yet** at time of writing | — |

Known trade-off for owner review: on phones, expert boards (up to 18×24) open zoomed at 40 dp per cell and need panning; tablets show more of the board.

#### Next
1. Milestone D: art import pipeline (rembg cut-outs, thumbnails, masks, WebP), photoreal awakening/bestiary, `docs/ART_STATUS.md`, art review sheet, re-certify levels from the new masks.

Next command: `scripts/verify_all.sh`

### Milestone B — DONE
- Final icon = owner artwork (`assets/icon/icon_source.png`, D-44): `tools/make_icons.py` → 512 store icon, 192 legacy, adaptive background (her own gray vignette), cut-out foreground with horns/eye/snout/chin inside the 66 dp safe circle, monochrome; `--check` in CI. Preview `docs/store/icon_final_preview.png` (readable at 48 dp on light and dark).
- Speed timer `scripts/core/speed_timer.gd`, stars/par `scripts/core/star_rating.gd` (D-45); timer in `PuzzleSession` (saved with the board), discreet `TimerLabel` on the puzzle, holds for dialogs/ads/background.
- Results screen (`scripts/screens/level_complete.gd`): time, par, New record / First clear / personal best, `StarRow` reveal (fade with reduced motion), Retry / Next / Level selection; shown after every puzzle, Next opens an earned awakening.
- `Progression.record_result` / `best_time_ms` / `best_stars` / `total_stars`; level select shows stars + best time per level and total stars.
- Save schema 3 + v0.1 migration (D-46) with a real v0.1.1 fixture (`tests/fixtures/save_v0_1_1.json`).
- versionCode 3 / 0.2.0 in both presets; CI rehearsals and `release.yml` expect 3.
- Tests: +34 (timer, stars, records, session timer persistence, migration on the fixture, screen-driven timer holds / kill-relaunch / faster-slower replays / star reveal, par table for every level). E2E journeys updated (results → Next → awakening; timer saved and restored across kill; hints cap stars at 2).

#### Verification (milestone B, local)
| Check | Result | Evidence |
|---|---|---|
| `scripts/verify_all.sh` | **PASS**: 228 discovered / 228 passed / 0 failed / 0 skipped; English-only + self-test pass | `build/reports/junit.xml` |
| Coverage | **PASS**: puzzle/solver/progression/timer/stars 94.9% (≥ 90); save/reward 95.0% (≥ 80) | `tools/coverage.py build/reports/coverage` |
| Desktop E2E (Xvfb, 720×1280) | **PASS**: 8/8 journeys | `scripts/desktop_e2e.sh` (local run) |
| `tools/make_icons.py --check`, `tools/store_assets.py check` | **PASS** | local |
| Par table (24 v0.1 levels) | printed by `test_par_times_and_three_stars_reachable_for_every_level` (gut.log); every level's human replay earns 3★ | `build/reports/gut.log` |
| CI | **NOT RUN yet** at time of writing | — |
| 100-level difficulty/par tables, world unlocks | **NOT RUN**: milestone C | — |

#### Next
1. Milestone C: 10 worlds × 10 dragons = 100 certified puzzles (level id = dragon id), world/level select, world N+1 unlocks after world N, multi-screen layout P1–P7.

Next command: `scripts/verify_all.sh`

### Milestone A — DONE (owner then supplied her own icon, D-44)
- English only: `locales/strings.csv` is `keys,en`; Spanish translation, language setting/picker and `LANGUAGE_*` strings removed; locale fixed to `en` (device language ignored); obsolete `language` key dropped from old saves on load; Spanish tests replaced (settings persist + UI stays English; device locale `es` forced back to `en`); E2E settings journey now changes sound + reduced motion (touching the music slider) instead of language.
- `tools/check_english_only.py` (self-test with 7 planted cases + repo scan: locale columns, translation files, `values-es`, `"es"` locale literals, Spanish characters/words in shipped code, data, scenes, Android plugin, store files and file names, privacy page) runs in `verify_all.sh` step 0 and in the CI `godot-tests` job.
- Store text English: Play Console files renamed to English field names, store README translated, `GUIA_INICIO.md` → `GETTING_STARTED.md`, Spanish M2 screenshots deleted, Spanish half of `docs/privacy.html` removed.
- Icon concepts v2: `tools/icon_concepts_v2.py` → `docs/store/icon_concepts_v2.png` (A Ember Eye, B Arrow Wyvern, C Crowned Head, D Dragon Arrow).
- Fix: the owner's 176 MB of raw art was imported and packed into the APK (main CI run 44413626725 failed, APK artifact 183 MB). `assets/creatures/raw/.gdignore` + preset `exclude_filter` (D-43).
- Roster check: `docs/ART_PROMPTS.md` has 100 unique ids; `assets/creatures/raw/` has exactly those 100 files, all 1024×1536.

### Verification (milestone A)
| Check | Result | Evidence |
|---|---|---|
| Local `scripts/verify_all.sh` @ `9e59354` | **PASS**: 194 discovered / 194 passed / 0 failed / 0 skipped; English-only check + self-test (7 planted cases) pass | `build/reports/junit.xml`, `english_only.log` |
| CI push run @ `6fc8c98`, all 7 jobs | **PASS**: tests + English-only + coverage, Kotlin plugin, Play assets, debug APK + both AAB rehearsals, desktop E2E phone + tablet, Android emulator E2E API 34 | [run 44423031551](https://github.com/MariaAlejandraBoadaRodriguez/legend-arrow/actions/runs/44423031551) |
| CI PR runs, desktop E2E jobs | **FAIL (infrastructure)**: GitHub runner could not install xvfb/mesa/ffmpeg from the Ubuntu mirror; no journey started. Same code passed on the push run above. Re-run once each | runs [44418671778](https://github.com/MariaAlejandraBoadaRodriguez/legend-arrow/actions/runs/44418671778), [44423038351](https://github.com/MariaAlejandraBoadaRodriguez/legend-arrow/actions/runs/44423038351); PR comment |
| Gate 9.1 items for levels/timer/stars/100 puzzles | **NOT RUN**: built in milestones B–C | — |
| Physical tablet | **BLOCKED** (owner) | — |

### Next
1. Owner: choose icon **A, B, C or D** from `docs/store/icon_concepts_v2.png`.
2. Milestone B: chosen icon → `tools/make_icons.py` (adaptive fg/bg/monochrome + 512 store icon), timer, stars, results screen, save schema v3 + v0.1 fixture migration (old creature ids → roster ids).

Next command: `scripts/verify_all.sh`

### Blockers
- Icon choice (owner).
- Local Android builds still blocked by the network policy (`dl.google.com`); Android checks run in CI only.

---

## v0.1 history

## Where things are
- `main` holds M0–M2 (PR #1 merged). M3–M6 are on `claude/new-session-8a6cy7` in PR [#2](https://github.com/MariaAlejandraBoadaRodriguez/legend-arrow/pull/2) → `main`, CI green; merge is the owner's call.

## Done
- **M0** — roadmap, decisions, Godot 4.7.2 skeleton, vendored GUT 9.7.1, `verify_all.sh` + JUnit gate, SHA-pinned CI.
- **M1** — pure puzzle model, swept-body rules, graph solver, validator, generator; 1,000 seeded + 300 random-vs-brute-force boards.
- **M2** — vertical slice: tutorial, Forest Drake 2 levels + awakening, bestiary, settings, EN/ES, atomic saves, debug APK.
- **M3** — ads and consent:
  - GDScript: `AdService` rewarded state machine (grant only from earned callback, once per presentation id, persisted; duplicates/late/unknown harmless; retry cooldown; audio muted during full-screen), `ConsentService` (one UMP request per launch, refusal never blocks play, privacy-options entry), `AdConfig` (test IDs in debug/CI; release rejects test/missing IDs), `InterstitialPolicy` + `RemoteConfig` (only reduce pressure), mock provider, Android provider adapter; hint sheet Watch ad / Loading / No ad available + rate-limited Try again.
  - Kotlin plugin `android/plugins/legend_ads` (UMP 3.2.0 + GMA 24.4.0; child/unknown → child-directed, under-age, G), export plugin `addons/legend_ads` (AAR, deps, test app id, strips AD_ID + Privacy Sandbox permissions), Gradle-build APK export.
  - `verify_all.sh` now fails on objects leaked at exit.
  - Docs: `docs/ADS_AND_PRIVACY.md`, DECISIONS D-27…D-32.
- **M4** — full content:
  - 12 creatures in 3 realms (Mistwood: forest drake, moon owl, antler fox, basilisk · Cloud Peaks: wyvern, arctic drake, griffin, cloud serpent · Ancient Highlands: stone wyrm, unicorn, phoenix, ancient dragon), each a layered procedural rig with its own signature awakening (D-33); EN/ES names + lore.
  - 24 validated levels built from each creature's rendered silhouette (`tools/build_content.py`, D-34): 7 → 36 arrows, grids 8×10 → 17×19, easy/medium/hard.
  - Board pinch/wheel zoom + pan for large boards (D-35).
  - Original synthesised audio (`tools/make_audio.py`) + `AudioDirector` (Music/SFX/Creature buses, voice pool, retrigger limit, mute on background/ad) hooked into puzzle and awakening (D-36).
  - New tests: 12 creatures/24 levels, strings in both languages, random-play no-deadlock on large boards, difficulty curve, full-campaign playthrough unlocks each creature once, every rig awakens/skips, audio director.
- **M5** — E2E and coverage:
  - `DeviceE2E` runs the 6 brief journeys (+ kill/relaunch halves) **inside the real app**, screen touches injected at window pixels, mock ads only, debug builds only (D-37).
  - `scripts/android_e2e.sh` on a CI **Android 14 emulator** (Pixel 6, 1080×2400): `am start` / `am force-stop`, logcat, in-app PNGs, system `screencap`, JUnit; `scripts/desktop_e2e.sh` at phone 720×1280 and tablet 1200×1920.
  - `tools/coverage.py` line coverage enforced in CI (D-38); `docs/REQUIREMENTS_MATRIX.md`.
  - Fixed during M5: tap coordinates ignored the canvas stretch transform (would miss on any scaled screen); desktop runner leaked orphan processes.
- **M6** — release preparation:
  - Release AAB pipeline `scripts/export_release.sh` (real release needs owner upload key + `ads_release.json`; CI `--rehearsal` with a throwaway key and ads disabled), bundletool 1.18.1 validation, manifest/ABI/16 KB checks, per-device download size, SHA-256.
  - `scripts/measure_device.sh` (cold start, PSS, in-game frame-time p50/p95, gfxinfo, thermal) — exercised on the CI emulator.
  - Gameplay + awakening video `docs/media/legend_arrow_gameplay.mp4` (`scripts/record_video.sh`, Godot Movie Maker; CI artifact).
  - Docs: `RELEASE_CHECKLIST.md`, `QA_REPORT.md`, `docs/RELEASE.md`, `docs/OPERATIONS.md`, `docs/PRIVACY_POLICY.md` (draft), `docs/DATA_SAFETY.md`, `docs/ART_AND_ANIMATION.md`, README architecture diagram.
  - Fixed: bundletool CRLF output broke the size check (reproduced from CI output).
  - Fixed: emulator harness declared a slowly starting app dead on one transient `adb pidof` miss and force-stopped it (PR run 40561130695: no crash in logcat, later journeys cascaded); death now needs 3 consecutive misses over a working adb link after a 60 s grace. `measure_device.sh` no longer exits silently (PR run 40565431363) and always keeps its report + logcat.

- **Signed release (session 4)** — manual `.github/workflows/release.yml` builds the store AAB (`com.mariaalejandraboada.legendarrow`, versionCode 1) signed with the owner's upload key from GitHub secrets (decoded to runner temp, verified with keytool, deleted); `--no-ads` release mode leaves the ads plugin and Google SDKs out so the first upload needs no AdMob account; `scripts/check_no_secrets.sh` in CI; owner guide in `docs/RELEASE.md` §1–3 (D-39).
- **Store listing (session 4)** — new app icon (concept B, owner's choice) for store + launcher; versionCode 2 / 0.1.1; 16 Play Console assets in `docs/store/play_console/` rendered from the real game, checked by `tools/store_assets.py` in CI (artifact `play-store-assets`); bestiary overflow at phone width fixed (D-40).

## Verification
| Check | Result | Evidence |
|---|---|---|
| CI Godot import/compile/tests @ `eaf5c35` | **PASS** — 166 tests, 0 failed/pending/assertion-free | [run 40449617522](https://github.com/MariaAlejandraBoadaRodriguez/legend-arrow/actions/runs/40449617522) |
| CI Kotlin plugin: core JUnit, Android unit tests, lint, AAR @ `eaf5c35` | **PASS** — 15 core tests, `lintRelease` clean, AAR built | run 40449617522, artifacts `kotlin-reports`, `legend-ads-aar` |
| CI Gradle APK export + `check_apk.sh` @ `eaf5c35` | **PASS** — package/label, minSdk 24, targetSdk 36, LegendAds registered + packaged, Google test app id, no AD_ID / ACCESS_ADSERVICES_*, no notification/location/camera/mic/contacts, arm64-v8a + x86_64, 16 KB (ELF + zip offsets), signature; SHA-256 `d40fd283…5bdc` | run 40449617522, artifact `legend-arrow-debug-apk` |
| CI @ `25a9af4` (M4): Godot tests, Kotlin plugin, APK export + checks | **PASS** — 188 tests, 0 failed/pending/assertion-free; Kotlin + APK jobs green | [run 40554751564](https://github.com/MariaAlejandraBoadaRodriguez/legend-arrow/actions/runs/40554751564) |
| CI @ `c76f958` (M5): Android emulator E2E, API 34, 1080×2400 | **PASS** — fresh_install, partial_a, partial_b (after force-stop), blocked_undo, hint_ad, awakening_replay, settings_a, settings_b (after force-stop) + cold_start_smoke (TotalTime 1563 ms); 22 in-app PNGs + 9 screencaps | [run 40558523080](https://github.com/MariaAlejandraBoadaRodriguez/legend-arrow/actions/runs/40558523080), artifact `e2e-android-api34` |
| CI @ `c76f958`: desktop E2E phone + tablet | **PASS** — 8/8 journeys each | run 40558523080, artifacts `e2e-desktop-phone`, `e2e-desktop-tablet` |
| CI @ `c76f958`: line coverage | **PASS** — puzzle/solver/progression 94.8% (≥90), save/reward 95.1% (≥80) | run 40558523080, artifact `test-reports/coverage/` |
| CI @ `c76f958`: Godot tests, Kotlin, APK | **PASS** — 191 tests | run 40558523080 |
| CI @ `fa321c7` (M6): all 6 jobs incl. release AAB rehearsal + emulator E2E + measure_device | **PASS** — AAB: validate, versionCode 1 / 0.1.0, targetSdk 36, not debuggable, no AD_ID, arm64 + armv7 + x86_64, universal APK checks; download arm64 30.7 MB / armv7 32.1 MB (≤ 120 MB) | [run 40565420265](https://github.com/MariaAlejandraBoadaRodriguez/legend-arrow/actions/runs/40565420265), artifact `legend-arrow-release-aab-rehearsal` |
| **CI @ `7835016` (final code): push + PR runs, all 6 jobs** | **PASS** — emulator: 8/8 journeys + first-launch smoke on cleared data with the real UMP/GMA stack (test IDs) + measure_device; desktop phone/tablet 8/8 + Movie Maker video; AAB rehearsal; 192 tests + coverage | [push run 40580454945](https://github.com/MariaAlejandraBoadaRodriguez/legend-arrow/actions/runs/40580454945), [PR run 40580462900](https://github.com/MariaAlejandraBoadaRodriguez/legend-arrow/actions/runs/40580462900) (attempt 2: attempt 1 died downloading the emulator image, before any test) |
| Emulator performance (not device evidence) | measured — cold start 1.1–1.7 s; peak PSS 182–212 MB; software-GPU frame p95 110–133 ms puzzle / 86–130 ms awakening (SwiftShader, ~10 fps) | run 40565420265, `e2e-android-api34/measure-emulator` |
| Local `scripts/verify_all.sh` (M4) | **PASS** — 188 tests, 4,341 asserts, 0 failed/pending/assertion-free | `build/verify.log`, `build/reports/junit.xml` |
| Creature art final quality | **NOT RUN** — stylised procedural placeholder art; human art pass recommended before store listing (D-33) | — |
| Local Kotlin core (`-PcoreOnly`) | **PASS** — 15 tests | `build/kt.log` |
| Live ads on a device/emulator (consent form, real SDK callbacks) | **NOT RUN** — by design CI never requests ads (brief §5); manual check with Google test IDs before release | — |
| Physical-device performance | **BLOCKED** — no Android phone (D-18) | — |

## Next
1. Owner: create the upload keystore and the `release` environment secrets (`docs/RELEASE.md` §1–2), then run **Release AAB** (`without-ads`, versionCode 1). The real signed run has not executed yet: it needs those secrets.
2. All milestones M0–M6 delivered. Remaining work needs the owner (see `RELEASE_CHECKLIST.md` → Owner actions): Play App Signing, AdMob IDs + UMP message → `ads_release.json`, hosted privacy policy, Play Console forms, `scripts/measure_device.sh` on a real phone.
3. Recommended: human creature-art pass; physical-device performance run (software-GPU emulator ran ~10 fps, so the 60 fps budget is unverified).

Next command: `scripts/verify_all.sh` (any change), `scripts/measure_device.sh <apk>` on a phone (owner).

## Blockers
- **Network policy (cloud environment):** `dl.google.com` (Google Maven, Android SDK, emulator images) is denied and Maven Central rate-limits → Android builds only in CI. Allowing `dl.google.com` in the environment's Network access settings would enable local Android builds/emulator.
- Physical-device checks: BLOCKED by design (D-18).
- Release ads: real AdMob IDs, UMP message, `ads_release.json` — owner prerequisites (see `docs/ADS_AND_PRIVACY.md`).
