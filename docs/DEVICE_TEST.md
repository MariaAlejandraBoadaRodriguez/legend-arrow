# Testing Legend Arrow on your Lenovo tablet

These steps are for you (the owner), to test the game on your Lenovo Android tablet. No Android phone is needed. Part A is enough for the manual checklist; Part B is optional and only needed for the performance numbers.

Until you send results, the physical-device checks are marked **BLOCKED** in `docs/QA_REPORT.md` (never PASS).

---

## Part A — Install the game through Google Drive (about 10 minutes)

1. On your computer, open the repository on GitHub → **Actions** tab.
2. Click the newest run with a green check whose name starts with **CI**.
3. Scroll to **Artifacts** at the bottom and click **legend-arrow-debug-apk**. A ZIP file downloads.
4. Open the ZIP. Inside is **legend-arrow-debug.apk**. Drag it into your **Google Drive** (drive.google.com).
5. On the tablet, open the **Drive** app, find **legend-arrow-debug.apk** and tap it.
6. Android asks whether to allow installing apps from Drive. Tap **Settings** → turn on **Allow from this source** → go back.
7. Tap **Install**. If Play Protect warns about an unknown app, tap **More details → Install anyway** (this is your own test build).
8. Open **Legend Arrow** from the app list.
9. When you are done testing, you can turn **Allow from this source** off again (Settings → Apps → Special app access → Install unknown apps → Drive).

To update later: repeat steps 1–7 with a newer APK (it installs over the old one and keeps your progress).

---

## Part B (optional) — Measure performance over USB

You need a USB cable and a Windows computer.

### 1. Turn on Developer options and USB debugging on the Lenovo tablet
1. Open **Settings → About tablet**.
2. Tap **Build number** seven times (on some Lenovo models it is under **Settings → About tablet → Software information**). You will see "You are now a developer".
3. Go back to **Settings → System → Developer options** (on some models: **Settings → Additional settings → Developer options**).
4. Turn on **USB debugging**.

### 2. Install the tools on Windows (one time)
1. Install **Git for Windows** from https://git-scm.com/download/win (keep the default options). It includes **Git Bash**, which can run the measuring script.
2. Download **SDK Platform-Tools for Windows** from https://developer.android.com/tools/releases/platform-tools and unzip it to `C:\platform-tools`.
3. Open **Git Bash** and type:
   ```bash
   export PATH="/c/platform-tools:$PATH"
   adb version
   ```
   You should see a version number.

### 3. Connect and run
1. Plug the tablet in with USB. On the tablet, tap **Allow** on "Allow USB debugging?" (tick "Always allow from this computer").
2. In Git Bash, check the tablet is visible:
   ```bash
   adb devices
   ```
   It should list one device with the word `device` after it.
3. Download the repository (green **Code** button → **Download ZIP**), unzip it, and in Git Bash go into that folder, for example:
   ```bash
   cd ~/Downloads/legend-arrow-claude-upbeat-turing-4w8wzu
   ```
4. Put the APK from Part A into a folder named `build/android` inside it, then run:
   ```bash
   scripts/measure_device.sh build/android/legend-arrow-debug.apk build/device-lenovo
   ```
   It takes a few minutes. It installs the game, measures start-up time, memory and frame times while it plays, and writes a report.
5. Zip the folder `build/device-lenovo` and send it to me (attach it in the chat or upload it to Drive and share the link).

---

## Manual checklist (tick each line, add notes)

Write down your tablet model (Settings → About tablet) and Android version.

| # | Check | Result (OK / problem) | Notes |
|---|---|---|---|
| 1 | Play a level in **World 1** to the end | | |
| 2 | Play a level in a **middle world** (finish worlds by playing, or tell me and I send a test build with more unlocked) | | |
| 3 | Play a level in a **later world** with a large board: zoom/pan works, arrows are easy to tap | | |
| 4 | The **timer** starts at your first tap and shows discreetly; it stops while the pause menu is open | | |
| 5 | **Results** screen: time, "New record!" or "First clear", 1–3 stars appear one by one, Retry / Next work | | |
| 6 | Replay a level **faster**: best time and stars improve; replay **slower**: they do not drop | | |
| 7 | **Awakening** with a realistic dragon: arrows gather, the image appears through mist, Skip works after 1 s | | |
| 8 | **Bestiary**: grid of thumbnails; open a dragon: the image breathes gently; "Replay awakening" works | | |
| 9 | **Pause / background / resume**: press Home mid-puzzle, wait a minute, come back: same board, timer did not run | | |
| 10 | **Sound on/off**: set Music to 0 in Settings, close and reopen the game: still silent | | |
| 11 | **Larger text** in Settings: text grows, nothing is cut off | | |
| 12 | Turn the tablet sideways mid-puzzle: the game stays upright, nothing lost | | |
| 13 | **15-minute session**: play for 15 minutes without stopping: no lag, no crash | | |
| 14 | **Battery / heat** after 15 minutes: battery used (%), does the tablet feel warm? | | |

Send me this table (a photo is fine) together with the Part B report if you ran it. I will record the results in `docs/QA_REPORT.md`.
