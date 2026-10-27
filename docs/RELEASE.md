# Release procedure

What CI produces automatically on every push / PR:
- **Debug APK** (`legend-arrow-debug-apk`): debug-signed, Google test ad IDs, installable on any emulator/phone for testing.
- **Release AAB rehearsal** (`legend-arrow-release-aab-rehearsal`): the real release pipeline (release export, bundletool validation, manifest/ABI/16 KB checks, SHA-256) but signed with a **throwaway key** and **ads disabled**. Proves the release build works; **never upload it to Play** (its key is not your upload key).

The real store release is a manual, owner-run step, because it needs things that must never be in the repository.

## One-time prerequisites (owner)
1. **Upload key**: `keytool -genkeypair -v -keystore legend-arrow-upload.jks -alias upload -keyalg RSA -keysize 4096 -validity 10000`. Keep it and its password outside the repo (password manager + offline backup). Enrol in **Play App Signing** (Google holds the app signing key; losing the upload key is recoverable through Play support, losing an unenrolled app key is not).
2. **AdMob**: app + rewarded ad unit, UMP message published. Create `ads_release.json` in the project root (git-ignored), see `docs/ADS_AND_PRIVACY.md`.
3. **Play Console**: app created with package `com.mariaalejandraboada.legendarrow` (permanent), target audience including children → Families policy, Data Safety form from `docs/DATA_SAFETY.md`, privacy policy hosted at a public URL from `docs/PRIVACY_POLICY.md`, content rating questionnaire, store listing (screenshots from CI artifacts `e2e-android-api34` / `e2e-desktop-*`).

## Each release
1. Bump the version in `export_presets.cfg` **for both presets**: `version/code` (+1, integer, must always increase) and `version/name` (`MAJOR.MINOR.PATCH`). Commit.
2. Check `main` is green on CI (all jobs, including the emulator E2E).
3. Build locally (needs Android SDK, JDK 17, Google Maven access):
   ```bash
   scripts/build_ads_plugin.sh
   export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/secure/legend-arrow-upload.jks
   export GODOT_ANDROID_KEYSTORE_RELEASE_USER=upload
   export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD='…'
   scripts/export_release.sh
   ```
   It refuses to run without the key or `ads_release.json`, fails on any export error, validates the bundle with bundletool and writes `build/android/legend-arrow-release.aab`, `.sha256` and `aab_report.txt`.
4. Install the universal APK from the bundle on a test device (`build/android/universal/universal.apk`), play a puzzle, check the consent form appears (EEA test device via AdMob test device settings) and a **test** rewarded ad loads on a registered test device. Never click your own live ads.
5. Run `scripts/measure_device.sh` on the reference phone (see `QA_REPORT.md`).
6. Upload the AAB to the **internal testing** track, then closed testing, then production with a staged rollout (e.g. 10% → 50% → 100%).
7. Tag the commit: `git tag v<version_name> && git push origin v<version_name>`; attach the `.sha256` and `aab_report.txt` to the GitHub release notes.

## Rollback / recovery
Google Play **cannot** go back to an older version code. To undo a bad release:
1. **Halt** the staged rollout in Play Console (stops new installs of the bad version).
2. Revert or fix the code on `main`, **increase `version/code` again** (higher than the bad one) and release that corrective build through the same steps.
3. Save compatibility: saves carry `schema_version`; the game migrates older saves forward (`SaveSchema.migrate`) and refuses saves from the future without destroying them (`test_rejects_future_schema`). A corrective release that keeps the newer schema (or reads it) is required if the bad release already wrote a newer save format. Never lower the schema number.
4. Corrupt saves are handled on the device: checksum failure → backup restore → quarantine as `.corrupt`, with a one-time message (`docs/SAVE_FORMAT.md`).

## Release notes template
```
Legend Arrow <version_name> (<version_code>)
New: …
Fixed: …
Known limitations: see QA_REPORT.md
SHA-256 (AAB): …
```

## Known limitations (current)
- Creature art is stylised procedural vector art made in code (D-33); a human art pass is recommended before marketing screenshots.
- Physical-device performance has not been measured (no Android phone available); emulator measurements only.
- Live ads and the real consent form have only been exercised through the mock provider and unit/integration tests, never against live Google services.
- Store listing graphics (feature graphic, phone/tablet screenshots in store format) are not produced.
