# Legend Arrow — Roadmap

Planning window: 15–25 working days (provisional; re-estimate after M2's first Android vertical slice).
Milestones M0–M6 come from `CLAUDE.md`; phases 1–10 from the brief (§3). Every phase lists Activity, Tools, Risk, Justification/trade-off, Deliverable, Definition of Done (DoD), Dependencies and Estimated days.

| Phase | Milestone(s) | Est. days |
|---|---|---|
| 1 Requirements & repo audit | M0 | 0.5 |
| 2 Mockups, wireframes, flow | M0 (doc), M2 (applied) | 1 |
| 3 UI & design system | M2, refined M4 | 2 |
| 4 Architecture & data model | M0–M1 | 2 |
| 5 Backend/API assessment | M0 (doc), M3 (interfaces) | 0.5 |
| 6 Game client & content | M2 (slice), M4 (full) | 7–11 |
| 7 Android & monetization | M2 (export), M3 (ads/consent) | 2–3 |
| 8 Automated testing & repair | M1–M5 (continuous) | 2–3 |
| 9 GitHub, CI/CD, release prep | M0 (CI), M5, M6 | 1.5–2 |
| 10 Monitoring & post-launch | M6 | 0.5 |

---

## Phase 1 — Requirements and repository audit (M0)
- **Activity:** Inspect repo, tools, auth; turn brief/spec into acceptance criteria; list external dependencies.
- **Tools:** git, shell, Godot CLI, GitHub MCP.
- **Risk addressed:** Scope, delivery.
- **Justification / trade-off:** A short audit avoids rework; acceptance criteria live in the spec (§19–21) and are referenced, not duplicated.
- **Deliverable:** `docs/DECISIONS.md` (assumptions, scope boundaries, external prerequisites), this roadmap, `docs/PROGRESS.md`.
- **DoD:** No unresolved routine engineering decision; external blockers (AdMob IDs, upload key, Play Console, policy hosting, physical device) listed.
- **Dependencies:** none. **Days:** 0.5.

## Phase 2 — Mockups, wireframes and interaction flow (M0 doc → M2)
- **Activity:** Review all 14 screens; document every screen state, transition, empty/loading/blocked/ad-failure/recovery state and Back behaviour.
- **Tools:** Mockups in `docs/design/mockups/`, Markdown flow table.
- **Risk addressed:** Product (confusing onboarding), scope.
- **Justification / trade-off:** A state table is cheaper than Figma rework and is directly testable by E2E navigation tests.
- **Deliverable:** `docs/UI_FLOW.md` (screen → states → destinations → Back).
- **DoD:** Every screen in READ_FIRST + loading/consent/no-ad/save-recovery has a documented state and destination.
- **Dependencies:** Phase 1. **Days:** 1.

## Phase 3 — UI and design system (M2, refined M4)
- **Activity:** Godot `Theme` with spec tokens (#FAF9F6, #F0EFEB, #25282B, #62686D, #47677C, #D9D8D2, #244A63, #8A4E48), one sans family in two weights, buttons ≥48 dp, dialogs, cards, focus outlines, safe-area container.
- **Tools:** Godot Theme/StyleBox, a bundled OFL font, contrast checker script.
- **Risk addressed:** Product, technical (clipping, contrast).
- **Justification / trade-off:** One shared Theme keeps the restrained palette consistent; no custom shaders.
- **Deliverable:** `assets/theme/legend_arrow_theme.tres`, `scripts/ui/*`, contrast test.
- **DoD:** WCAG AA contrast test passes for every text/background pair; phone + tablet screenshots show no clipping or saturated colour.
- **Dependencies:** Phase 2. **Days:** 2.

## Phase 4 — Architecture and data model (M0–M1)
- **Activity:** Pure puzzle model (`scripts/core/`), swept-body collisions, exact solver, validator, deterministic generator, session (undo/restart/hint); later progression, save repository, reward ledger as separate modules.
- **Tools:** GDScript (RefCounted classes, no nodes), GUT 9.7.1.
- **Risk addressed:** Technical (solvability, race conditions).
- **Justification / trade-off:** Rules as plain objects run headless and fast; the view only observes results. Dependency-graph solver is exact for removal-only rules (proof in DECISIONS D-07).
- **Deliverable:** `scripts/core/*.gd`, `docs/LEVEL_FORMAT.md`, `docs/ARCHITECTURE.md`.
- **DoD:** Model runs headless; schema validation, solver and property tests pass in CI.
- **Dependencies:** Phase 1. **Days:** 2.

## Phase 5 — Backend/API assessment (M0 doc, M3 interfaces)
- **Activity:** Assess backend need → **No backend required.** Define `AdService`, `ConsentService`, `RemoteConfig` (local default, can only reduce ad pressure), `EventLog` (in-memory/local sink).
- **Tools:** GDScript interfaces, mock providers.
- **Risk addressed:** Scope, delivery (no hosting cost).
- **Justification / trade-off:** Local JSON content + local saves satisfy every requirement; a server would add cost, privacy surface and offline failure modes.
- **Deliverable:** DECISIONS D-05; `scripts/services/*` interfaces + mocks.
- **DoD:** Game boots and completes the campaign with network disabled; no code path awaits a server.
- **Dependencies:** Phase 4. **Days:** 0.5.

## Phase 6 — Game client and content (M2 slice, M4 full)
- **Activity:** Tutorial (3 steps), level select, board view/input (tap/drag/pinch), hints (3 free/level), undo, restart, progression (2 puzzles → unlock), awakening, creature detail, bestiary, settings, EN/ES; then 24 levels, 12 creatures with layered cut-out art, distinct awakenings, audio buses.
- **Tools:** Godot scenes, AnimationPlayer/Tween, Line2D/CanvasItem drawing, generator with silhouette masks, original SVG/PNG art made in-repo, procedurally synthesised CC0 audio.
- **Risk addressed:** Scope (unfinished content), product (replay motivation), technical (animation quality, memory).
- **Justification / trade-off:** Vertical slice first (1 creature) proves the pipeline before scaling to 12. Art is original layered vector-style illustration produced in-repo (no paid assets); quality is reviewed via screenshots, not claimed.
- **Deliverable:** Playable campaign; `data/levels/*.json` (24), `data/creatures/*.json` (12), `assets/creatures/*`.
- **DoD:** Full campaign completable offline in an automated run; each creature unlocks exactly once; content validation passes for all 24 levels.
- **Dependencies:** Phases 3–5. **Days:** 7–11.

## Phase 7 — Android and monetization integration (M2 export, M3 ads)
- **Activity:** Android export preset (minSdk 26, target/compile 36, arm64 + x86_64 debug), lifecycle save on pause, audio focus; Kotlin Godot plugin wrapping UMP + Google Mobile Ads with child/unknown restricted treatment; reward state machine.
- **Tools:** Godot Android templates 4.7.2, Android SDK/Gradle, Kotlin, Google test ad IDs.
- **Risk addressed:** Technical (callbacks, compat), delivery (signing).
- **Justification / trade-off:** Thin custom plugin keeps audience controls in our hands; mock provider keeps desktop/CI deterministic.
- **Deliverable:** `android/plugins/legend_ads/`, `export_presets.cfg` (no secrets), `docs/ADS_AND_PRIVACY.md`.
- **DoD:** Debug APK installs on emulator; reward state-machine tests cover success, no-fill, offline, early dismiss, duplicate/late callbacks; progress survives kill/relaunch.
- **Dependencies:** Phase 6 slice. **Days:** 2–3.

## Phase 8 — Automated testing and repair (continuous, M1–M5)
- **Activity:** Unit, property (1,000 seeded boards), content, integration and Android E2E tests; reproduce → diagnose → fix → regression test for each failure.
- **Tools:** GUT 9.7.1, `scripts/verify_all.sh`, JUnit gate (`scripts/check_junit.py`), Android emulator instrumentation.
- **Risk addressed:** Technical, delivery.
- **Justification / trade-off:** One wrapper locally and in CI means "green" means the same thing everywhere. GDScript has no reliable line-coverage tool, so a requirements→tests matrix is delivered instead of an invented percentage.
- **Deliverable:** `tests/**`, `docs/QA_REPORT.md`, `docs/TEST_MATRIX.md`.
- **DoD:** All required tests pass on the final revision with JUnit evidence; empty discovery, pending and assertion-free tests fail the gate.
- **Dependencies:** Phases 4–7. **Days:** 2–3.

## Phase 9 — GitHub, CI/CD and release preparation (M0, M5, M6)
- **Activity:** Pinned GitHub Actions (SHA-pinned actions, minimal permissions): import/script check, tests, content validation, Kotlin tests/lint, debug APK export, emulator smoke suite, artifact upload; separate scheduled heavy matrix; AAB + checksums.
- **Tools:** GitHub Actions, Godot headless export, Gradle, `reactivecircus`-style emulator runner (pinned), `bundletool`.
- **Risk addressed:** Delivery.
- **Justification / trade-off:** Fast job on every push; heavy emulator matrix on schedule/manual to save minutes.
- **Deliverable:** `.github/workflows/ci.yml`, `.github/workflows/android-matrix.yml`, `docs/RELEASE_CHECKLIST.md`, `BUILDING.md`.
- **DoD:** Final commit has a green required run with downloadable APK/AAB + reports; external publication prerequisites listed explicitly.
- **Dependencies:** Phases 7–8. **Days:** 1.5–2.

## Phase 10 — Monitoring and post-launch readiness (M6)
- **Activity:** Local diagnostics log (sanitised, rotating), crash investigation guide (Play Console vitals + `adb logcat`), content update and rollback procedure (corrective release with higher versionCode + save migration).
- **Tools:** Godot logging, Play Console (owner), `scripts/measure_device.sh`.
- **Risk addressed:** Delivery, product.
- **Justification / trade-off:** External telemetry stays off (mixed-age audience); local logs + Play vitals are enough for v1.
- **Deliverable:** `docs/OPERATIONS.md`, `scripts/measure_device.sh`.
- **DoD:** Handoff explains how to diagnose failures, reproduce builds, restore save compatibility and ship a corrective release.
- **Dependencies:** Phase 9. **Days:** 0.5.

## Milestone map
- **M0** (Phases 1, 2-doc, 4-skeleton, 5-doc, 9-CI): skeleton, pinned runner, verify_all, CI. ✅ see PROGRESS.
- **M1** (Phase 4, 8): pure model, solver, validator, generator, property tests. ✅ see PROGRESS.
- **M2** (Phases 3, 6-slice, 7-export): vertical slice + debug APK. ✅ locally (CI run pending GitHub write access) — see PROGRESS.
- **M3** (Phase 5 interfaces, 7 ads/consent). ✅ CI green — see PROGRESS.
- **M4** (Phase 6 full content). ✅ CI green — see PROGRESS.
- **M5** (Phases 8, 9 E2E/emulator).
- **M6** (Phases 9 release, 10).
