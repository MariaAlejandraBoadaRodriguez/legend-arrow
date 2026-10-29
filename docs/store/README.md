# Store graphics

- **[`play_console/`](play_console/README.md)**: every Google Play listing asset, named after its Play Console field (icon, feature graphic, phone and tablet screenshots), with a Spanish guide to where each file goes. Rebuild with `tools/make_store_graphics.sh`; check with `python3 tools/store_assets.py check`.
- **`icon_concepts.png`**: the three icon concepts (A, B, C) at 512 px and 48 px. **B** was chosen and is now both the store icon and the launcher icon (`tools/make_icons.py`).
