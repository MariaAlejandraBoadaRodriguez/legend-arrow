# Progress

_Last updated: 2026-10-27 (session 3, M6)_

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
1. Owner: review/merge PR #2 into `main`.
2. All milestones M0–M6 delivered. Remaining work needs the owner (see `RELEASE_CHECKLIST.md` → Owner actions): upload key + Play App Signing, AdMob IDs + UMP message → `ads_release.json`, hosted privacy policy, Play Console forms, `scripts/measure_device.sh` on a real phone.
3. Recommended: human creature-art pass; physical-device performance run (software-GPU emulator ran ~10 fps, so the 60 fps budget is unverified).

Next command: `scripts/verify_all.sh` (any change), `scripts/measure_device.sh <apk>` on a phone (owner).

## Blockers
- **Network policy (cloud environment):** `dl.google.com` (Google Maven, Android SDK, emulator images) is denied and Maven Central rate-limits → Android builds only in CI. Allowing `dl.google.com` in the environment's Network access settings would enable local Android builds/emulator.
- Physical-device checks: BLOCKED by design (D-18).
- Release ads: real AdMob IDs, UMP message, `ads_release.json` — owner prerequisites (see `docs/ADS_AND_PRIVACY.md`).
