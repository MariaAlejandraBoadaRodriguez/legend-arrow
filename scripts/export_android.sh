#!/usr/bin/env bash
# Exports the Android debug APK (Gradle build with the LegendAds plugin) and
# inspects it. Run scripts/build_ads_plugin.sh first.
#   scripts/export_android.sh            -> build/android/legend-arrow-debug.apk (+ .sha256, apk_report.txt)
# Needs: ANDROID_HOME (SDK with build-tools), Java 17 (JAVA_HOME), network for
# the first template download. The debug keystore is generated locally if
# missing; it is NOT a release key and is never committed.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
GODOT="${GODOT:-$("$ROOT/scripts/install_godot.sh")}"
GODOT_VERSION="4.7.2-stable"
TEMPLATE_DIR_NAME="4.7.2.stable"
TPZ_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_export_templates.tpz"
TEMPLATES="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${TEMPLATE_DIR_NAME}"
OUT_DIR="$ROOT/build/android"
APK="$OUT_DIR/legend-arrow-debug.apk"
: "${ANDROID_HOME:?ANDROID_HOME must point to an Android SDK}"
: "${JAVA_HOME:?JAVA_HOME must point to JDK 17}"

# 1. Export templates (Android only, to save disk).
if [[ ! -f "$TEMPLATES/android_debug.apk" ]]; then
  mkdir -p "$TEMPLATES"
  tmp="$(mktemp -d)"
  if [[ -n "${GODOT_TEMPLATES_TPZ:-}" && -f "${GODOT_TEMPLATES_TPZ}" ]]; then
    cp "$GODOT_TEMPLATES_TPZ" "$tmp/t.tpz"
  else
    curl -sSLf --retry 4 --retry-delay 2 -o "$tmp/t.tpz" "$TPZ_URL"
  fi
  unzip -q -o "$tmp/t.tpz" 'templates/android_*' 'templates/version.txt' -d "$tmp"
  cp "$tmp"/templates/* "$TEMPLATES/"
  rm -rf "$tmp"
fi
cat "$TEMPLATES/version.txt"; echo

# 2. Editor settings: SDK and JDK paths (both file names used by Godot 4.x).
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/godot"
mkdir -p "$CFG"
for f in editor_settings-4.tres editor_settings-4.7.tres; do
  cat > "$CFG/$f" <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$ANDROID_HOME"
export/android/java_sdk_path = "$JAVA_HOME"
EOF
done

# 3. Debug keystore (throwaway, standard debug credentials).
KEYSTORE="${DEBUG_KEYSTORE:-$ROOT/build/debug.keystore}"
mkdir -p "$(dirname "$KEYSTORE")"
if [[ ! -f "$KEYSTORE" ]]; then
  "$JAVA_HOME/bin/keytool" -genkeypair -keystore "$KEYSTORE" -alias androiddebugkey \
    -storepass android -keypass android -dname "CN=Android Debug,O=Android,C=US" \
    -keyalg RSA -keysize 2048 -validity 10000 >/dev/null
fi
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$KEYSTORE"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER="androiddebugkey"
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="android"

[[ "${SKIP_DEBUG_EXPORT:-0}" == "1" ]] && exit 0   # setup only (used by export_release.sh)

# 4. Export (Gradle build: bundles the LegendAds plugin AAR).
AAR="$ROOT/addons/legend_ads/bin/legend_ads-release.aar"
[[ -f "$AAR" ]] || { echo "!! $AAR missing: run scripts/build_ads_plugin.sh first" >&2; exit 1; }
mkdir -p "$OUT_DIR"
rm -f "$APK"
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$ROOT" --install-android-build-template --export-debug "Android" "$APK" 2>&1 | tee "$OUT_DIR/export.log"
[[ -s "$APK" ]] || { echo "!! export produced no APK" >&2; exit 1; }
if grep -E "^ERROR|SCRIPT ERROR" "$OUT_DIR/export.log"; then
  echo "!! export logged errors" >&2; exit 1
fi

# 5. Inspect.
"$ROOT/scripts/check_apk.sh" "$APK" | tee "$OUT_DIR/apk_report.txt"
(cd "$OUT_DIR" && sha256sum "$(basename "$APK")" > "$(basename "$APK").sha256")
cat "$OUT_DIR/$(basename "$APK").sha256"
