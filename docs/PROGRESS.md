# Progress

_Last updated: 2026-10-27 (session 1)_

## ⚠ Blocker: commits are not on GitHub yet
`git push` to `MariaAlejandraBoadaRodriguez/legend-arrow` returns **403**; the GitHub API also refuses writes ("Resource not accessible by integration"). Reads work. The Claude GitHub App needs write access to this repo (owner action, see "Blockers"). All work is committed locally on branch `claude/new-session-8a6cy7`; **no GitHub Actions run exists yet**.

## Done
- **M0** — roadmap, decisions, Godot 4.7.2 skeleton, vendored GUT 9.7.1, pinned installer (SHA-256), `scripts/verify_all.sh` + JUnit gate, CI workflow (SHA-pinned actions). Gate negative checks demonstrated: empty discovery, failing test, assertion-free test, broken script → all exit 1.
- **M1** — pure model (`scripts/core/`): swept-body rules, graph solver, validator, deterministic generator, session (undo/restart/hint/save replay). Property suite: 1,000 seeded boards + 300 random boards vs brute force.
- **M2** — vertical slice:
  - Progression (two-puzzle unlock, idempotent transactions, pending-awakening replay, hint wallet) and atomic saves (checksum, tmp+rename, backup, quarantine, v1→v2 migration, kill-at-each-step tests).
  - Content: Forest Drake levels 1–2 (mask-generated, validated, exhaustively deadlock-free), 3 tutorial boards, `campaign.json`.
  - Client: Game autoload, BoardView (tap/drag/multitouch/cancel, nearest-path hits, keyboard focus, exit/blocked/hint/undo animation), 10 screens + pause/hint/credits/restored dialogs, EN/ES (`locales/strings.csv`), Inter font, WCAG-checked tokens, reduced motion, haptics toggle, audio buses (no sounds yet).
  - Forest Drake layered cut-out rig with ~5 s awakening (gather → silhouette → wings unfold → silent roar → wing beat → settle) and idle loop; SubViewport stage.
  - Android: `export_presets.cfg` (no secrets), `scripts/export_android.sh`, `scripts/check_apk.sh`, CI job `android-debug-apk`.

## Verification (local, this container)
| Check | Result | Evidence |
|---|---|---|
| `scripts/verify_all.sh` (import, compile 53 scripts, GUT, JUnit gate) | **PASS** — 127 tests, 0 failed/pending/assertion-free | `build/reports/summary.json`, `junit.xml` |
| Debug APK export (`scripts/export_android.sh`, Ubuntu SDK tools, D-25) | **PASS** — package, label, minSdk 24, targetSdk 36, arm64-v8a + x86_64 libs, signature | `build/android/apk_report.txt` |
| 16 KB page alignment | **NOT RUN** locally (old zipalign); runs in CI | — |
| GitHub Actions run | **NOT RUN** — push blocked (403) | — |
| APK install/launch on emulator | **NOT RUN** — no emulator/KVM here; M5 CI emulator | — |
| Physical-device performance | **BLOCKED** — no Android phone (D-18) | — |
| Screenshots phone/tablet EN/ES | captured (visual evidence only) | `docs/screenshots/m2/` |

## Next
1. Owner: grant the Claude GitHub App write access (see Blockers), then: `git push -u origin claude/new-session-8a6cy7` and check the Actions run; fix until green.
2. **M3**: `AdService`/`ConsentService` interfaces + mock provider, reward state machine (idle→loading→ready→showing→rewarded/dismissed/failed) + tests; switch Android export to Gradle build with a Kotlin plugin (UMP + Google Mobile Ads, child/unknown restricted, official test IDs); hint sheet "Watch ad" + "No ad available" states.
3. Polish noted from screenshots: cap button width on tablets; creature art pass (M4).

Next command: `scripts/verify_all.sh`

## Blockers
- **GitHub write access (owner action):** reconnect GitHub at https://claude.ai/connect-github and make sure the Claude GitHub App is installed on `legend-arrow` with write access (https://github.com/apps/claude/installations/select_target).
- **Network policy:** `dl.google.com` is denied in this cloud environment (Android SDK/emulator images). Allowing it (environment settings → Network access → Allowed domains) enables a local emulator and the official SDK; CI is unaffected.
- Physical-device checks: BLOCKED by design (D-18).
