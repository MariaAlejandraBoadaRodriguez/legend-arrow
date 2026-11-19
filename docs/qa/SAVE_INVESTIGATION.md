# Save investigation: "results shown, save missing the level" (API 26)

## Verdict: FIXED

| | |
|---|---|
| **Root cause** | `SaveRepository.write()` promoted the temp file without checking it. Under a **full disk** (ENOSPC), the write is short, Godot reports success, and the broken temp file replaced the good main save. The next load fell back to the older backup and showed "Progress restored", and the newest progress was lost. Meanwhile the results screen correctly showed the in-memory run. |
| **Trigger in CI** | The API 26 emulator's `/data` partition **filled up from outside the app**, a test-environment condition. The app's own data stayed around 1 KB. |
| **Player exposure** | Real: a phone can run out of storage. |
| **Fix** | Verify before promoting, retry, and keep progress in memory until a write lands. |
| **Evidence** | A **real** disk-full test fails on the old code and passes on the new. It is now a CI check on every push. |

## Symptom

On the API 26 emulator, the first session after install plus `pm clear` sometimes ended like this: the results screen showed the level (3 stars, a time), but the save on disk had no record of it. Seen in:
- run 44466657570, then the script died on `run-as`;
- run 44472596603, in `measure_device.sh`;
- run 44546790523, with forensics.

It was never seen on API 34, API 36 or desktop.

## How the cause was found

### 1. The write path on Android 8

Read in Godot 4.7.2's source (`platform/android/os_android.cpp`, `drivers/unix/*`).

| Question | Finding |
|---|---|
| Which file layer handles `user://` | `FileAccessUnix` / `DirAccessUnix`; the Java layer only handles other filesystem paths. |
| Rename | POSIX `rename(2)`: atomic and replaces the target on Android 8 too. Same directory, so no EXDEV. |
| Godot's own write | `mkstemp("…-XXXXXX")`, then a rename inside `close()`. `close()` has no return value, so a failure there is invisible to GDScript. |
| flush / fsync | `flush()` is `fflush`; there is no fsync anywhere. A process kill keeps the page cache, and power loss is covered by the `.bak` fallback. |
| Fallback order | main → tmp → bak, correct. `sanitize` type checks were reviewed: no normal save is ever rejected. |
| **Defect** | Write errors were never checked, and the temp file was never read back before rotating main to `.bak` and promoting it. |

### 2. Results screen versus the save

- The completion is persisted synchronously, inside the last tap's handler, before the results screen opens. The screen shows the in-memory run. No other file is read.
- If that write failed, the error was only logged, and the old code didn't even notice a short write.
- The E2E's own read (`load_save()`) quarantined and repaired files while checking them. It now uses the side-effect-free `peek()`.

### 3. Forensics from a recurrence (run 44546790523)

```
stars shown 3, saved { }; source=NEW problems=["main save missing"] files=(none)
last_persist_error=16 save_pending=true my_seq=16  in_memory={completed, 2421 ms, 3 stars}
then the harness: run-as … echo > files/… failed 4/4
```

No save file existed at all, and the shell couldn't write into the app's directory either.

### 4. System-side capture (run 44568586880, API 26, 3 GB)

```
installd: Device /data has 326500352 free; requested 624066560
installd: Failed to free up 624066560 on /data
DeviceStorageMonitorService: IOException: Failed to free 624066560 on storage device at /data
```

The 6 GB partition, 2% used at boot, was full. The app's files at the time were `save.json` 683 B and `.bak` 684 B. Storage traces in other jobs swung between 13% and 96% used while the app's directory stayed in KB.

A full disk explains every observation:
- no save could be written (`files=(none)`);
- the new code's read-back refused a short write (error 16);
- `run-as … echo >` failed;
- the old code promoted broken temp files, which gave "saved { }".

Which emulator component fills `/data` is not identified. It is outside the app's directories, so it doesn't affect the verdict. `android_e2e.sh` now prints storage at the start and on failure.

## (3) Stress test: kill around the save, relaunch, compare

`scripts/save_stress.sh` drives two journeys, `save_kill` and `save_verify`. Each iteration:
- wipes the app's data;
- finishes a level while a thread **inside the app** SIGKILLs the process at a planned moment: during the commit (0–300 ms), right after it (0.3–1.5 s), with the results on screen (1.5–3.5 s), or during the in-progress saves of play; every 5th iteration does not kill, as a control;
- relaunches and checks that the save equals what was shown and that earlier progress survived.

| Target | Save code | Iterations | Mismatches |
|---|---|---|---|
| Desktop | new | 300 (seeds 777, 4242) | 0 |
| Desktop | old | 150 (seed 4242, same kill plans) | 0 |
| API 26, 3 GB and default RAM | new | 240 (runs 44546790523, 44554390772) | 0 mismatches ¹ |
| API 26, 3 GB and default RAM | old | 240 (run 44554390772) | 0 |
| API 26, **same emulator, alternating** old/new, 3 GB and default RAM | 120 old + 120 new | 240 (run 44568586880) | 0 / 0, storage flat at 6% |
| **Total** | | **1,170** | **0** |

¹ Two new-code jobs had "no verdict" iterations on emulators whose `/data` was filling up. The same-emulator A/B run showed the code isn't the cause: old 120/120, new 120/120, and the app's directory at 336 KB.

**What the stress test shows:** a process kill alone never loses or corrupts progress, with either version of the code. A kill can't make a write short; it can only stop the process before promotion. So the kill stress could not separate old from new. **The real disk-full test does:**

## (4) Fix and regression tests

**Fix**
- `SaveRepository.write()`: check `get_error()`, read the temp file back and compare it with what was meant to be written. On mismatch, delete the temp file, leave main untouched and return an error.
- `Game.persist()`: retry once at once, then every 2 s while `save_pending`, so the save catches up with what the screen showed as soon as space is back.

**Regression tests**

| Test | Old code | New code |
|---|---|---|
| Unit: short write, stale temp file, missing temp file | fail | pass |
| Unit: `peek()` has no side effects | — | pass |
| Unit: the old-code baseline still promotes a broken temp file | — | pass |
| Integration: a failed completion save catches up; saved stars and time equal what was shown | — | pass |
| **`scripts/enospc_check.sh`, real ENOSPC on a 2 MB tmpfs, every CI push** | `second_write_err=0 main_readable=false load_source=BACKUP recovered=true` | `second_write_err=13 main_readable=true load_source=MAIN recovered=false`, previous progress kept |

**Kept**
- The system-side capture on any emulator failure (`scripts/android_probe.sh`): package/installd/storage/SELinux lines, the data directory's state, and the storage breakdown.
- The save stress job, on demand (Actions → CI → Run workflow).
