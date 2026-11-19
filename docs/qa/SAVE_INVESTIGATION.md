# Save investigation: "results shown, save missing the level" (API 26)

## Verdict (owner decision)

**0.2.0 ships to CLOSED TESTING with this known limitation; the fix on save-hardening-experimental must ship in 0.2.1 BEFORE any production release.**

**Known limitation of the shipped save code:** when the device storage is completely full, the save can report success while writing a 0-byte save file. On the next launch, the latest progress is gone. Real players are only affected with a completely full device.

### The run that showed it (CI run 44577702952, PR #7, attempt 1, API 26)

The first launch after install plus `pm clear` ran on the code that ships in 0.2.0 (docs-only head `0cca853`):

```
RESULTS stars shown 3, saved { }; source=NEW problems=["main save missing"]
  files=save.json.corrupt=0   last_persist_error=0
then the harness: run-as … echo > files/… failed 4/4
```

- The write path **reported success** (`last_persist_error=0`) while the main save was a **0-byte file**.
- The next read quarantined that file as `save.json.corrupt`, so the completed level was missing.
- The harness's own writes into the app directory failed at the same moment. That is the full-storage signature, as in run 44568586880 (installd: "Failed to free up 624066560 on /data", 326 MB free of 6 GB).
- The job's one allowed re-run passed. The push run on the same commit (44577654407) passed too.
- A real disk-full test on a tmpfs (branch `save-hardening-experimental`, `scripts/enospc_check.sh`) reproduces the same outcome with the shipped code: write "OK", main unreadable, backup restored. The fix on that branch reports the failure, keeps the main save intact, and keeps progress in memory until a write lands.

### Earlier results, still true

The shipped code never lost progress in these checks:

| Check | Result |
|---|---|
| API 26 emulator kill stress (run 44554390772) | 240/240 |
| Same-emulator A/B (run 44568586880) | 120/120 |
| Desktop kill stress | 150/150 |
| Owner's Lenovo tablet, `docs/DEVICE_TEST.md` items 1–15 | all PASS |

A process kill alone does not lose progress. The limitation needs a completely full storage.

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

## Required for 0.2.1 (before any production release)

Branch **`save-hardening-experimental`** (commit 693a5bf) holds:
- verify-before-promote writes, with retry while progress is only in memory;
- a real disk-full check (`scripts/enospc_check.sh`);
- the kill stress harness (`scripts/save_stress.sh`);
- the system-side failure capture for the emulator (`scripts/android_probe.sh`).

Not in 0.2.0 (owner decision). It must ship in 0.2.1 before any production release; see `RELEASE_CHECKLIST.md` item 18.
