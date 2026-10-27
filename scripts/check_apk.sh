#!/usr/bin/env bash
# Asserts an APK's identity and native-library requirements.
# Usage: scripts/check_apk.sh path/to.apk   (needs ANDROID_HOME build-tools)
set -euo pipefail
APK="$1"
EXPECTED_PACKAGE="com.mariaalejandraboada.legendarrow"
MIN_SDK_MAX=26        # we promise to run on API 26+
BT="$(ls -d "$ANDROID_HOME"/build-tools/* | sort -V | tail -1)"
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
# aapt2 is preferred; old SDKs/distro packages only ship aapt.
AAPT="$BT/aapt2"; [[ -x "$AAPT" ]] || AAPT="$BT/aapt"

badging="$("$AAPT" dump badging "$APK")"
pkg="$(sed -n "s/^package: name='\([^']*\)'.*/\1/p" <<<"$badging")"
vcode="$(sed -n "s/.*versionCode='\([0-9]*\)'.*/\1/p" <<<"$badging" | head -1)"
vname="$(sed -n "s/.*versionName='\([^']*\)'.*/\1/p" <<<"$badging" | head -1)"
minsdk="$(sed -n "s/^minSdkVersion:'\([0-9]*\)'/\1/p;s/^sdkVersion:'\([0-9]*\)'/\1/p" <<<"$badging" | head -1)"
target="$(sed -n "s/^targetSdkVersion:'\([0-9]*\)'/\1/p" <<<"$badging" | head -1)"
label="$(sed -n "s/^application-label:'\([^']*\)'/\1/p" <<<"$badging" | head -1)"
echo "package=$pkg versionCode=$vcode versionName=$vname minSdk=$minsdk targetSdk=$target label=$label"
grep "uses-permission" <<<"$badging" || true

check "package id is $EXPECTED_PACKAGE" '[[ "$pkg" == "$EXPECTED_PACKAGE" ]]'
check "app label is Legend Arrow" '[[ "$label" == "Legend Arrow" ]]'
check "minSdk <= $MIN_SDK_MAX" '[[ -n "$minsdk" && "$minsdk" -le $MIN_SDK_MAX ]]'
check "versionCode >= 1" '[[ -n "$vcode" && "$vcode" -ge 1 ]]'
check "no location/camera/microphone/contacts permissions" '! grep -qE "LOCATION|CAMERA|RECORD_AUDIO|CONTACTS" <<<"$badging"'

libs="$(unzip -l "$APK" | awk '{print $4}' | grep '^lib/' || true)"
echo "$libs"
check "arm64-v8a engine library present" 'grep -q "^lib/arm64-v8a/.*\.so$" <<<"$libs"'
check "x86_64 library present (emulator)" 'grep -q "^lib/x86_64/.*\.so$" <<<"$libs"'
check "no 32-bit-only ABI without 64-bit" '! grep -q "^lib/armeabi-v7a/" <<<"$libs" || grep -q "^lib/arm64-v8a/" <<<"$libs"'
check "16 KB page size: ELF segments and zip offsets" 'python3 "$(dirname "$0")/check_page_size.py" "$APK"'
check "APK signature verifies" '"$BT/apksigner" verify "$APK" >/dev/null 2>&1'
echo "targetSdk note: spec asks for >= 36; template value is $target (see DECISIONS D-20)."
exit $fail
