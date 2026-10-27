# Art and animation

## Approach (D-33)
Every creature is a **layered cut-out rig built in code**: `Polygon2D` fills with ink outlines and `Line2D` strokes, parented to pivot nodes (head, neck, torso, wings, legs, tail, plus mist/specks props). Nothing is a single sticker: parts rotate and scale about anatomical pivots. Rigs render inside a `SubViewport` stage (`CreatureStage`) so fades apply to the whole creature at once (no see-through overlaps).

Shared skeletons, as the spec allows for matching anatomy:
- `DrakeRig`: forest drake, wyvern (wings are its arms), arctic drake, ancient dragon
- `QuadrupedRig`: antler fox, unicorn, basilisk, griffin
- `SerpentRig` (segment chain): cloud serpent, stone wyrm
- Bespoke: moon owl, phoenix

Palette: muted greys and slate blues on warm off-white (mockups); the phoenix gets the only warm accent, desaturated and limited to its tips and crest.

**Quality statement:** this is stylised procedural placeholder art, consistent with the mockups' palette and silhouettes, not final illustration. A human art pass (or commissioned layered art dropped into the same rig structure) is recommended before store marketing.

## Awakening timeline (~5 s, `CreatureRig.awaken`)
| Time | Phase |
|---|---|
| 0.0–1.2 s | faint silhouette gathers (grey, 45% opacity) |
| 1.2–2.0 s | full form resolves |
| 2.0–~5 s | creature-specific signature move (and its sound motif) |
| end | settles into idle loops (breathing, blinking, small sway) |

Skip appears after 1 s; reduced motion replaces the whole sequence with a 0.6 s fade into the final pose and no idle loops.

## Signatures
| Creature | Signature |
|---|---|
| Forest Drake | unfolds its wings, raises its head with a silent roar, settles on the rock |
| Moon Owl | opens its wings to full span, swivels its head, settles half open |
| Antler Fox | rises, looks back over its shoulder with a tail sweep, bows its antlers |
| Basilisk | rises on its forelegs, raises its crest, turns its gaze |
| Wyvern | unfolds its wings, beats twice, lifts off the rock and lands |
| Arctic Drake | rises, unfolds its wings, exhales a thin stream of frost |
| Griffin | rears and spreads its wings wide, then folds them |
| Cloud Serpent | uncoils, rises in an S-curve, sends a slow wave down its body |
| Stone Wyrm | emerges from the stone, rears to full height, opens its jaws shaking off dust |
| Unicorn | rears on its hind legs, tosses its mane, lands |
| Phoenix | opens its wings high, sheds pale embers that drift up and fade |
| Ancient Dragon | lowers its head, rises to full height with a slow wide wing spread and a held stare |

Tests: every rig builds with layered parts, its final pose differs from its dormant pose, awaken → skip finishes, idle runs (`test_every_creature_rig_builds_awakens_and_skips`); reduced motion finishes quickly.

## Level silhouettes (D-34)
Each creature's two puzzles are shaped like its final pose: `tools/make_mask.gd` renders the rig, rasterises the silhouette onto the grid (coverage 0.3; thin bodies dilated by one cell) and the generator fills only those cells.

## Audio (D-36)
All sounds and music are synthesised by `tools/make_audio.py` (no samples): soft sine/bell tones, peaks at −6 dBFS, one motif per creature played with its signature, a 32 s ambient pad loop. Buses: Music, SFX, Creature (settings sliders).

## Regenerating
- Strip render of a rig: `tools/render_sheet.sh <creature_id>`
- Masks + levels: `python3 tools/build_content.py [creature_id …]`
- Audio: `python3 tools/make_audio.py`
- Screenshots: CI E2E artifacts; `tools/capture_screens.gd`
