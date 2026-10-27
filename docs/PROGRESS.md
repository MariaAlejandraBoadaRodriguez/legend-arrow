# Progress

_Last updated: 2026-10-27 (session 3)_

## Where things are
- `main` holds M0–M2 (PR #1 merged). M3, M4 and M5 are on `claude/new-session-8a6cy7` in PR [#2](https://github.com/MariaAlejandraBoadaRodriguez/legend-arrow/pull/2) → `main`, CI green; merge is the owner's call.

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
| Local `scripts/verify_all.sh` (M4) | **PASS** — 188 tests, 4,341 asserts, 0 failed/pending/assertion-free | `build/verify.log`, `build/reports/junit.xml` |
| Creature art final quality | **NOT RUN** — stylised procedural placeholder art; human art pass recommended before store listing (D-33) | — |
| Local Kotlin core (`-PcoreOnly`) | **PASS** — 15 tests | `build/kt.log` |
| Live ads on a device/emulator (consent form, real SDK callbacks) | **NOT RUN** — by design CI never requests ads (brief §5); manual check with Google test IDs before release | — |
| Physical-device performance | **BLOCKED** — no Android phone (D-18) | — |

## Next
1. Owner: review/merge PR #2 into `main`.
2. **M6** — release prep: AAB, checksums, privacy policy draft, Data Safety inventory, `RELEASE_CHECKLIST.md`, `QA_REPORT.md`, `scripts/measure_device.sh`.
3. Polish noted earlier: creature art pass (human).

Next command: `scripts/verify_all.sh`, then M6.

## Blockers
- **Network policy (cloud environment):** `dl.google.com` (Google Maven, Android SDK, emulator images) is denied and Maven Central rate-limits → Android builds only in CI. Allowing `dl.google.com` in the environment's Network access settings would enable local Android builds/emulator.
- Physical-device checks: BLOCKED by design (D-18).
- Release ads: real AdMob IDs, UMP message, `ads_release.json` — owner prerequisites (see `docs/ADS_AND_PRIVACY.md`).
