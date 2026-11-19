# Save investigation: "results shown, save missing the level" (API 26)

**Status: OPEN.** A real save-path defect is fixed. The failure seen in CI is narrowed to an external wipe of the app's data directory on the Android 8 emulator. The component doing the wipe is not identified yet. This file is updated as results come in.

## Symptom

On the API 26 emulator, the first launch right after install plus `pm clear` sometimes ended like this: the results screen showed the level (3 stars, a time), but the save file on disk had no record of it ("stars shown 3, saved { }").

| Run | Failure |
|---|---|
| 44466657570 | the results check failed; the script then died on `run-as` |
| 44472596603 | `measure_device.sh`'s `fresh_install` |
| 44546790523 | the regular API 26 job, the first with full forensics |

It has never been seen on API 34, API 36 or desktop.

## (1) Write path on Android 8

The save path is `user://save.json`. Godot 4.7.2 source (`platform/android/os_android.cpp`, `drivers/unix/*`) shows `user://` uses `FileAccessUnix` and `DirAccessUnix` on Android, not the Java layer.

| Question | Finding |
|---|---|
| Temp file + rename | `write()` writes `save.json.tmp`, rotates main to `.bak`, then renames tmp to main. Godot's own write goes through `mkstemp("save.json.tmp-XXXXXX")` and renames that on `close()`. |
| Rename over an existing file | POSIX `rename(2)`: atomic, and replaces the target, on Android 8 too. EXDEV is not possible: same directory. |
| flush / fsync | `FileAccess.flush()` is `fflush` only. Godot never calls `fsync`, and GDScript cannot. That matters for power loss or an OS crash, not a process kill (the page cache survives). The `.bak` fallback covers a torn file. |
| Backup fallback order | main → tmp → bak, correct. The type checks in `sanitize` were reviewed: every top-level key keeps its type in play, so a valid fresh save is never rejected. |
| **Defect (fixed)** | Godot reports neither short writes nor a failed rename inside `close()`, and `write()` did not verify the tmp. A broken tmp would replace a good main, and the next load would restore the older backup, giving exactly "saved { }". **Fix:** check the write error, read the tmp back and compare it before promoting; on mismatch, delete the tmp, leave main untouched and return an error. Regression tests: short write, stale tmp, missing tmp. All three fail on the old code and pass now. |

## (2) Results screen versus the save

- The completion is written synchronously, inside the last tap's handler, before the results screen opens. The screen shows the in-memory run.
- **Gap (fixed):** if that write failed, it was only logged. Now `Game.persist()` retries once, then keeps retrying every 2 s while `save_pending` is set. An integration test checks that the saved stars and time equal those shown after a failed first write.
- **Gap (fixed):** the E2E checked the save with `load_save()`, which quarantines and repairs files while reading. It now uses the side-effect-free `peek()`.
- No other file is read. Boot uses the same `load_save()` path, main first.

## Forensics from the recurrence (run 44546790523, API 26, 3 GB)

```
stars shown 3, saved { }; source=NEW problems=["main save missing"] files=(none)
last_persist_error=16 (ERR_FILE_CORRUPT) save_pending=true my_seq=16
in_memory={completed: true, best_time_ms: 2421, best_stars: 3}
then: run-as ... mkdir -p files && echo ... → failed 4/4
```

- The main, tmp and backup files were all **gone**, after 15 successful writes.
- The new write verification correctly refused to promote (error 16), and progress was kept in memory.
- At the same moment the **shell's `run-as` could not use the app's data directory either**. That is outside the app's control: the data directory was wiped or recreated externally, about 30 s after a first launch that followed install plus `pm clear`.
- Next: system-side capture on failure (`scripts/android_probe.sh`: PackageManager, installd, ActivityManager, avc, storage; `ls -laZ`, `dataDir`, df), to name the component.

## (3) Stress test: kill around the save, relaunch, compare

`scripts/save_stress.sh` with journeys `save_kill` and `save_verify`. Each iteration:
- wipes the app's data;
- finishes a level while a thread inside the app SIGKILLs the process at a planned moment: during the commit write (0–300 ms), right after it (300–1500 ms), with the results already on screen (1.5–3.5 s), or during the in-progress saves of play; every 5th iteration does not kill, as a control;
- relaunches, and checks that the save equals what was shown and that earlier committed progress survived.

The A/B baseline `LEGACY=1` restores the pre-fix write path, and a unit test proves the baseline still has the defect.

| Target | Save code | Iterations | Mismatches | Notes |
|---|---|---|---|---|
| Desktop (Linux) | new | 150 (seed 777) | 0 | 30 controls, 88 killed before the results screen, 32 after |
| Desktop (Linux) | new | 150 (seed 4242) | 0 | 19 kills landed between the save and the screen, all intact |
| API 26 emulator, 3 GB | new | 120 (seed 26003) | 0 | run 44546790523 |
| Desktop / API 26, old code, 3 GB and default RAM | old and new | pending | | A/B with the same seeds |
