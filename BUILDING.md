# Building and testing Legend Arrow

## Pinned toolchain
| Tool | Version | Pinned by |
|---|---|---|
| Godot (editor/headless) | **4.7.2-stable** (`ed1daf0bf`) | `scripts/install_godot.sh` (download URL + SHA-256 `cadd3204…29e4`) |
| GUT test runner | **9.7.1** (`aeb5d4f3f7f0a6c9b5e178876d6c99b791fda605`) | vendored in `addons/gut/` (`VENDORED_VERSION.txt`) |
| Python | 3.x (stdlib only) | JUnit gate `scripts/check_junit.py` |
| GitHub Actions | checkout v7.0.1, cache v6.1.0, upload-artifact v7.0.2 | commit SHAs in `.github/workflows/ci.yml` |
| Android (from M2) | JDK 17, SDK 36, minSdk 26 | added with the export job |

## Run all checks (Linux / CI)
```bash
scripts/verify_all.sh          # downloads pinned Godot on first run
GODOT=/path/to/godot scripts/verify_all.sh   # use an existing binary
```
Steps: headless import → compile every project script (`tools/check_scripts.gd`) → all GUT tests → JUnit gate.
Exit code is nonzero on any failure, parse error, empty discovery, pending test, assertion-free test, or a test file that reports nothing.
Reports: `build/reports/` (`junit.xml`, `summary.json`, `gut.log`, `import.log`, `check_scripts.log`).

## Run tests in the editor (any OS)
Open the project in Godot 4.7.2 → Project Settings → Plugins → enable **Gut** → GUT panel → Run All. Config: `.gutconfig.json`.

## Run a single test file
```bash
$GODOT --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gselect=test_puzzle_board
```

## Android export
Added in M2 (debug APK in CI). Release signing keys and real AdMob IDs are owner-supplied and never committed.
