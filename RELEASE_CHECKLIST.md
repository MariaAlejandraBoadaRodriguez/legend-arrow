# Release checklist — Legend Arrow 0.1.0 (versionCode 1)

Brief §7 production-readiness items with evidence. **PASS** = executed with assertions (cited); **BLOCKED** = needs something outside this repository; **OWNER** = a release-time action only the owner can take. CI runs referenced: see `QA_REPORT.md`.

| # | Item | Status | Evidence |
|---|---|---|---|
| 1 | Reproducible builds, pinned dependencies | PASS | Godot 4.7.2 by SHA-256 (`scripts/install_godot.sh`); GUT vendored; Gradle wrapper + AGP 8.6.1 / Kotlin 2.1.21; GMA 24.4.0 / UMP 3.2.0; bundletool 1.18.1 by SHA-256; Actions pinned by commit SHA; `docs/OPERATIONS.md` |
| 2 | Package identity, version code/name | PASS | `com.mariaalejandraboada.legendarrow`, versionCode 1, versionName 0.1.0 — `check_apk.sh` (APK) and `aab_report.txt` (AAB) |
| 3 | Current target API, native compatibility | PASS | targetSdk 36, minSdk 24; arm64-v8a + armeabi-v7a + x86_64; 16 KB page-size check (ELF + zip) on APK and on the universal APK from the AAB |
| 4 | Production config separated from test | PASS | Debug/CI: Google test IDs only; release reads git-ignored `ads_release.json` and refuses test/missing IDs (`test_release_build_rejects_test_ids`, `test_release_config_validation`); `export_release.sh` refuses a real release without it; E2E harness inert in release (`OS.is_debug_build()`) |
| 5 | No committed secrets; signing material | PASS / OWNER | `.gitignore` covers keystores, `ads_release.json`, `.env`; CI uses a throwaway rehearsal key generated per run. Owner: create upload key + enrol Play App Signing (`docs/RELEASE.md`) |
| 6 | Ad consent and audience configuration | PASS (code) / OWNER (console) | Child/unknown treatment for everyone, AD_ID + Privacy Sandbox permissions removed, interstitials disabled, UMP once per launch, refusal never blocks play — unit/integration tests + manifest checks. Owner: UMP message + Families declaration in consoles |
| 7 | Privacy policy and Data Safety | DRAFT / OWNER | `docs/PRIVACY_POLICY.md`, `docs/DATA_SAFETY.md`; owner hosts the policy and re-verifies Google SDK disclosures |
| 8 | Atomic saves, recovery, migration tests | PASS | `test_save_repository` (12 incl. kill-at-every-step), E2E `partial_a` → force-stop → `partial_b` on the emulator |
| 9 | Sanitised logs, crash diagnosis | PASS | `EventLog` holds no identifiers (`test_events_are_logged_without_identifiers`); `docs/OPERATIONS.md` |
| 10 | Performance and memory on named devices | **BLOCKED** | No Android phone (D-18). Emulator only (not evidence): see `QA_REPORT.md`. Owner: `scripts/measure_device.sh <apk>` on a 3 GB phone |
| 11 | All required CI jobs passing on the final commit | PASS | `QA_REPORT.md` → final run |
| 12 | APK/AAB checksums | PASS | `legend-arrow-debug.apk.sha256`, `legend-arrow-release.aab.sha256` in CI artifacts |
| 13 | Release notes and known limitations | PASS | `docs/RELEASE.md` |
| 14 | Rollback / recovery procedure | PASS | `docs/RELEASE.md` (halt rollout, corrective release with a higher version code, save-schema rules) |

## Owner actions before the first upload
1. Upload key + Play App Signing.
2. AdMob app and rewarded unit, UMP message → `ads_release.json`.
3. Host the privacy policy; fill Data Safety, content rating, target audience (Families) in Play Console.
4. Run `scripts/measure_device.sh` on a low-tier phone; fix if budgets are missed.
5. Build with `scripts/export_release.sh`, upload to internal testing, then staged rollout.
