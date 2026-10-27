# Progress

_Last updated: 2026-10-27 (session 1)_

## Where things are
- Branch `claude/new-session-8a6cy7` pushed; `main` created from it at `8950f0d` (the repo previously had only `master` = initial upload; see DECISIONS D-26).
- Follow-up fix (16 KB page-size check) is on `claude/new-session-8a6cy7` with a PR into `main`.

## Done
- **M0** — roadmap, decisions, Godot 4.7.2 skeleton, vendored GUT 9.7.1, pinned installer (SHA-256), `scripts/verify_all.sh` + JUnit gate, SHA-pinned CI. Gate negative checks demonstrated: empty discovery, failing test, assertion-free test, broken script → all exit 1.
- **M1** — pure model (`scripts/core/`): swept-body rules, graph solver, validator, deterministic generator, session (undo/restart/hint/save replay). 1,000 seeded boards + 300 random boards vs brute force.
- **M2** — vertical slice: progression + atomic saves (backup, quarantine, migration, kill-at-each-step), Forest Drake levels 1–2 + 3 tutorial boards, 10 screens + dialogs, EN/ES, Inter font, WCAG-checked tokens, reduced motion, Forest Drake layered rig with ~5 s awakening, Android export preset/scripts, CI APK job.

## Verification
| Check | Result | Evidence |
|---|---|---|
| CI `Godot import, script check and tests` on `main` @ `8950f0d` | **PASS** — 127 tests discovered, 127 passed, 2,693 assertions, 0 failed/pending/assertion-free | [run 40444356036](https://github.com/MariaAlejandraBoadaRodriguez/legend-arrow/actions/runs/40444356036), artifact `test-reports` |
| Same on branch push | **PASS** | [run 40444348583](https://github.com/MariaAlejandraBoadaRodriguez/legend-arrow/actions/runs/40444348583) |
| CI `Export Android debug APK` @ `8950f0d` | **PASS** — package `com.mariaalejandraboada.legendarrow`, label, minSdk 24, targetSdk 36, arm64-v8a + x86_64, only VIBRATE permission, signature verified; SHA-256 `0de538d3…e248` | artifact `legend-arrow-debug-apk` in run 40444356036 |
| 16 KB page size | **NOT RUN** in run 40444356036 (zipalign flag detection missed); **PASS locally** with new `scripts/check_page_size.py` (all 4 libs PT_LOAD p_align 16384, libs compressed) — CI confirmation pending on the PR run | `scripts/check_page_size.py` |
| Local `scripts/verify_all.sh` | **PASS** — 127 tests | `build/reports/summary.json` |
| APK install/launch on emulator | **NOT RUN** — M5 CI emulator job | — |
| Physical-device performance | **BLOCKED** — no Android phone (D-18) | — |
| Screenshots phone/tablet EN/ES | captured (visual evidence only) | `docs/screenshots/m2/` |

## Next
1. Confirm the PR's CI run shows the 16 KB check PASS; merge into `main`.
2. **M3**: `AdService`/`ConsentService` interfaces + mock provider, reward state machine (idle→loading→ready→showing→rewarded/dismissed/failed) + tests; Gradle-based Android export with a Kotlin plugin (UMP + Google Mobile Ads, child/unknown restricted, official test IDs); hint sheet "Watch ad" and "No ad available" states.
3. Polish from screenshots: cap button width on tablets; creature art pass (M4).

Next command: `scripts/verify_all.sh`

## Blockers
- **Network policy (cloud environment):** `dl.google.com` denied → no official Android SDK/emulator inside this container (CI unaffected). Allow it under the environment's Network access settings to run an emulator here.
- Physical-device checks: BLOCKED by design (D-18).
- Optional owner action: make `main` the default branch on GitHub (currently `master`).
