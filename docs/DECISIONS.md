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
| D-16 | CI runs on pushes to `master`, `main` and `claude/**`, PRs and manual dispatch; actions pinned by commit SHA; `permissions: contents: read`. | Brief §5. `claude/**` lets each development branch prove green before merge. |
| D-17 | JDK: spec says JDK 17 for Godot Android export. Container has JDK 21; CI will install Temurin 17 via `actions/setup-java` for the export job (M2). | Follow Godot's documented requirement. |
| D-18 | Physical-device performance checks are **BLOCKED** (owner has no Android phone); `scripts/measure_device.sh` will be shipped (M6). | CLAUDE.md. |
| D-19 | Android auto-backup **disabled** (`user_data_backup/allow=false`). | Spec §15 asks for an explicit choice; avoids restoring a save onto a different app version unexpectedly. No cross-device sync is claimed. |
| D-20 | Non-Gradle template export for M2: Godot 4.7.2's template yields **targetSdk 36, minSdk 24**. Spec's provisional minSdk 26 is a floor we test against; 24 widens support at no cost. M3 switches to a Gradle build (Kotlin plugin) and pins min 24 / target 36 explicitly. | Verified with `aapt dump badging` on the locally exported APK. |
| D-21 | Creature art = original **procedural layered vector cut-outs** (Polygon2D/Line2D parts with pivots) rendered into a transparent SubViewport so fades composite correctly. No paid or third-party art. | Fits "original layered illustration", animates with Tween without sliding stickers. Quality is reviewed by rendered screenshots; a polish pass is planned in M4 and it is **not** claimed as final art yet. |
| D-22 | Font: **Inter 4.1** (SIL OFL 1.1), Regular + SemiBold. | One sans family, two weights (spec §8). License in `assets/fonts/Inter-LICENSE.txt`. |
| D-23 | Board touch rules: tap = press/release within 24 px and 0.8 s with a single finger; nearest path within 0.6 cell wins; input locked during an exit animation. Pinch/pan arrive with M4's larger boards. | Spec §13. Covered by `tests/integration/test_board_input.gd`. |
| D-24 | Scene-level journey tests run in-engine (`tests/integration/`), driving real screens with synthesized touch events. They are **not** Android instrumentation; M5 adds emulator E2E. | Brief §4: never mislabel model/in-engine tests as device E2E. |
| D-25 | Local APK export in this cloud container uses Ubuntu's `apksigner`/`aapt`/`zipalign` because `dl.google.com` is blocked by the environment's network policy. CI uses the runner's official SDK. 16 KB page-size compatibility is checked by `scripts/check_page_size.py` (ELF `PT_LOAD` p_align ≥ 16384, and 16 KB zip offsets for stored libs) instead of zipalign's `-P` flag, whose availability differs between tool versions. | Same check locally and in CI. |
| D-26 | `main` was created from `claude/new-session-8a6cy7` (the repo had only `master`, holding the initial upload). Later work lands on `main` through PRs. Owner may set `main` as the default branch in GitHub settings. | Owner instruction: push to `main` if it does not exist. |

## External prerequisites (owner-supplied, not fabricated)
- Real AdMob app ID and ad unit IDs (until then: Google's official test IDs).
- Upload/release signing key (debug keystore only in CI).
- Google Play Console account, Families/target-audience declaration, Data Safety form.
- Public hosting URL for the privacy policy (draft delivered in M6).
- A physical low/mid-tier Android phone for performance/memory evidence.
