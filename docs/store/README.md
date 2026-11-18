# Store graphics

- **[`play_console/`](play_console/README.md)**: every Google Play listing asset, named after its English Play Console field (icon, feature graphic, phone and tablet screenshots), with a guide to where each file goes. Rebuild with `tools/make_store_graphics.sh`; check with `python3 tools/store_assets.py check`. These are the v0.1 graphics; they are regenerated for 0.2.0 in milestone F.
- **`icon_concepts_v2.png`** (v0.2): four bold, high-contrast concepts **A–D** — Play icon, round launcher version, real 48 dp size on light and dark simulated home screens among generic colourful icons, and a 48 px close-up. Rebuild with `python3 tools/icon_concepts_v2.py`. **Awaiting the owner's choice**; the chosen concept becomes the adaptive launcher icon (foreground/background/monochrome) and the 512×512 store icon in milestone B.
- **`icon_concepts.png`** (v0.1, superseded): the three earlier concepts; B shipped in 0.1.x.
