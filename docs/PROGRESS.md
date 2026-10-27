# Progress

_Last updated: 2026-10-27 (session 1)_

## Done
- **M0** — audit, `docs/ROADMAP.md`, `docs/DECISIONS.md`, Godot 4.7.2 project skeleton (`project.godot`, `scenes/main.tscn` placeholder), GUT 9.7.1 vendored, `scripts/install_godot.sh` (SHA-256 pinned), `scripts/verify_all.sh`, `scripts/check_junit.py`, `tools/check_scripts.gd`, CI workflow `.github/workflows/ci.yml`.
- **M1** — `scripts/core/`: `ArrowPath`, `PuzzleBoard` (swept-body rule), `PuzzleSolver` (graph solver, verify, depth, exhaustive explore), `LevelValidator`, `LevelGenerator` (reverse construction, restarts, mask support), `DeterministicRng`, `LevelData`, `PuzzleSession` (tap/undo/restart/hint/save replay).
- Tests: 68 tests / 2,357 assertions locally (unit + property over 1,000 seeded boards + 300 random boards vs brute force).
- Gate negative checks demonstrated locally: empty test discovery → exit 1; failing test → exit 1; assertion-free test → exit 1; broken script → check_scripts exit 1.

## Next
- Confirm the GitHub Actions run for the latest commit is green (see links in the session report).
- **M2** vertical slice: `docs/UI_FLOW.md`, theme/tokens, board view + input, tutorial (3 steps), Forest Drake levels 1–2 (generated with mask, validated), progression + atomic saves (+ tests), awakening animation, bestiary, settings, EN/ES, Android export preset + debug APK job in CI.

Next command: `scripts/verify_all.sh`

## Blockers
- None for M0–M1. Physical-device checks are BLOCKED by design (no Android phone, see DECISIONS D-18).
