# Save investigation: "results shown, save missing the level" (API 26)

## Verdict: test-environment issue (owner decision, closed)

The mismatch was seen only on the API 26 CI emulator: the results screen showed a completed level that the save file on disk did not contain. It happened in the first session right after `adb install -r -g` plus `pm clear`, in runs 44466657570, 44472596603 and 44546790523. When it happened, the app's data directory was unusable from outside the app too: the harness's own `run-as` writes failed at the same moment.

**The original save code (on `main`, shipped in 0.2.0) passed:**

| Check | Result |
|---|---|
| API 26 emulator kill stress, 3 GB and default RAM (run 44554390772) | 240/240 |
| API 26, same emulator, alternating with the experimental code (run 44568586880) | 120/120 |
| Desktop kill stress, same kill plans | 150/150 |
| Owner's Lenovo tablet, `docs/DEVICE_TEST.md` items 1–15 (incl. item 15: finish a level, force-close, reopen, progress kept) | all PASS |

The kill stress (`save_kill` / `save_verify`) wipes data, finishes a level while the app SIGKILLs itself during the save, right after it or with the results on screen, then relaunches and compares the save with what was shown.

## What was reviewed

| Area | Finding |
|---|---|
| Rename (Android 8) | `user://` uses Godot's `FileAccessUnix` / `DirAccessUnix`; `rename(2)` is atomic and replaces the target. |
| flush / fsync | No fsync anywhere; the `.bak` fallback covers power loss. |
| Fallback order | main → tmp → bak. |
| Results screen | Shows the in-memory run after a synchronous save inside the last tap's handler. |

## Engineering notes (for the record)

- **What the emulator logs showed:** the system-side capture in run 44568586880 recorded the emulator's `/data` partition as full at the failure ("installd: Failed to free up 624066560 on /data", 326 MB free of 6 GB) while the app's data was about 1 KB. A full disk makes every app write fail, so this is the likely mechanism of the emulator issue. What fills the emulator's storage is not identified.
- **Old vs new code on one emulator:** the experimental branch below was compared in run 44568586880 by alternating old and new code per iteration on the same emulator: 120/120 each, storage flat. The earlier storage churn followed particular emulator instances.
- **What the experimental branch changes:** under a real full disk (ENOSPC on a tmpfs), the shipped write path reports success while leaving the main save unreadable, so the next launch restores the backup. The experimental path reports the failure and keeps the main save. Players only meet this with a completely full phone.

## Future item (v0.2.x, not in 0.2.0)

Branch **`save-hardening-experimental`** (commit 693a5bf) holds:
- verify-before-promote writes, with retry while progress is only in memory;
- a real disk-full check (`scripts/enospc_check.sh`);
- the kill stress harness (`scripts/save_stress.sh`);
- the system-side failure capture for the emulator (`scripts/android_probe.sh`).

It is unmerged by owner decision. Evaluate it for a later v0.2.x release.
