# Release checklist — Legend Arrow 0.2.1 (versionCode 4)

> **Status (0.2.1): PENDING CI.** Production stays BLOCKED until item 18 is PASS (the real full-storage check passing in CI on 0.2.1). 0.2.0 went to closed testing only.

Final run: [CI 44470278817](https://github.com/MariaAlejandraBoadaRodriguez/legend-arrow/actions/runs/44470278817) on `a0b8717`, all jobs green (also [44464519633](https://github.com/MariaAlejandraBoadaRodriguez/legend-arrow/actions/runs/44464519633) on `8a4b555`).

Statuses:
- **PASS**: executed with assertions (see `QA_REPORT.md`).
- **BLOCKED**: needs the owner's device.
- **OWNER**: a release-time action only the owner can take.

| # | Item | Status | Evidence |
|---|---|---|---|
| 1 | Reproducible builds, pinned dependencies | PASS | Godot 4.7.2 by SHA-256; GUT vendored; Gradle wrapper; GMA 24.4.0 / UMP 3.2.0; bundletool 1.18.1 by SHA-256; rembg 2.0.67 + model by SHA-256; Actions pinned by commit |
| 2 | Package identity, version | PENDING CI | `com.mariaalejandraboada.legendarrow`, versionCode 4, versionName 0.2.1 (APK + both AABs; `EXPECT_VERSION_CODE=4`) |
| 3 | Target API, ABIs, 16 KB pages | PASS | targetSdk 36; arm64-v8a + armeabi-v7a; 16 KB ELF + zip alignment |
| 4 | No new permissions | PASS | merged-manifest audit against `tools/permissions_allowlist.txt` (v0.1 baseline) |
| 5 | Test config separate from production | PASS | debug/CI use Google test IDs only; a real release refuses test or missing IDs |
| 6 | No committed secrets | PASS | `check_no_secrets` in CI |
| 7 | Signing-certificate SHA-256 printed for comparison with Play Console | PASS | `aab_report.txt`, run 44464519633 (check fails if missing) |
| 8 | Content: 100 certified puzzles, rising difficulty, English only | PASS | `QA_REPORT.md` 9.1 |
| 9 | All 100 dragons imported (no ART PENDING) | PASS | `docs/ART_STATUS.md`: 100/100 |
| 10 | Save migration from v0.1 (real save) | PASS | fixture test |
| 11 | Emulator E2E on API 26 / 34 / 36 | PASS | 13/13 each (runs 44554390772, 44464519633). The API 26 save mismatch is a test-environment issue (`docs/qa/SAVE_INVESTIGATION.md`) |
| 12 | Screen matrix P1–P7 reviewed | PASS (local) / PENDING CI | 20 screens incl. the "Storage full" message, `docs/qa/VISUAL_QA.md` |
| 13 | Memory settles; download ≤ 120 MB | PASS | 48.8 MB arm64 (with ads) |
| 14 | Feel and stability on a real device | PASS | owner's Lenovo tablet: all 15 `docs/DEVICE_TEST.md` checklist items PASS (15-minute session without lag, progress kept after force-close). Optional frame-time numbers (Part B): not run |
| 15 | Privacy policy and Data Safety current | PASS (docs) / OWNER (publish) | `docs/privacy.html` updated for 0.2.0; no Data Safety answer changes |
| 16 | Store graphics (English, 20 files) | PASS | CI artifact `play-store-assets` |
| 17 | APK/AAB checksums | PASS | `.sha256` files in CI artifacts |
| 18 | **Save never reports success for a broken write on a full device** (blocks production) | **PENDING CI** (fix in 0.2.1) | Fix from `save-hardening-experimental`: verified write, retry now + in the background, "Storage full" message (D-52). Closes only when `scripts/enospc_check.sh` (real ENOSPC on a tmpfs) passes in CI on 0.2.1. Local run: PASS |
| 19 | No device feature required unintentionally; `android.hardware.screen.portrait` not required | PENDING CI | `scripts/check_apk.sh` against `tools/required_features_allowlist.txt` (D-53) |

## Owner actions before uploading 0.2.0 (closed testing track only)
1. ~~Run `docs/DEVICE_TEST.md` on the Lenovo tablet.~~ Done: all 15 items PASS.
2. Replace the hosted privacy policy page with the new `docs/privacy.html`. No Data Safety changes are needed in Play Console.
3. Upload the new store graphics from the `play-store-assets` artifact (Main store listing → Graphics). Upload them in number order.
4. Use a **closed testing** track for 0.2.0, not production (item 18).
5. Build the signed AAB with your upload key: `release.yml` (or `scripts/export_release.sh`). Check that the printed certificate SHA-256 matches Play Console → App integrity. Upload to internal testing first.
