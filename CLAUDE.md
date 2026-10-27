# Legend Arrow — standing instructions for Claude Code

Read this file at the start of every session. Keep it short; details live in `docs/`.

## Sources of truth (read in this order, only the parts you need)
1. `docs/PROGRESS.md` — where the last session stopped (create it if missing).
2. `docs/brief/LEGEND_ARROW_BRIEF.md` — owner's execution brief: phases, tests, CI, deliverables.
3. `docs/design/DEVELOPMENT_SPEC.md` — gameplay, rules, ads/privacy, testing (governs behavior).
4. `docs/design/READ_FIRST_CLAUDE.md` + `docs/design/mockups/*.png` — visual direction (governs look).

Conflict priority: this file > brief > spec > READ_FIRST > mockup pixels. Record resolutions in `docs/DECISIONS.md`.

## Fixed decisions (do not re-ask)
- Product name: **Legend Arrow** everywhere (app label, docs, store). The spec/mockups say "Flechas: Bestiary" or "Arrows" — treat those as the old working title. Spanish UI may show the subtitle "Flechas" only as a localized tagline; the app name stays Legend Arrow in both languages.
- Android application ID: `com.mariaalejandraboada.legendarrow` (permanent on Google Play — never change after first release).
- GitHub repo: this repository (`legend-arrow`, private). Do not create another one.
- Engine: stable Godot 4.x + GDScript, Compatibility renderer. Pin the exact version in `BUILDING.md`.
- No backend, accounts, email, login, cloud saves or paid assets.
- Owner has **no Android phone** (iPhone only). Device testing = Android Studio emulator on her computer + CI emulator. Mark physical-device performance checks **BLOCKED**, never PASS, and ship `scripts/measure_device.sh` so she can run them later.
- Ads: official Google **test** IDs only. Real AdMob IDs and release signing keys are owner-supplied later; never fabricate or commit them.

## How to work within Claude Pro limits
- Work in milestones (see below). Each milestone ends with: tests run → `docs/PROGRESS.md` updated → commit → push.
- Read files with targeted ranges; don't re-read the whole spec every session.
- Keep commits small and coherent. Push after every milestone so nothing is lost if the session ends.
- If you run out of budget mid-milestone, first write PROGRESS.md (done / next command / blockers), commit "wip: checkpoint", push.

## Milestones
- **M0** Audit + roadmap (`docs/ROADMAP.md`, `docs/DECISIONS.md`, `docs/PROGRESS.md`), Godot project skeleton, `.gitignore`, test runner pinned (GUT or gdUnit4), `scripts/verify_all.sh`, first CI workflow that runs headless tests. Empty test discovery must fail.
- **M1** Pure puzzle model + swept-body collision + solver + level validator + unit/property tests (1,000 seeded boards).
- **M2** Vertical slice: tutorial (3 steps), 2 levels, 1 creature (Forest Drake), real awakening animation, bestiary, settings, atomic saves, EN/ES. Debug APK exported in CI.
- **M3** Ad/consent service interface + mock provider + Kotlin bridge (UMP + Google Mobile Ads, child/unknown restricted) + reward state machine tests.
- **M4** Full content: 24 validated levels, 12 creatures with layered art, distinct awakenings, audio buses.
- **M5** Android E2E/instrumentation on CI emulator, screenshots phone/tablet, coverage/requirements matrix, fixes until green.
- **M6** Release prep: AAB, checksums, privacy policy draft, Data Safety inventory, `RELEASE_CHECKLIST.md`, `QA_REPORT.md` with PASS/FAIL/BLOCKED/NOT RUN.

## Definition of honesty
A workflow file is not proof. Only report PASS for checks that actually executed with assertions, citing the command, run link or log. Never disable or weaken a test to go green.
