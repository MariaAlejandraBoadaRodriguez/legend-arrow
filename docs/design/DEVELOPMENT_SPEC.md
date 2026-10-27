# Flechas: Bestiary — Android Development Specification

Version: 1.0 | Prepared: October 24, 2026 | Deliverable language: English

## 1. Execution mandate for Claude

Build a complete, installable Android puzzle game from this specification. Act as the developer, technical artist, test engineer and debugger. Do not stop after planning, scaffolding or creating a visual demo. Implement, build, test, inspect, fix and verify the final result.

Make routine engineering and design decisions autonomously. Do not ask the owner to choose dependencies, approve ordinary fixes, debug errors or resolve implementation details. When an approach fails, diagnose it, use a compatible alternative and continue. Preserve the scope and quality gates. Never disable a failing test, weaken an assertion or hide a defect to report success.

Missing production credentials, paid assets, release signing keys or unavailable hardware must not block independent development. Use test ads, original assets, debug signing and available emulators. Record genuine external blockers in the final handoff; do not invent credentials, test results or device measurements. Publishing, spending money and creating external accounts are outside this development mandate. Deliver everything that can be completed without them.

This document specifies work to perform; it does not claim that a game or its tests already exist.

## 2. Product and audience

Working title: **Flechas: Bestiary**. A calm, elegant arrow puzzle game in which players release fantasy creatures and collect them in a bestiary. Android first, portrait orientation, immediate guest play, no email, password, account, social login or mandatory cloud service. Core content works offline. Progress saves automatically on the device.

A ten-year-old must understand the rules; a thirty-year-old should enjoy the visual tone and challenge. Use plain language, mature naturalistic fantasy creatures and uncluttered interfaces. Avoid baby talk, cartoon baby dragons, ornate fantasy UI, rainbow palettes and childish reward overload. Include English and Spanish UI from external string resources; default to device language with an in-game language setting. All engineering documentation remains English.

## 3. Game engine and architecture

Use a current stable **Godot 4.x** release with **GDScript**, the Compatibility renderer and matching Android export templates. Pin the exact tested version; do not use preview builds or floating dependencies. Godot is selected for its 2D tooling, lightweight scene workflow, animation system and Android export. Use a small Kotlin Android plugin for Google Mobile Ads and UMP if an audited maintained compatible plugin does not satisfy all requirements. Keep a mock ad provider for tests and desktop runs.

Use separate modules: pure puzzle model; solver and level validator; board view and input; progression; save repository; creature animation; audio; platform bridge; ads; consent; event logging. Use signals and injected interfaces rather than placing all behavior in one script. Puzzle rules must run headlessly without rendering or network access. Ad callbacks must never directly manipulate scene nodes that may have been freed.

No backend, multiplayer, account system, leaderboard, energy timer, loot boxes or AI inference at runtime in version 1.

## 4. Core rules: precise arrow mechanics

A puzzle is a finite integer grid containing disjoint orthogonal paths. Each path is one arrow with exactly one arrowhead at its final cell. Consecutive cells differ by one horizontal or vertical unit. The final segment defines the exit direction. Curves in concept art are aesthetic references only: shipping paths use clear orthogonal geometry and predictable rules.

When tapped, the entire arrow translates rigidly in its head direction until every occupied cell is outside the board. It can leave only if this complete swept motion never intersects any cell of another arrow. Ignore its own cells during collision checks. Do not merely check the ray in front of its head: all body cells sweep forward too. The model evaluates discrete one-cell translation steps until the full arrow exits; the view interpolates that validated motion smoothly.

A legal tap locks input for that arrow, plays its exit animation, commits removal once, and contributes magic to the creature reveal. Other board input is disabled during this brief move to avoid race conditions. A blocked tap moves nothing permanently, gives a gentle visual pulse and says “Clear another arrow first.” No life loss, forced restart or ad penalty. There is no timer. Completion requires zero arrows remaining.

A hint highlights one currently removable arrow. Undo restores exactly the previous removed arrow and prior progress; it cannot undo a completed level reward or duplicate a collectible. Restart restores the level without revoking already earned collection items. Replaying a completed level is allowed but grants no duplicate first-completion reward.

### First-session instructions

Use a three-step interactive tutorial with at most one short sentence per step:
1. “Tap an arrow with a clear way out.”
2. “Clear other arrows to open a path.”
3. “Release every arrow to awaken the creature.”

Demonstrate a legal move, a harmless blocked move and completion. Do not require reading a long instruction page. Tutorial is replayable from settings.

## 5. Level data, generation and solvability

Store levels as versioned JSON resources: schema version, unique level ID, creature ID, difficulty, grid width/height, ordered paths with stable IDs, and certified solution order. Store creature metadata separately: localized name, realm, art resource, animation resource, silhouette, unlock condition and credits.

Validate bounds, orthogonal adjacency, path length of at least two cells, unique cells within each path, no overlap between paths, unique IDs and a valid final direction. Generate deterministic levels offline with fixed seeds and a reverse-construction or rejection method backed by the exact swept-body solver. Save generated content as packaged JSON; do not ask players to wait for generation.

For every shipped level, simulate its complete recorded solution. Explore all reachable states for small levels. Under these removal-only rules, removal cannot introduce a new collision; verify this monotonicity property in tests. Never ship a board with no legal move unless it is already empty. Content must visibly resemble the intended creature without sacrificing hit targets or solvability. Evaluate silhouette readability visually; procedural generation alone does not certify art quality.

Difficulty is determined by arrow count, path length, simultaneous available exits and dependency depth, not color or misleading labels. Provisional bands: easy 6–12 arrows, medium 13–24, hard 25–40, expert 41–60. Tune through playtesting. Larger boards must offer zoom and pan; never shrink paths below usable touch size.

## 6. Scope and content

Deliver 24 polished launch levels across 12 collectible original creatures, two distinct puzzles per creature. The second puzzle completes its awakening and unlocks it. First tutorial creature uses two very short levels. Persist partial creature progress clearly as “1 of 2 puzzles”. One creature is never shown unlocked before its condition is met.

Creature roster: Forest Drake, Moon Owl, Antler Fox, Wyvern, Basilisk, Arctic Drake, Griffin, Cloud Serpent, Stone Wyrm, Unicorn, Phoenix and Ancient Dragon. Start with simple shapes and increase complexity. Three realms: Mistwood, Cloud Peaks and Ancient Highlands. Realms appear as restrained headings and small environment thumbnails, not busy gameplay backdrops.

All 12 creatures need final usable art, distinct awakening animations and ambient collection motion. First complete a vertical slice with one creature and two levels, then expand to the full roster. Do not substitute permanent placeholders for the final scope. Use original layered illustration assets or properly licensed assets with recorded provenance; do not copy franchise creatures. A supplied reference image guides atmosphere/anatomy, not asset ownership.

## 7. Screens and game loops

Screens: Home, interactive tutorial, realm/level selection, puzzle, awakening, creature detail, bestiary and settings. Include loading, consent, unavailable-ad and save-recovery states.

Moment loop: inspect board → tap → exit or blocked feedback → identify newly opened routes.

Level loop: finish puzzle → persist result → update creature progress → show awakening only on unlock → next challenge.

Collection loop: solve two creature puzzles → collect creature → inspect/replay animation → unlock the next creature. Reveal the next locked silhouette without pressure or countdowns.

Optional daily challenge uses packaged validated levels, a deterministic date-to-level mapping and local progress. It must not replace or block the campaign; no streak penalties, notifications or time-limited collectibles. Clock changes must not corrupt campaign progress or duplicate rewards. Identify this as a local daily challenge, not server-verified competition.

Persist completion before displaying any reward advertisement. Android Back pauses during play, closes overlays first, and returns to the previous screen without losing progress. Returning from an ad restores the exact prior context.

## 8. Graphics and colorimetry — binding white-background direction

The approved direction is the restrained white/ivory mockup. Prior colorful magical screens are rejected. Use the following sRGB design tokens consistently:

| Token | Hex | Purpose |
|---|---|---|
| Background | #FAF9F6 | Main ivory-white surface |
| Card | #F0EFEB | Quiet collection surfaces |
| Ink | #25282B | Text and puzzle arrows |
| Secondary text | #62686D | Supporting labels |
| Accent | #47677C | Active arrow, progress and primary actions |
| Grid | #D9D8D2 | Decorative dot grid only |
| Focus | #244A63 | Keyboard/controller focus outline |
| Error | #8A4E48 | Brief blocked-move feedback, accompanied by motion/text |

Keep approximately 85–90% of gameplay surfaces neutral. Never encode legality or rarity only by hue. Validate text contrast at WCAG AA thresholds; adjust tokens if required. Decorative grid dots must not be the sole instruction or interactive boundary. Use white text only on a tested sufficiently dark button.

Use one readable sans serif family, two weights and generous spacing. Text should remain readable at enlarged Android font settings. Essential touch controls must be at least 48 dp after density conversion. No ornate borders, gold framing, neon glows, glitter clouds, saturated gems or confetti storms.

Creature illustrations use natural graphite, stone, bone, gray-green and slate-blue tones. A phoenix may have a small desaturated warm highlight; do not turn the whole screen orange. Background detail stays absent during puzzles. Only the awakening scene may briefly show a misty landscape. Portrait art and controls must fit notches, gesture areas and tablets.

## 9. Animation

Use Godot AnimationPlayer, Tween and 2D layered skeletal/cutout animation. The shipping game is primarily 2D; full 3D is not required to achieve expressive movement. Split creature art into sensible head, torso, wing, tail, limb and mist layers. Avoid visibly sliding rigid stickers or stretching anatomy. Reusable rigs are permitted when anatomy matches; each creature needs a distinct action and silhouette.

Arrow exits last about 200–400 ms, using predictable easing. Blocked feedback lasts about 150 ms with no screen shake by default. On the final unlock, the arrow trails gather into a faint silhouette; the creature forms, performs a signature movement, then settles into an idle pose.

Awakening target: 4–6 seconds, skippable after the first second and replayable from the bestiary. Examples: wyvern unfolds wings and lifts off; basilisk rises and turns its gaze; arctic drake exhales thin frost; phoenix opens wings and sheds a few pale embers. Spectacle comes from silhouette, scale, motion, timing and audio. Use restrained white rim light and bounded particles instead of saturated flashes.

Provide reduced-motion mode: short dissolve plus final creature pose, no camera movement or rapid flashes. Bestiary detail loops include subtle breathing, blinking and tail motion. Grid thumbnails remain still to reduce distraction and resource use. If skipped, interrupted, backgrounded or replayed, an awakening cannot grant a duplicate unlock.

## 10. Sound

Use three independently controlled buses: music, effects and creature audio; persist mute/volume preferences. Provide quiet atmospheric music with seamless loops; tactile arrow clicks; soft exit sounds; gentle blocked feedback; and a short creature signature. Avoid startling volume jumps or repetitive loud roars. Limit simultaneous voices and test speaker/headphone output for clipping.

Pause or duck game audio before a full-screen ad and on loss of audio focus. Restore only if the app is active and preferences allow it. Essential game information must be visible without sound. Haptics are optional and can be disabled; use brief effects only when supported. No microphone permission.

## 11. IDE, Android SDK and NDK

Use the Godot editor for scenes and GDScript; Android Studio for SDK management, Kotlin bridge, Gradle builds, emulators and Android profiling. Install the JDK recommended by the chosen stable Godot documentation (currently JDK 17 in the consulted stable export guide); pin compatible Gradle and Android Gradle Plugin versions.

Use compileSdk and targetSdk at least API 36 for this October 2026 baseline, and recheck the current Google Play requirement before packaging. Provisional minSdk: API 26 (Android 8.0), raised only if a verified engine/ad dependency requires it; document the final resolved value. Prefer ARM64 production builds; include an x86_64 debug/emulator configuration when supported by the selected export templates.

Ordinary GDScript export uses prebuilt engine templates; it does not require writing C++. Install a matching NDK only when the build or native dependency requires it. Verify all bundled native libraries and the final bundle satisfy applicable 64-bit and 16 KB page-size requirements; do not assume a Kotlin bridge eliminates native engine requirements. Record exact resolved toolchain versions and artifact checks in BUILDING.md.

## 12. Graphics APIs and rendering

Use Compatibility rendering, normally OpenGL ES 3.0 on Android. Do not require Vulkan, Forward+ features or custom native rendering. Use CanvasItem drawing/Line2D for arrows, lightweight Sprite2D layers for creatures, and limited particles. Avoid a full-screen shader stack or real-time 3D environments.

Target 60 FPS in puzzles; allow stable 30 FPS for cinematic effects on the low-quality tier. Scale effects automatically or via settings without changing puzzle rules. Provide a conservative mode with fewer particles and no expensive post-processing. Profile on actual Android builds, not only the editor.

## 13. Input system and device compatibility

Use one action abstraction for touch, mouse, keyboard and controller. Primary input is single-finger tap. Calculate hit tests in board coordinates after inverse camera transform, with padded path hit areas. Resolve ambiguous taps consistently to the nearest visible path within the threshold; do not select through modal overlays.

Support pinch zoom and two-finger pan for dense boards. Distinguish tap from drag using movement thresholds; canceled touches, interrupted gestures and multitouch must not trigger moves. Desktop mouse click/wheel/pan supports development. Keyboard and controller provide visible focus, directional path selection, confirm, back, hint and undo. Android system Back must work correctly.

Test narrow phones, tall phones and tablets. Keep portrait gameplay but handle lifecycle/configuration recreation safely. Respect display cutouts, system bars and large font settings. Critical controls cannot overlap ads, gesture areas or the board.

## 14. Resources, performance and memory

Use on-demand scene loading, import compression appropriate to art, texture atlases where useful and explicit ownership of loaded assets. Keep only the current creature's full animation resident; collection tiles use small cached thumbnails. Release old animation/audio resources when leaving detail scenes. Avoid loading all creatures at startup.

Provisional measurable budgets on a named 3 GB RAM low-tier test phone: cold offline launch to usable Home within 5 seconds; puzzle frame time p95 <= 16.7 ms at 60 Hz; cinematic frame time p95 <= 33.3 ms in low tier; total process PSS <= 300 MB during a typical puzzle including initialized ad SDK, and <= 400 MB at awakening peak. Record device, Android version, sample duration and ad state. These are acceptance targets, not preclaimed measurements.

After 20 level/detail transitions, memory must settle within 10% of the comparable warmed baseline and show no unbounded growth. Initial packaged download goal <= 120 MB, measured separately for APK and device-specific bundle delivery where available. If exceeded, compress/downscale/reuse assets without removing required creatures. No synchronous network or large resource import on the main input path.

## 15. Save data and lifecycle

Use versioned local saves with atomic temp-file replacement and a last-known-good backup. Persist removed arrow IDs, undo history, level/creature progress, unique reward transactions, settings, tutorial status, ad reward receipts and campaign schema version. Validate on load and migrate older schemas. Corrupt saves recover from backup with a clear short message; never silently erase valid progress.

Save immediately after committed moves and unlocks, and on lifecycle pause. A process kill during a write must recover to the previous or current complete transaction, never a half-unlocked creature. Exclude diagnostic advertising identifiers and sensitive consent details from ordinary game saves. Decide explicitly whether Android backup is enabled; document limitations. No claim of cross-device sync or guaranteed uninstall recovery.

## 16. Advertising monetization

Use Google AdMob through an isolated AdService interface. Version 1 has rewarded ads and conservative optional interstitial placement; no banner on gameplay, no app-open ads and no ad during creature awakening.

Rewarded placement: the user explicitly chooses “Watch an ad for a hint.” Clearly state the reward before showing. Hints also have a free gameplay path: give three free hints per level and allow unlimited free restart/undo. An ad can provide an additional hint; no ad is required to complete or collect any creature. Do not add a coins economy merely to justify ad views.

Interstitial eligibility: only after a completed level reward/reveal flow, before the next level, never on first launch, tutorial, failure, back/exit or resume. Initial cap: at least five completed non-tutorial levels between displays and at least 180 seconds since the last full-screen ad of any kind; do not show immediately after a rewarded ad. Disable interstitials for child/unknown treatment in this initial implementation. Campaign progress never waits for an ad request. Frequency is configurable within hard-coded maximum limits.

Reward state machine: idle → loading → ready → showing → rewarded/dismissed/failed. Grant the promised hint only from the SDK earned-reward callback, exactly once per presentation ID. Persist the receipt and entitlement atomically. Dismissal, load failure or loss of network must not grant false rewards or consume a free hint. Duplicate and late callbacks must be harmless. If the player leaves the screen after earning a reward, retain the hint entitlement for the next valid board. Disable repeat taps while loading/showing.

Use official test app/ad IDs in development and CI. Never request live ads in automated tests or click real ads. Release configuration must reject test IDs, absent consent configuration or missing app IDs without embedding secrets. Debug builds remain usable with mocks if SDK services are unavailable.

Ads require an internet connection; the campaign does not. Show “No ad available. You can keep playing.” on no-fill/failure. Do not loop retries aggressively or promise ad revenue.

## 17. Platform services, privacy and LiveOps

Because the intended audience includes children and adults, implement child-safe ad handling rather than treating everyone as an adult. Default unknown users to restrictive child/unknown ad treatment. No account or exact birthdate is needed for guest play. If a neutral age-band flow is required by the final configuration, store only the minimum local band and explain its purpose. Never use an age screen to encourage users to claim adulthood.

Integrate Google's UMP consent flow for applicable regions; request updated consent information at launch and check whether ads may be requested before initializing requests. Prevent duplicate initialization. Provide the required privacy-options entry in settings. Consent refusal or offline consent checks must not block gameplay. UMP is not a substitute for child-directed treatment. Use appropriate child/under-age flags, non-personalized/restricted handling and compliant certified ad sources for children/unknown audiences. Confirm current Families and ad-format requirements before release; if a format cannot comply, disable it for that audience. Do not evade the audience declaration to improve monetization.

Permissions: internet/network state as needed for ads; optional vibration. No contacts, location, camera, microphone or broad storage. Audit merged manifests and SDK data collection. Supply a privacy-policy draft and Data Safety inventory that match the actual SDK versions, including ad collection; no-account does not mean no SDK data collection. Public policy hosting and store declarations are release handoff items.

Version 1 LiveOps is packaged data plus the optional local daily challenge. Define an optional remote configuration interface but do not require a backend. Remote values may only reduce ad pressure or adjust safe existing limits, never download executable code or make an offline game unusable. New content ships through validated app updates initially.

Define events locally: tutorial_complete, level_start, blocked_tap, level_complete, creature_unlock, hint_requested, ad_result and save_recovery. Unit tests use an in-memory sink; production upload analytics is off by default until a documented audience/consent configuration permits it. Never record names, email, exact age, raw identifiers or puzzle tap streams unnecessarily. No notification permission in version 1.

## 18. Development sequence — execute to completion

1. Inspect repository and preserve unrelated files. If empty, create a self-contained project and README. Record exact toolchain and decisions.
2. Implement pure puzzle model, swept collision checks, deterministic solver and schema validator. Add meaningful tests before expanding content.
3. Build vertical slice: tutorial, two levels, one creature, collection, local saves and settings, with real representative art and awakening.
4. Export and run an Android debug APK early; resolve compatibility and lifecycle issues before scaling content.
5. Implement native ad/consent bridge with mock provider, callback tests, error handling and child-safe configuration.
6. Produce full roster, 24 validated levels, English/Spanish strings, final audio and distinct animations. Perform visual review on Android-sized screens.
7. Run the complete validation pipeline; fix every reproducible failure, rebuild and rerun affected checks plus the final required suite.
8. Package source, APK, AAB/build outputs where available, logs, validation report and release handoff. Do not stop with “next steps” that are development tasks you can perform yourself.

## 19. Required tests and verification

Provide one documented command (for example scripts/verify_all.sh) that fails nonzero when a required automated check fails. Pin a compatible GDScript test runner and Kotlin test tooling. Include deterministic seeds and machine-readable results. Keep pure model tests independent of the Android SDK.

| Area | Required evidence |
|---|---|
| Puzzle rules | Legal exits in four directions; body-sweep collisions including a clear head but blocked body; off-board completion; bent arrows; blocked tap leaves state unchanged |
| Generator/content | All 24 schemas valid; unique paths and cells; each full recorded solution succeeds; empty-board edge case; 1,000 deterministic generated test boards checked for solvability |
| Properties | Removing an arrow cannot create a blocker; legal choices cannot create deadlocks in the removal-only model; serialization round trips preserve state |
| Undo/restart | Exact restoration; repeated taps; undo after hint; restart after partial progress; no duplicate completion or unlock |
| Progress/save | Two-level unlock condition; replay idempotency; atomic-write interruption; corrupt backup recovery; schema migration; kill/relaunch mid-level and during reveal |
| Ads | Mock success, no-fill, offline, failure, early dismiss, duplicate reward callback, late callback, activity recreation, navigation away, cooldown and cap boundaries |
| Consent | Unknown/child restriction; ads blocked when not permitted; refusal does not block game; privacy settings; no duplicate requests |
| UI/input | Tutorial to collection end-to-end; tap/drag separation; zoom coordinate conversion; overlay input blocking; keyboard/controller focus; Back navigation; safe-area and font-scale checks |
| Animation/audio | Every creature unlocks, skips and replays; reduced motion; mute persistence; pause/resume and ad audio focus; no duplicate rewards |
| Android build | Clean import, script parsing, unit/integration tests, Kotlin tests/lint where applicable, debug export and installation, AAB validation, ABI/native library inspection |
| Runtime/performance | Named emulator and available physical device runs; frame-time/memory evidence; 20-transition stress pass; offline cold start; 30-minute play soak |

Android matrix: API 26/minimum-supported emulator; an intermediate Android version; and API 36/current target emulator. Test on at least one actual low/mid-tier phone when available; emulators do not establish real-device performance. Include x86_64 emulator and ARM64 device coverage where available. If no physical phone is accessible, mark those checks BLOCKED and deliver a reproducible measurement script; never mark them PASS.

Automate scene navigation and capture screenshots at phone/tablet sizes. Inspect screenshots for clipping, excessive saturation, unreadable paths, missing art, distorted creatures and distracting backgrounds. A visual snapshot alone does not establish functional correctness. Compare final screenshots to the white-background art direction, not the rejected colorful mockup.

## 20. Autonomous repair and truthful completion gate

For every failure: reproduce → inspect logs/state → identify root cause → implement fix → add a focused regression test when warranted → rerun that check → rerun the complete required suite on final source. Continue without asking the owner to debug or approve routine corrections. Do not arbitrarily stop after a fixed number of repair attempts. If an actual environment limitation prevents a check, continue all independent work and record the limitation precisely.

Report every required check as PASS, FAIL, BLOCKED or NOT RUN. PASS requires an executed check, actual expected assertions and evidence. Skipped, blocked and unexecuted checks are not passes. Any failed test makes its containing gate fail even if the process returns zero. Ensure the test wrapper propagates failures and detects empty test discovery. A smaller passing subset is not “all tests passed.”

The final QA report must contain source revision/hash, exact commands, environment and tool versions, date, discovered/passed/failed/skipped test counts, exit codes, seeds, artifact paths and unresolved limitations. If all executable required checks pass but physical-device or production checks are blocked, say “Automated checks passed; release verification incomplete” and list blockers. Claim release readiness only when all required release gates have passed on the final build.

## 21. Acceptance criteria

- Fresh Android installation starts guest play without an account or email.
- A first-time player can learn the three rules through interaction and complete the tutorial.
- All 24 levels are solvable under the implemented swept-body rules.
- All 12 creatures have coherent puzzle silhouettes, final artwork, signature awakening and bestiary detail motion.
- Every creature is earnable without ads, payment or internet.
- White/ivory art direction, readable controls and restrained color hold throughout.
- Save/load, interruption, offline mode and duplicate callbacks never lose valid progress or duplicate rewards.
- Ad placement obeys consent, audience restrictions, cooldowns and explicit rewarded opt-in.
- Final source builds reproducibly and required checks have honest, reviewable evidence.
- There are no remaining actionable development/test failures concealed as future work.

## 22. Required delivery structure

Deliver a Git-ready source project containing project.godot; scenes/; scripts/; data/levels/; data/creatures/; assets/; locales/; android/ plugin sources; tests/; tools/ level validator/generator; scripts/ build/test wrappers; export presets without signing secrets; pinned dependency metadata; CI workflow; and docs/.

Documentation: README.md (run and play); BUILDING.md (exact versions/commands); ARCHITECTURE.md; LEVEL_FORMAT.md; ART_AND_ANIMATION.md; ADS_AND_PRIVACY.md; QA_REPORT.md; RELEASE_CHECKLIST.md; and THIRD_PARTY_NOTICES.md with per-asset source/license. Include representative screenshots and a short captured gameplay/awakening video when capture tools are available.

Provide an installable debug APK and SHA-256 checksum. Produce an AAB if the toolchain permits; clearly label unsigned/test artifacts. Production signing and real AdMob identifiers remain owner-supplied external configuration, not fabricated values. Include exact final release commands and separate genuine account/signing/hosting blockers from completed implementation. Do not publish automatically.

## 23. Primary technical references

Consult these official documents during implementation and record the versions actually used; requirements can change:

- Godot Android export: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html
- Godot rendering: https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html
- Godot system requirements: https://docs.godotengine.org/en/stable/about/system_requirements.html
- Android target SDK: https://developer.android.com/google/play/requirements/target-sdk
- Android page sizes: https://developer.android.com/guide/practices/page-sizes
- AdMob Android SDK: https://developers.google.com/admob/android/quick-start
- AdMob rewarded ads: https://developers.google.com/admob/android/rewarded
- UMP privacy: https://developers.google.com/admob/android/privacy
- Ad targeting settings: https://developers.google.com/admob/android/targeting
- Families ad requirements: https://support.google.com/admob/answer/6223431

## 24. Start instruction

Begin implementation now. Make the routine decisions yourself. Deliver the functioning Android game, all requested content, test evidence and corrected final build. Do not return only a plan, a mockup, pseudocode or a request for permission to continue ordinary development.
