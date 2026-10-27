#!/usr/bin/env bash
# Builds and verifies the LegendAds Android plugin, then copies the AAR to
# addons/legend_ads/bin/ for Godot's Gradle export.
#   scripts/build_ads_plugin.sh            core tests + Android unit tests + lint + AAR
#   scripts/build_ads_plugin.sh --core     only the SDK-independent core tests
# Needs JDK 17 and (except --core) Google Maven + an Android SDK (ANDROID_HOME).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN="$ROOT/android/plugins/legend_ads"
GRADLE_ARGS=(--no-daemon --stacktrace -Dorg.gradle.internal.repository.max.retries=8 -Dorg.gradle.internal.repository.initial.backoff=2000)
REPORTS="$ROOT/build/reports/kotlin"
mkdir -p "$REPORTS"

cd "$PLUGIN"
if [[ "${1:-}" == "--core" ]]; then
  ./gradlew "${GRADLE_ARGS[@]}" -PcoreOnly=true :core:test
else
  ./gradlew "${GRADLE_ARGS[@]}" :core:test :plugin:testReleaseUnitTest :plugin:lintRelease :plugin:assembleRelease
  mkdir -p "$ROOT/addons/legend_ads/bin"
  cp plugin/build/outputs/aar/plugin-release.aar "$ROOT/addons/legend_ads/bin/legend_ads-release.aar"
  cp -r plugin/build/reports/lint-results-release.* "$REPORTS/" 2>/dev/null || true
fi
cp -r core/build/test-results/test "$REPORTS/core-tests"

# Fail on zero discovered tests or any failure (same rule as GDScript tests).
python3 - "$REPORTS/core-tests" <<'PY'
import glob, sys, xml.etree.ElementTree as ET
cases = failed = 0
for f in glob.glob(sys.argv[1] + "/*.xml"):
    r = ET.parse(f).getroot()
    cases += int(r.get("tests", 0)); failed += int(r.get("failures", 0)) + int(r.get("errors", 0)) + int(r.get("skipped", 0))
print(f"kotlin core tests: {cases} discovered, {failed} failed/errored/skipped")
sys.exit(0 if cases > 0 and failed == 0 else 1)
PY
echo "== build_ads_plugin: PASS"
