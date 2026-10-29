# Google Play listing graphics

Rebuilt with `tools/make_store_graphics.sh`; the script also checks each file against Play's size and format rules.

| File | Play Console slot | Format | Source |
|---|---|---|---|
| `icon_512.png` | App icon | 512×512, 32-bit PNG, opaque | launcher icon artwork (`tools/make_icons.py`), same as the in-app launcher icon |
| `feature_graphic.png` | Feature graphic | 1024×500, 24-bit PNG | Godot render of the awakening backdrop + Forest Drake rig, title in Inter |
| `phone_1_home.png` | Phone screenshot 1 | 1080×1920, 24-bit PNG | running game, Home |
| `phone_2_puzzle.png` | Phone screenshot 2 | 1080×1920, 24-bit PNG | running game, Griffin puzzle 1 with a hint |
| `phone_3_awakening.png` | Phone screenshot 3 | 1080×1920, 24-bit PNG | running game, Forest Drake awakening (~3 s in) |
| `phone_4_bestiary.png` | Phone screenshot 4 | 1080×1920, 24-bit PNG | running game, Bestiary with all 12 creatures (unlocked through the real progression rules) |

The screenshots are unedited frames of the game (`tools/capture_store.gd`): no added captions, device frames or mock-ups.
