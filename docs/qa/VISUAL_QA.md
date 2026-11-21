# Visual QA — screen matrix (v0.2 §9.4)

**What:** every screen of the real app, captured at each device profile with the system bars drawn over it, so anything hidden under the status bar, camera cutout or navigation/gesture bar shows up.

**Files:** 20 screens × 7 profiles in `docs/qa/screens/<profile>/NN_screen.png`, plus the overview `docs/qa/screen_matrix.png` (rows = screens, columns = profiles). CI rebuilds them on every push; the CI artifact is named **screen-matrix**.

**How:**

```bash
GODOT=/path/to/godot scripts/screen_matrix.sh
```

`scripts/screen_matrix.sh` runs `tools/capture_matrix.gd` once per profile under Xvfb. The script fails if any profile does not have exactly 20 screens. `tools/screen_matrix.py` then builds the overview and stores all PNGs with 256 colours (enough to judge layout, not colour fidelity).

**Profiles** (from the v0.2 prompt §8 and D-41). The insets are the simulated system UI in px.

| Profile | Device class | Window | Density (dpi) | Text | System UI |
|---|---|---|---|---|---|
| P1 | small phone | 720×1280 | 320 | 1.0 | status 48, 3-button nav 96 |
| P2 | standard phone | 1080×1920 | 420 | 1.0 | status 63, gesture bar 63 |
| P3 | tall phone | 1080×2400 | 420 | 1.0 | status 128 with punch-hole camera, gesture bar 63 |
| P4 | very tall phone | 1080×2640 | 440 | 1.0 | status 145 with notch, gesture bar 66 |
| P5 | 7" tablet | 1200×1920 | 320 | 1.0 | status 48, nav 96 |
| P6 | 10–11" tablet (like the owner's Lenovo) | 1600×2560 | 320 | 1.0 | status 48, nav 96 |
| P7 | P2 with Larger text | 1080×1920 | 420 | 1.3 | as P2 |

## Screens

01 Home · 02–04 Tutorial steps 1–3 · 05 World select · 06 Level select (World 3, with stars and times) · 07 Puzzle, largest board (Ancient Dragon, World 10) · 08 Blocked move (red flash) · 09 Hint highlight · 10 Pause · 11 Hint/ad sheet · 12 Ad unavailable · 13 Results (3 stars, new record) · 14 Awakening start · 15 Awakening end · 16 Bestiary · 17 Creature detail · 18 Settings · 19 Save-recovery message · 20 "Storage full" message over a puzzle (0.2.1).

## Review (screenshots of commit with this file)

| Check | Result | Notes |
|---|---|---|
| Nothing under status bar, cutout or notch (P3, P4) | PASS | The safe area pushes every screen below the bar. Back buttons, titles and the pause button are fully visible. |
| Nothing under the navigation/gesture bar | PASS | The bottom buttons (Undo/Hint/Restart, Continue, Play) sit above the bar on all profiles. |
| Text clipped or overlapping | **FIXED → PASS** | P7 level select: the title "World 3 · Riverstone Gorge" ran into the "Worlds" link and the back button stretched tall. `Ui.top_bar` now keeps an 8 px gap and the side buttons keep their size. Recaptured; the title wraps cleanly. |
| Larger text (P7) | PASS | Titles, captions, sheet text and bestiary names wrap and do not clip. The Settings list scrolls. |
| Touch size of arrows on big boards | PASS (by design) | On P1, P2, P7 and P5 the 41–60-arrow World 10 board opens zoomed so each cell is ≥ 40 dp (48 dp touch band, D-48), and you pan to reach the rest. On P6 the whole board fits. |
| Dialogs and sheets (pause, hint, no-ad, save restored) | PASS | Centred and readable on every profile, with the dimmed board behind. |
| Results, awakening, creature detail | PASS | The photoreal art is not cropped (the overview cuts rows at fixed heights; the single screenshots show the full image). |
| Tablets (P5, P6) | PASS | Content is centred with a 900 px max width; there are no stretched buttons. The bestiary shows 3 columns. |
| Very tall phones (P3, P4) | PASS | The extra height becomes empty space or a larger board area, not stretched controls. |

| "Storage full" message (20, 0.2.1) | PASS | Sits under the screen header on every profile, so back, title and pause stay visible; wraps on P1 and P7 without clipping; dark panel with white text in the game font. It never takes input. |

Open items: none for layout. Colour, animation and feel on a real screen remain **BLOCKED** on the owner's Lenovo tablet run (`docs/DEVICE_TEST.md`).
