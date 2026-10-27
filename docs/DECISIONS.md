# Decisions and assumptions

Priority on conflicts: `CLAUDE.md` > brief > spec > READ_FIRST > mockup pixels.

| ID | Decision | Why / trade-off |
|---|---|---|
| D-01 | Product name **Legend Arrow** everywhere; "Flechas: Bestiary" / "Arrows" in spec and mockups are the old working title. Spanish UI may show "Flechas" only as a tagline. | CLAUDE.md fixed decision. |
| D-02 | Engine **Godot 4.7.2-stable** (latest stable on 2026-10-27, tags checked via `git ls-remote`), GDScript, Compatibility renderer. Binary SHA-256 pinned in `scripts/install_godot.sh`. | Spec §3; no preview builds. |
| D-03 | Test runner **GUT 9.7.1** (commit `aeb5d4f3f7f0a6c9b5e178876d6c99b791fda605`), vendored in `addons/gut/` (MIT). | GUT's compatibility table maps 9.7.1 → Godot 4.7.x. Vendoring (3.2 MB) makes the project work in the editor on Windows/macOS with no extra install step and pins the exact code. Excluded from Android export (M2). |
| D-04 | Application ID `com.mariaalejandraboada.legendarrow`. | CLAUDE.md fixed; permanent once on Play. |
| D-05 | **No backend.** Local JSON content, local atomic saves, service interfaces (ads, consent, remote config, event log) with local/mock implementations. | Brief Phase 5: every requirement is satisfiable offline; avoids hosting cost and privacy surface. |
| D-06 | GDScript lives in `scripts/` (sub-folders `core/`, later `ui/`, `services/`…); shell/Python wrappers live directly in `scripts/`. | Spec §22 lists both under `scripts/`. Godot ignores non-.gd files. |
| D-07 | **Solver = dependency graph + topological sort.** An arrow's swept area depends only on its own cells, so its blockers in any state = (blockers on the full board) ∩ (arrows still present). Hence removal never creates a blocker (monotonicity), a board is solvable iff the "blocked-by" graph is acyclic, and from a solvable board every legal move keeps it solvable (no deadlocks). | Exact and O(n·area). Cross-checked against exhaustive BFS on 300 random (often unsolvable) boards and on all small generated boards in `tests/property/`. |
| D-08 | Swept-body check = cast a ray from **every** body cell in the head direction to the board edge; any foreign cell hit blocks. Own cells are ignored (U-turn and spiral arrows are legal). | Equivalent to discrete rigid one-cell steps until fully off-board (spec §4). |
| D-09 | Arrow direction is **derived** from the last two cells, not stored. | Removes a class of inconsistent data; validator enforces orthogonal adjacency so the direction is always a unit vector. |
| D-10 | Generator = deterministic **reverse construction** with own xorshift32 RNG (`DeterministicRng`), restarts on stall, optional silhouette mask. Output IDs are renamed `a01…` in head reading order; solution = reverse insertion order. | Solvable by construction; own RNG keeps content bit-identical across engine versions (golden-value test). |
| D-11 | Difficulty bands from spec §5 are **enforced** by the validator, plus a `tutorial` band (1–8 arrows) for the first creature's very short levels. | Spec: first creature uses two very short levels; bands are provisional and can be tuned in one constant. |
| D-12 | Hints pick the earliest arrow of the certified solution that is free now; fallback any free arrow. Hints never change state. | Sensible order; always safe because moves cannot deadlock (D-07). |
| D-13 | Undo is disabled once a level is complete; restart is allowed (replay). Rewards are owned by progression, not the session. | Spec §4: undo cannot undo a completed reward; replay grants no duplicate reward. |
| D-14 | Saved in-progress state stores only the ordered removed-arrow IDs and is **replayed through the rules** on load; an illegal history is rejected and the level restarts. | Tampered/stale saves can never produce an impossible board. |
| D-15 | The test gate fails on: GUT nonzero exit, any script/parse error in logs, zero tests, pending/skipped tests, assertion-free tests, or a test file that reports no tests. | Spec §20 / CLAUDE.md honesty rules. Each gate was demonstrated failing (see PROGRESS). |
| D-16 | CI runs on pushes to `master` (the repo default branch), `main` and `claude/**`, PRs and manual dispatch; actions pinned by commit SHA; `permissions: contents: read`. | Brief §5. `claude/**` lets each development branch prove green before merge. |
| D-17 | JDK: spec says JDK 17 for Godot Android export. Container has JDK 21; CI will install Temurin 17 via `actions/setup-java` for the export job (M2). | Follow Godot's documented requirement. |
| D-18 | Physical-device performance checks are **BLOCKED** (owner has no Android phone); `scripts/measure_device.sh` will be shipped (M6). | CLAUDE.md. |

## External prerequisites (owner-supplied, not fabricated)
- Real AdMob app ID and ad unit IDs (until then: Google's official test IDs).
- Upload/release signing key (debug keystore only in CI).
- Google Play Console account, Families/target-audience declaration, Data Safety form.
- Public hosting URL for the privacy policy (draft delivered in M6).
- A physical low/mid-tier Android phone for performance/memory evidence.
