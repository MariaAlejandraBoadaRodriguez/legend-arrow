# Promo video (Google Play + social)

| File | Use | Format |
|---|---|---|
| `legend_arrow_promo_1920x1080.mp4` | Google Play listing (landscape) | 1920x1080, 30 fps, H.264 High + AAC 48 kHz stereo, 47.1 s |
| `legend_arrow_promo_1080x1920.mp4` | Social media (vertical) | 1080x1920, same codecs and length |
| `legend_arrow_promo_15s_1080x1920.mp4` | Short social cut (vertical) | 1080x1920, 30 fps, H.264 + AAC, 14.9 s, -14 LUFS |
| `legend_arrow_promo_15s_1920x1080.mp4` | Short cut (landscape) | 1920x1080, same |
| `legend_arrow_promo_50s_1920x1080.mp4` | 50-second cut in the 15 s style (landscape) | 1920x1080, 30 fps, H.264 + AAC, 50.6 s, about -14 LUFS |

**50-second cut:** the same style as the 15 s cut (edit-only speed-ups of 1.25–1.6x on the clearing shots, ASMR-processed game effects over the game music), with every scene: dragon reveal, title card, level select, the World 1 board with the blocked tap, first clear, Mossback Drake's awakening, the fast replay with 3 stars and "New record!", World 5/8/10 boards, the bestiary filling up, the Starwing Dragon's awakening, end card.

**15-second cut:** dragon reveal, the World 1 board cleared (one blocked tap included), Mossback Drake's awakening, a fast replay with 3 stars and "New record!", a World 10 board, end card. Two things differ from the game and are edit-only: the arrow-clearing shots play **1.6–2x faster** than real time (the game is not faster), and the sound is the game's own effects (tap, exit, blocked, complete, dragon motif) from a second, identical take with the music muted, processed to sound close and crisp (EQ, compression, a short room reflection), with the game's own music track mixed low underneath.

**Google Play takes a YouTube link, not a file.** Upload the 1920x1080 file to YouTube (public or unlisted, with ads turned off), then paste its URL in Play Console → Grow → Store presence → Main store listing → Video.

## What is in it

Every shot is real in-game footage of the game at commit `7cb66d0` (main), recorded with Godot Movie Maker at a fixed 30 fps in portrait 1080x1920, with the game's own music and sound effects. Nothing is mocked up.

1. **Hook (3 s):** the arrows gather and the Starwing Dragon appears through the mist (its awakening, replayed from the bestiary).
2. **Title card:** "Legend Arrow" and the app icon (`assets/icon/icon_512.png`) over the blurred Home screen.
3. **How to play:** Mossback Drake (World 1) with real taps: two free arrows, one blocked tap ("Clear another arrow first."), then the board empties.
4. **Awakening:** Mossback Drake's photoreal awakening, played to the end.
5. **Speed and stars:** a fast replay with the timer running, then the results screen with 3 stars and "New record!".
6. **Later worlds and bestiary:** boards from World 5, World 8 and World 10, then the bestiary with 3 and then 97 of 100 dragons awakened.
7. **End card:** "100 dragons · 10 worlds · Play offline" and the icon over the blurred dragon.

Captions are English, set in the game's font (Inter SemiBold) on the game's button colour. In the landscape version the portrait game sits in the centre with a blurred copy of the same footage on both sides; the vertical version shows the game at 90 % with a caption band on top.

**How the later shots were reached:** the recording plays Mossback Drake for real (first clear, awakening, faster replay). To show later worlds and a fuller bestiary in under a minute, the recording script marks the other levels as completed with the game's own progression calls (the same ones the `world_unlock` E2E test uses). The screens, boards and dragons shown are the real ones a player reaches.

## Rebuild

```bash
GODOT=/path/to/godot scripts/record_promo.sh build/promo-work
python3 tools/make_promo_video.py build/promo-work docs/store/video
LEGEND_PROMO_SFX_ONLY=1 GODOT=/path/to/godot scripts/record_promo.sh build/promo-work-sfx
python3 tools/make_promo_short.py build/promo-work-sfx docs/store/video
python3 tools/make_promo_short.py build/promo-work-sfx docs/store/video 50
```

`scripts/record_promo.sh` runs the `promo` journey (`scripts/e2e/device_e2e.gd`, debug builds only) under Xvfb with Movie Maker and writes `promo.avi` plus `marks.txt` (scene start frames). `tools/make_promo_video.py` cuts the shots from those marks and fails if the result is not 45–60 s long. CI rebuilds all five videos on every push in the "Desktop E2E journeys (phone)" job and uploads them as the artifact **`promo-video`**.
