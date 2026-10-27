# Legend Arrow

A calm arrow-puzzle game for Android: clear arrows with an open path out, awaken legendary creatures, and collect them in a bestiary.

Built with Godot 4.7.2 (GDScript, Compatibility renderer) · Android · GitHub Actions. No accounts, no backend; plays offline.

## Status
M0 (skeleton + CI), M1 (puzzle model, solver, validator, tests) and M2 (playable vertical slice: tutorial, Forest Drake's two puzzles, awakening, bestiary, settings, EN/ES, debug APK) are implemented. Live state: `docs/PROGRESS.md`; plan: `docs/ROADMAP.md`.

## Play
Open the project in Godot 4.7.2 and press Play, or install the debug APK (`scripts/export_android.sh`, or the CI artifact `legend-arrow-debug-apk`) on an Android emulator.
Tap an arrow whose whole path to the edge is clear. Undo, Restart and three hints per puzzle are free. Clear both puzzles of a creature to awaken it.

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
scripts/core/        Pure logic: ArrowPath, PuzzleBoard, PuzzleSolver, LevelValidator,
                     LevelGenerator, PuzzleSession, LevelData, Campaign, Progression,
                     SaveSchema, SaveRepository
scripts/app/         Game autoload (navigation, settings, lifecycle), main scene, EventLog
scripts/ui/          Theme, palette, BoardView, dialogs, widgets
scripts/screens/     One script per screen (scenes/screens/*.tscn)
scripts/creatures/   CreatureRig, CreatureStage, per-creature rigs
data/                campaign.json, tutorial.json, levels/, creatures/
locales/strings.csv  English + Spanish UI strings
assets/              Inter font, launcher icons
scripts/*.sh|.py     Build/test wrappers (verify_all.sh, install_godot.sh, check_junit.py)
tests/unit/          Rule, solver, validator, session, RNG tests (GUT)
tests/property/      1,000 seeded generated boards + solver-vs-brute-force
tests/content/       Packaged levels, tutorial and campaign validation
tests/integration/   Real screens driven in-engine (journeys, input, leaks)
tools/               Script compile check, level generator, screenshot/render capture
addons/gut/          Vendored GUT 9.7.1 (tests only)
docs/                Brief, spec, mockups, roadmap, decisions, progress
```

## Documentation
`BUILDING.md` · `docs/ARCHITECTURE.md` · `docs/UI_FLOW.md` · `docs/LEVEL_FORMAT.md` · `docs/SAVE_FORMAT.md` · `docs/ROADMAP.md` · `docs/DECISIONS.md` · `docs/PROGRESS.md` · `docs/THIRD_PARTY_NOTICES.md` · screenshots in `docs/screenshots/`
