# Prompt 2 — Continue (paste into every following session)

```
Continue Legend Arrow. Read CLAUDE.md and docs/PROGRESS.md, then only the parts of the brief/spec needed for the next milestone.

Resume exactly where PROGRESS.md says. Finish the current milestone, run scripts/verify_all.sh, fix every failure (reproduce → diagnose → fix → regression test → rerun), commit, push, and verify the real GitHub Actions run is green. Then move to the next milestone.

Do not ask me about routine decisions. Before stopping, update docs/PROGRESS.md, commit and push. Report PASS / FAIL / BLOCKED / NOT RUN, commit SHA and Actions run link.
```

# Prompt 3 — Fix CI (use when a GitHub Actions run is red)

```
The latest GitHub Actions run for Legend Arrow failed. Fetch its logs with gh, find the root cause, fix it, add a regression test if warranted, run scripts/verify_all.sh locally, push, and re-check the new run until all required jobs pass. Do not disable or weaken tests. Update docs/PROGRESS.md.
```

# Prompt 4 — Final tests and handoff (after M5/M6)

```
Run the full Legend Arrow verification: scripts/verify_all.sh, all CI jobs including the Android emulator E2E suite, coverage/requirements matrix, debug APK + AAB with SHA-256 checksums, phone and tablet screenshots, and an awakening video capture if possible. Write docs/QA_REPORT.md and docs/RELEASE_CHECKLIST.md with PASS / FAIL / BLOCKED / NOT RUN for each item. Physical-device performance is BLOCKED (owner has no Android phone) — provide scripts/measure_device.sh instead. List the external prerequisites I must supply (AdMob IDs, upload key, Play Console declarations, privacy policy hosting).
```
