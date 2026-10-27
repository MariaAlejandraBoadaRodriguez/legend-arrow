#!/usr/bin/env bash
# Exports the release Android App Bundle and validates it with bundletool.
#
#   Real release (owner): ads_release.json present + upload key in env:
#     GODOT_ANDROID_KEYSTORE_RELEASE_PATH / _USER / _PASSWORD
#     scripts/export_release.sh
#   CI rehearsal (never uploaded): throwaway key, test ads config, ads disabled:
#     scripts/export_release.sh --rehearsal
#
# Output: build/android/legend-arrow-release.aab (+ .sha256, aab_report.txt,
# universal APK built from the bundle for the same checks as the debug APK).
# Needs ANDROID_HOME, JAVA_HOME, the LegendAds AAR (scripts/build_ads_plugin.sh)
# and network for templates/bundletool on first run.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
REHEARSAL=0
[[ "${1:-}" == "--rehearsal" ]] && REHEARSAL=1
GODOT="${GODOT:-$("$ROOT/scripts/install_godot.sh")}"
OUT_DIR="$ROOT/build/android"
AAB="$OUT_DIR/legend-arrow-release.aab"
BUNDLETOOL_VERSION="1.18.1"
BUNDLETOOL_SHA256="675786493983787ffa11550bdb7c0715679a44e1643f3ff980a529e9c822595c"
: "${ANDROID_HOME:?ANDROID_HOME must point to an Android SDK}"
: "${JAVA_HOME:?JAVA_HOME must point to JDK 17}"
mkdir -p "$OUT_DIR"

# Templates + editor settings + debug keystore are shared with the debug export.
SKIP_DEBUG_EXPORT=1 "$ROOT/scripts/export_android.sh" >/dev/null

if (( REHEARSAL )); then
  export LEGEND_RELEASE_REHEARSAL=1
  [[ ! -f "$ROOT/ads_release.json" ]] || { echo "!! rehearsal must not use ads_release.json" >&2; exit 1; }
  KEY="$ROOT/build/rehearsal-upload.keystore"   # throwaway, regenerated per run
  rm -f "$KEY"
  PASS="$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 20)"
  "$JAVA_HOME/bin/keytool" -genkeypair -keystore "$KEY" -alias rehearsal -storepass "$PASS" -keypass "$PASS" \
    -dname "CN=Legend Arrow CI rehearsal (not for Play)" -keyalg RSA -keysize 2048 -validity 30 >/dev/null 2>&1
  export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KEY"
  export GODOT_ANDROID_KEYSTORE_RELEASE_USER="rehearsal"
  export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$PASS"
else
  : "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:?set the upload keystore (see docs/RELEASE.md)}"
  : "${GODOT_ANDROID_KEYSTORE_RELEASE_USER:?}"
  : "${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:?}"
  [[ -f "$ROOT/ads_release.json" ]] || { echo "!! ads_release.json missing (docs/ADS_AND_PRIVACY.md)" >&2; exit 1; }
fi

rm -f "$AAB"
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$ROOT" --install-android-build-template --export-release "Android AAB" "$AAB" 2>&1 | tee "$OUT_DIR/export_release.log"
[[ -s "$AAB" ]] || { echo "!! export produced no AAB" >&2; exit 1; }
if grep -E "^ERROR|SCRIPT ERROR|USER ERROR" "$OUT_DIR/export_release.log"; then
  echo "!! release export logged errors" >&2; exit 1
fi

# bundletool (pinned + checksum-verified).
BT_JAR="${BUNDLETOOL_JAR:-$ROOT/build/bundletool-$BUNDLETOOL_VERSION.jar}"
if [[ ! -f "$BT_JAR" ]]; then
  curl -sSLf --retry 4 --retry-delay 2 -o "$BT_JAR" \
    "https://github.com/google/bundletool/releases/download/$BUNDLETOOL_VERSION/bundletool-all-$BUNDLETOOL_VERSION.jar"
fi
echo "$BUNDLETOOL_SHA256  $BT_JAR" | sha256sum -c - >/dev/null || { echo "!! bundletool checksum mismatch" >&2; exit 1; }
bt() { "$JAVA_HOME/bin/java" -jar "$BT_JAR" "$@"; }

REPORT="$OUT_DIR/aab_report.txt"
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
{
  echo "mode: $([[ $REHEARSAL == 1 ]] && echo 'REHEARSAL (throwaway key, ads disabled, NOT for upload)' || echo 'release')"
  check "bundletool validate" 'bt validate --bundle="$AAB" >/dev/null'
  manifest="$(bt dump manifest --bundle="$AAB")"
  pkg="$(grep -o 'package="[^"]*"' <<<"$manifest" | head -1 | cut -d'"' -f2)"
  vcode="$(grep -o 'android:versionCode="[^"]*"' <<<"$manifest" | head -1 | cut -d'"' -f2)"
  vname="$(grep -o 'android:versionName="[^"]*"' <<<"$manifest" | head -1 | cut -d'"' -f2)"
  target="$(grep -o 'android:targetSdkVersion="[^"]*"' <<<"$manifest" | head -1 | cut -d'"' -f2)"
  echo "package=$pkg versionCode=$vcode versionName=$vname targetSdk=$target"
  check "package id" '[[ "$pkg" == "com.mariaalejandraboada.legendarrow" ]]'
  check "targetSdk >= 35 (Play requirement)" '[[ -n "$target" && "$target" -ge 35 ]]'
  check "release build is not debuggable" '! grep -q "android:debuggable=\"true\"" <<<"$manifest"'
  check "no AD_ID / Privacy Sandbox ad permissions" '! grep -qE "permission.AD_ID|ACCESS_ADSERVICES" <<<"$manifest"'
  files="$(unzip -l "$AAB" | awk '{print $4}')"
  check "arm64-v8a native libs" 'grep -q "^base/lib/arm64-v8a/.*\.so$" <<<"$files"'
  check "armeabi-v7a native libs (32-bit phones)" 'grep -q "^base/lib/armeabi-v7a/.*\.so$" <<<"$files"'
  check "no tests/tools/docs packaged" '! grep -qE "^base/assets/(tests|tools|docs|addons/gut)/" <<<"$files"'
  # Universal APK from the bundle -> same identity / 16 KB / signature checks.
  rm -rf "$OUT_DIR/universal"
  mkdir -p "$OUT_DIR/universal"
  bt build-apks --bundle="$AAB" --output="$OUT_DIR/universal/u.apks" --mode=universal \
    --ks="$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" --ks-key-alias="$GODOT_ANDROID_KEYSTORE_RELEASE_USER" \
    --ks-pass="pass:$GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD" >/dev/null
  unzip -q -o "$OUT_DIR/universal/u.apks" universal.apk -d "$OUT_DIR/universal"
  check "universal APK from bundle passes check_apk (release)" \
    'EXPECT_ADS_PLUGIN=0 "$ROOT/scripts/check_apk.sh" "$OUT_DIR/universal/universal.apk" > "$OUT_DIR/universal/apk_report.txt"'
  # Download size per device configuration (spec §14: <= 120 MB per delivery).
  bt build-apks --bundle="$AAB" --output="$OUT_DIR/universal/split.apks" \
    --ks="$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" --ks-key-alias="$GODOT_ANDROID_KEYSTORE_RELEASE_USER" \
    --ks-pass="pass:$GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD" >/dev/null
  sizes="$(bt get-size total --apks="$OUT_DIR/universal/split.apks" --dimensions=ABI | tr -d '\r')"  # CRLF output
  echo "download size by ABI (bytes, MIN,MAX):"; echo "$sizes"
  max_arm64="$(awk -F, '/arm64-v8a/ {print $3}' <<<"$sizes")"
  check "arm64 phone download <= 120 MB (spec §14)" '[[ "$max_arm64" =~ ^[0-9]+$ ]] && (( max_arm64 <= 125829120 ))'
  echo "REPORT COMPLETE"
} | tee "$REPORT"
# The block runs in a pipeline subshell: trust only a complete report.
grep -q "^REPORT COMPLETE" "$REPORT" || { echo "!! AAB checks aborted early" >&2; fail=1; }
if grep -q "^FAIL" "$REPORT"; then fail=1; fi
(cd "$OUT_DIR" && sha256sum "$(basename "$AAB")" > "$(basename "$AAB").sha256")
cat "$OUT_DIR/$(basename "$AAB").sha256"
rm -f "$ROOT/build/rehearsal-upload.keystore"
exit $fail
