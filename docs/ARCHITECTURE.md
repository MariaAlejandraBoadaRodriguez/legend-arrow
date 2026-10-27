# Architecture

```mermaid
flowchart TD
    Main["main.gd: boot, Back, safe area"] --> Game["Game autoload: navigation, settings, lifecycle saves"]
    Game --> Screens["scripts/screens/*: Home, Tutorial, Level select, Puzzle, Awakening, Detail, Bestiary, Settings"]
    Screens --> Board["BoardView: draw + input"]
    Board --> Session["PuzzleSession: tap/undo/restart/hint"]
    Session --> Model["PuzzleBoard + PuzzleSolver (pure)"]
    Game --> Progression["Progression: unlocks, idempotent rewards, hints"]
    Progression --> Saves["SaveRepository: atomic, backup, migration"]
    Game --> Content["Campaign + LevelData + LevelValidator (data/*.json)"]
    Screens --> Stage["CreatureStage (SubViewport) -> CreatureRig (layered cut-out)"]
    Game --> Events["EventLog (local, in-memory)"]
    Screens -. M3 .-> Ads["AdService interface -> Mock / Kotlin bridge (UMP + GMA)"]
    CI["GitHub Actions"] --> Verify["verify_all.sh: import, compile, GUT, JUnit gate"]
    CI --> APK["export_android.sh + check_apk.sh"]
```

- `scripts/core/` is pure (RefCounted, no nodes): runs headless, unit/property tested.
- Screens never mutate the model directly: BoardView emits `arrow_tapped`; the screen calls `session.tap()`, persists, then animates.
- Rewards: completion and unlock are transactions keyed `complete:<level>` / `unlock:<creature>` — replay, skip, kill and relaunch cannot duplicate them.
- Ad callbacks (M3) will go through Progression.grant_ad_hint(presentation_id) — idempotent and node-free.
- No backend; no network on any game path.
