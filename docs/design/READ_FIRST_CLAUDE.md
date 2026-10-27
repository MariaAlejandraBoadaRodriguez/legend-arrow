# Visual handoff for Claude

Read Flechas_Bestiary_Android_Development_Spec.md first. These 14 individual PNG screens are visual references, not executable screens, solvable level data, animation assets or final component exports. Implement native Godot UI and layered creature animation; do not use whole-screen images as the interactive UI.

## Binding direction
Ivory-white background #FAF9F6; graphite #25282B; muted slate-blue #47677C. Match the restrained layout, adult fantasy anatomy, readable typography and generous spacing. Only awakening uses a full landscape. Preserve guest play, no email and optional ads. Use the specification for behavior when an image differs.

## Screen index
- 01_home.png
- 02_tutorial.png
- 03_level_selection.png
- 04_puzzle.png
- 05_level_complete.png
- 06_awakening.png
- 07_creature_detail.png
- 08_bestiary.png
- 09_settings.png
- 10_pause.png
- 11_hint_ad.png
- 12_privacy.png
- 13_offline_ad.png
- 14_save_recovery.png

## Flow
Home → tutorial on first play → level selection → puzzle → first-puzzle completion → second puzzle → awakening → creature detail → bestiary → next challenge. Settings and pause are secondary routes. Hint advertising is an optional sheet; unavailability returns to play. Privacy preferences open the actual SDK-managed form when applicable. Recovery appears only after a verified successful backup restore.

## Implementation corrections that take precedence over concept pixels
- Tutorial image illustrates step 1; implement all three tutorial steps from the specification. Do not display a creature illustration over the playable tutorial board.
- Puzzle arrows must be disjoint orthogonal grid paths with one arrowhead per path. Generated concept images sometimes contain curves, diagonal tips or extra arrowheads. Do not trace those errors. Generate and solver-validate actual levels using full swept-body collisions.
- Use three realms only: Mistwood, Cloud Peaks and Ancient Highlands. Ignore the extra Sunspire tab in the selection concept and normalize Highlands to Ancient Highlands. Populate each realm consistently from game metadata; sample cards do not establish final realm membership.
- Standardize the title to Flechas: Bestiary, including the recovery background where the concept says Arrows.
- Some overlays show Level 12 while the main board shows Puzzle 2 of 2. Derive all labels from actual level metadata and preserve the same board behind every modal.
- Progress values are example states, not a single simultaneous save. There are 12 collectible creatures and 24 campaign levels.
- Awakening is a static keyframe reference. Build a real 4–6 second sequence with wing, head and tail motion, subtle mist, skip, replay and reduced-motion behavior. Show Continue at the end; show Skip only while animation is playing.
- Privacy mockup is an app information page, not a replacement for Google UMP or required consent text. Keep the production privacy layout text-focused; dragon art is optional and may be omitted.
- Keep Retry secondary and rate-limited on ad failure; no automatic retry loop.
- Additional loading, blocked-move, hint-highlight and consent SDK states reuse these visual tokens; do not introduce a new visual theme.

## Implementation instruction
Implement these screens together with the development specification. Resolve routine inconsistencies autonomously according to the written rules, build the APK, execute tests, fix failures and report evidence. Do not claim that static screenshots prove functional correctness.
