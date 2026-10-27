# Progress

_Last updated: 2026-10-27 (session 3)_

## Where things are
- `main` holds M0–M2 (PR #1 merged). M3 is on `claude/new-session-8a6cy7` in PR [#2](https://github.com/MariaAlejandraBoadaRodriguez/legend-arrow/pull/2) → `main`, CI green; merge is the owner's call.

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

## Verification
| Check | Result | Evidence |
|---|---|---|
| CI Godot import/compile/tests @ `eaf5c35` | **PASS** — 166 tests, 0 failed/pending/assertion-free | [run 40449617522](https://github.com/MariaAlejandraBoadaRodriguez/legend-arrow/actions/runs/40449617522) |
| CI Kotlin plugin: core JUnit, Android unit tests, lint, AAR @ `eaf5c35` | **PASS** — 15 core tests, `lintRelease` clean, AAR built | run 40449617522, artifacts `kotlin-reports`, `legend-ads-aar` |
| CI Gradle APK export + `check_apk.sh` @ `eaf5c35` | **PASS** — package/label, minSdk 24, targetSdk 36, LegendAds registered + packaged, Google test app id, no AD_ID / ACCESS_ADSERVICES_*, no notification/location/camera/mic/contacts, arm64-v8a + x86_64, 16 KB (ELF + zip offsets), signature; SHA-256 `d40fd283…5bdc` | run 40449617522, artifact `legend-arrow-debug-apk` |
| Local `scripts/verify_all.sh` (M4) | **PASS** — 188 tests, 4,341 asserts, 0 failed/pending/assertion-free | `build/verify.log`, `build/reports/junit.xml` |
| Creature art final quality | **NOT RUN** — stylised procedural placeholder art; human art pass recommended before store listing (D-33) | — |
| Local Kotlin core (`-PcoreOnly`) | **PASS** — 15 tests | `build/kt.log` |
| Live ads on a device/emulator (consent form, real SDK callbacks) | **NOT RUN** — needs an emulator (M5); CI never requests ads | — |
| APK install/launch on emulator | **NOT RUN** — M5 CI emulator job | — |
| Physical-device performance | **BLOCKED** — no Android phone (D-18) | — |

## Next
1. Owner: review/merge PR #2 into `main`.
2. **M5** — Android E2E/instrumentation on a CI emulator (install, launch, play a level, mock ads), phone/tablet screenshots, requirements/coverage matrix.
3. Polish noted earlier: cap button width on tablets; creature art pass.

Next command: `scripts/verify_all.sh`, then start M5 (`.github/workflows` emulator job).

## Blockers
- **Network policy (cloud environment):** `dl.google.com` (Google Maven, Android SDK, emulator images) is denied and Maven Central rate-limits → Android builds only in CI. Allowing `dl.google.com` in the environment's Network access settings would enable local Android builds/emulator.
- Physical-device checks: BLOCKED by design (D-18).
- Release ads: real AdMob IDs, UMP message, `ads_release.json` — owner prerequisites (see `docs/ADS_AND_PRIVACY.md`).
