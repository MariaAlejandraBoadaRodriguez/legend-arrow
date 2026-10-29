# Release procedure

What CI produces automatically on every push and PR:
- **Debug APK** (`legend-arrow-debug-apk`): debug-signed, uses Google test ad IDs, installs on any emulator or phone for testing.
- **Release AAB rehearsals**: the real release pipeline (release export, bundletool validation, manifest/ABI/16 KB checks, versionCode 1, SHA-256), with ads and without ads, signed with a **throwaway key**. They prove the release build works. **Never upload them to Play**: their key is not your upload key.

The store build comes from the manual **Release AAB** workflow (`.github/workflows/release.yml`), signed with **your upload key** from GitHub Actions secrets. The keystore and its password are never in the repository; `scripts/check_no_secrets.sh` fails CI if one is ever committed.

## 1. Create the upload keystore (Windows, once)

You need `keytool`, which ships with Java. Android Studio includes one.

1. Open **PowerShell** (Start → type `PowerShell`).
2. Create a private folder **outside the repository**, for example in your user profile:
   ```powershell
   New-Item -ItemType Directory -Force "$env:USERPROFILE\keys\legend-arrow" | Out-Null
   ```
   Don't put it in the repo, a shared folder or a synced folder that others can read.
3. Find `keytool`. With Android Studio installed:
   ```powershell
   $keytool = "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
   Test-Path $keytool   # must print True
   ```
   If it prints False, run `where.exe keytool`, or install Temurin JDK 17 and use `"C:\Program Files\Eclipse Adoptium\jdk-17*\bin\keytool.exe"`.
4. Generate the key. Type the command exactly. **keytool will ask for the password**; don't put the password on the command line, because it would be saved in your PowerShell history.
   ```powershell
   & $keytool -genkeypair -v `
     -keystore "$env:USERPROFILE\keys\legend-arrow\legend-arrow-upload.jks" `
     -storetype PKCS12 -alias upload `
     -keyalg RSA -keysize 4096 -validity 10000 `
     -dname "CN=Maria Alejandra Boada Rodriguez, O=Legend Arrow"
   ```
   - Use a long, unique password (20+ characters from your password manager's generator).
   - With PKCS12 there is **one** password for the keystore and the key. That's what the CI workflow expects.
   - `-validity 10000` is about 27 years (Play requires the key to be valid past 2033).
5. Check it and note the fingerprint (public, safe to share):
   ```powershell
   & $keytool -list -v -keystore "$env:USERPROFILE\keys\legend-arrow\legend-arrow-upload.jks" -alias upload
   ```
   Write down the **SHA-256** fingerprint. Every release AAB report prints the signing certificate's SHA-256; it must match this one and, later, the upload key shown in Play Console → *Test and release → App integrity*.
6. **Back it up** (losing it means asking Google support for an upload-key reset):
   - In your password manager, make an entry "Legend Arrow upload key" with the password, the alias `upload`, the SHA-256 fingerprint, and the `.jks` file as an attachment.
   - Keep a second copy of the `.jks` file offline, for example on a USB drive kept at home.
   - Never email it, never paste it into chats or issues, and never copy it into the project folder.

## 2. Add the GitHub Actions secrets (once)

1. Copy the keystore as base64 **to the clipboard** (no file is written):
   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("$env:USERPROFILE\keys\legend-arrow\legend-arrow-upload.jks")) | Set-Clipboard
   ```
2. On GitHub: repository → **Settings → Environments → New environment** → name it `release`. Recommended: tick **Required reviewers** and add yourself, so every signed build waits for your approval.
3. In the `release` environment → **Environment secrets → Add secret**, create:

   | Name | Value |
   |---|---|
   | `ANDROID_UPLOAD_KEYSTORE_BASE64` | paste the clipboard from step 1 |
   | `ANDROID_UPLOAD_KEYSTORE_PASSWORD` | the keystore password |
   | `ANDROID_UPLOAD_KEY_ALIAS` | `upload` |
   | `ADS_RELEASE_JSON` *(later, only for ads)* | the contents of `ads_release.json` (`docs/ADS_AND_PRIVACY.md`) |

   You can use **Settings → Secrets and variables → Actions → Repository secrets** instead; the workflow reads either.
4. Clear the clipboard: `Set-Clipboard -Value $null`.

GitHub stores secrets encrypted, masks them in logs, and never shows them again. The workflow decodes the keystore only into the runner's temporary directory, checks the password and alias with `keytool`, and deletes it at the end of the job.

## 3. Build the signed AAB

1. GitHub → **Actions → Release AAB → Run workflow** (branch `main`).
   - **ads**: `without-ads` until AdMob is set up. The ads SDK, the Google libraries and the AdMob manifest entry are left out entirely, and hints stay free-only. Use `with-ads` once `ADS_RELEASE_JSON` exists.
   - **version_code**: `1` for the first upload. The run fails if the bundle has a different versionCode.
2. If you set required reviewers, approve the run.
3. When it's green, download the artifact `legend-arrow-release-aab-vc1-…`. It contains:
   - `legend-arrow-release.aab`: upload this one;
   - `.sha256`: the checksum;
   - `aab_report.txt`: package `com.mariaalejandraboada.legendarrow`, versionCode 1, targetSdk, ABIs, sizes and the signing certificate SHA-256. Compare that SHA-256 with your note from step 1.5.
4. Play Console → your app → **Test and release → Internal testing → Create new release**. Accept **Play App Signing** (Google holds the app signing key; your key is the *upload* key), upload the AAB and roll out to your testers.

### Local alternative (Linux/macOS/WSL)
```bash
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/secure/legend-arrow-upload.jks
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=upload
read -rs GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD; export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
EXPECT_VERSION_CODE=1 scripts/export_release.sh --no-ads     # or, with ads_release.json: scripts/build_ads_plugin.sh && scripts/export_release.sh
```

## Each later release
1. Bump the version in `export_presets.cfg` **in both presets**: `version/code` (+1; it must always increase) and `version/name` (`MAJOR.MINOR.PATCH`). Commit and merge.
2. Check `main` is green on CI, including the emulator E2E and both AAB rehearsals.
3. Run **Release AAB** with the new `version_code`.
4. Install the universal APK built from the bundle on a test device and play a puzzle. With ads, check that the consent form appears (EEA test device) and that a **test** rewarded ad loads on a registered test device. Never click your own live ads.
5. Run `scripts/measure_device.sh` on the reference phone (see `QA_REPORT.md`).
6. Upload to **internal testing**, then closed testing, then production with a staged rollout (e.g. 10% → 50% → 100%).
7. Tag the commit: `git tag v<version_name> && git push origin v<version_name>`; attach the `.sha256` and `aab_report.txt` to the GitHub release notes.

## If the upload key is lost or leaked
With Play App Signing, ask for an **upload key reset** in Play Console (*App integrity → Request upload key reset*): create a new keystore (section 1), send Google its certificate, then replace the three secrets. Your app's identity is not affected.

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
