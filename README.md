# Legend Arrow

A calm arrow-puzzle game for Android: clear arrows with an open path out, awaken legendary creatures, and collect them in a bestiary.

Built with Godot 4.7.2 (GDScript, Compatibility renderer) · Android · GitHub Actions. No accounts, no backend; plays offline.

## Status
Milestones M0 (skeleton + CI) and M1 (puzzle model, solver, validator, generator, tests) — see `docs/PROGRESS.md` for the live state and `docs/ROADMAP.md` for the plan.

## Quick start
```bash
scripts/verify_all.sh   # import + script check + all tests (downloads pinned Godot)
```
Open `project.godot` in Godot 4.7.2 to run the game. Details: `BUILDING.md`.

## Rules in one paragraph
Each arrow is a path on a grid; its head shows where it moves. Tapping an arrow slides the **whole** arrow that way until it leaves the board — only if nothing else is in the way of any part of it. Clear every arrow to awaken the creature.

## Layout
```
project.godot        Godot project (Legend Arrow)
scripts/core/        Pure puzzle model: ArrowPath, PuzzleBoard, PuzzleSolver,
                     LevelValidator, LevelGenerator, PuzzleSession, LevelData
scripts/*.sh|.py     Build/test wrappers (verify_all.sh, install_godot.sh, check_junit.py)
tests/unit/          Rule, solver, validator, session, RNG tests (GUT)
tests/property/      1,000 seeded generated boards + solver-vs-brute-force
tools/               Headless tools (script compile check; level tools later)
data/levels|creatures  Packaged content (from M2)
addons/gut/          Vendored GUT 9.7.1 (tests only)
docs/                Brief, spec, mockups, roadmap, decisions, progress
```

## Documentation
`BUILDING.md` · `docs/ROADMAP.md` · `docs/DECISIONS.md` · `docs/PROGRESS.md` · `docs/LEVEL_FORMAT.md` · `docs/THIRD_PARTY_NOTICES.md`
