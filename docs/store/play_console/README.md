# Google Play listing graphics — Legend Arrow

Every file here goes in **Play Console → Grow users → Store presence → Main store listing → Graphics**. Each file name gives the section and the field. All text in the listing and the graphics is English (owner decision D-41).

| File | Play Console field | Required? |
|---|---|---|
| `01_Graphics__App_icon__512x512.png` | App icon (512×512, 32-bit PNG, no transparency) | Yes |
| `02_Graphics__Feature_graphic__1024x500.png` | Feature graphic (1024×500, no alpha) | Yes |
| `03_Graphics__Phone_screenshots__01_home__1080x1920.png` | Phone screenshots, 1 | Yes (at least 2) |
| `03_Graphics__Phone_screenshots__02_tutorial__1080x1920.png` | Phone screenshots, 2 | Yes (at least 2) |
| `03_Graphics__Phone_screenshots__03_puzzle__1080x1920.png` | Phone screenshots, 3 | Recommended |
| `03_Graphics__Phone_screenshots__04_awakening__1080x1920.png` | Phone screenshots, 4 | Recommended |
| `03_Graphics__Phone_screenshots__05_bestiary__1080x1920.png` | Phone screenshots, 5 | Recommended |
| `03_Graphics__Phone_screenshots__06_creature__1080x1920.png` | Phone screenshots, 6 | Recommended |
| `04_Graphics__7-inch_tablet_screenshots__01_home__1200x2133.png` | 7-inch tablet screenshots, 1 | Optional (needed to be featured on tablets) |
| `04_Graphics__7-inch_tablet_screenshots__02_puzzle__1200x2133.png` | 7-inch tablet screenshots, 2 | Optional |
| `04_Graphics__7-inch_tablet_screenshots__03_awakening__1200x2133.png` | 7-inch tablet screenshots, 3 | Optional |
| `04_Graphics__7-inch_tablet_screenshots__04_bestiary__1200x2133.png` | 7-inch tablet screenshots, 4 | Optional |
| `05_Graphics__10-inch_tablet_screenshots__01_home__1440x2560.png` | 10-inch tablet screenshots, 1 | Optional (needed to be featured on tablets) |
| `05_Graphics__10-inch_tablet_screenshots__02_puzzle__1440x2560.png` | 10-inch tablet screenshots, 2 | Optional |
| `05_Graphics__10-inch_tablet_screenshots__03_awakening__1440x2560.png` | 10-inch tablet screenshots, 3 | Optional |
| `05_Graphics__10-inch_tablet_screenshots__04_bestiary__1440x2560.png` | 10-inch tablet screenshots, 4 | Optional |

Upload them in number order: Play shows screenshots in upload order.

## Deliberately not included
- **Google Play Games on PC**, **Chromebook** and **Android XR**: Legend Arrow is not designed for those devices, so those sections stay empty.
- **Preview video** (YouTube URL, optional): no video is published. A real gameplay recording exists at `docs/media/legend_arrow_gameplay.mp4` if you want to upload it to YouTube.

## How they were made
- **Screenshots**: real frames of the running game (`tools/capture_store.gd`) rendered by Godot at each device resolution, not mock-ups, with a one-line English caption band on top in the game's typeface (Inter) and colours.
  - Phone: game at 1080×1704 + 216 px band.
  - 7" tablet: 10:16 tablet screen (1200×1920) + 213 px band.
  - 10" tablet: 10:16 tablet screen (1440×2304) + 256 px band.
- **Icon**: `tools/make_icons.py`; the same drawing as the launcher icon.
- **Feature graphic**: the awakening landscape and a creature rendered by Godot, with the title "Legend Arrow".

These v0.1 graphics are regenerated for 0.2.0 after the final dragon art is integrated (milestone F).

## Regenerate and verify
```bash
GODOT=/path/to/godot tools/make_store_graphics.sh   # regenerate everything and verify
python3 tools/store_assets.py check                 # verify only
```
The check confirms all 16 files exist with the exact name, are PNG, have the exact pixel size, have no alpha channel (the icon: 32-bit and fully opaque) and respect the size limits (icon ≤ 1 MB, feature graphic ≤ 15 MB, screenshots ≤ 8 MB). CI runs it on every push and publishes this folder as the `play-store-assets` artifact.
