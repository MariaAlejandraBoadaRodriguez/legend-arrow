# Progress

_Last updated: 2026-11-19 (v0.2 milestone B: final icon, timer, stars, results, save migration)_

## v0.2 — current status
Owner prompt: `docs/prompts/03_V0_2.md` (decisions D-41…D-43). Milestones A–F in `docs/ROADMAP.md`. Branch `claude/upbeat-turing-4w8wzu`.

### Milestone B — DONE (CI pending at the time of writing)
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
