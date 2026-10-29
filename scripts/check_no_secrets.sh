#!/usr/bin/env bash
# Fails if signing material or owner-only config is tracked by git.
# Runs in CI on every push; the release keystore and passwords must only ever
# exist in the owner's secure storage and in GitHub Actions secrets.
set -euo pipefail
cd "$(dirname "$0")/.."
tracked="$(git ls-files -- '*.jks' '*.keystore' '*.p12' '*.pfx' '*.pem' '*.key' \
  'keystore.properties' 'ads_release.json' '.env' '*.jks.b64' '*.keystore.b64' || true)"
if [[ -n "$tracked" ]]; then
  echo "!! signing material or secret config is committed:" >&2
  echo "$tracked" >&2
  exit 1
fi
# Base64 PKCS12/JKS blobs pasted into text files ("MII..." / "/u3+7Q").
if git grep -lE '^(MII[A-Za-z0-9+/]{60,}|/u3\+7Q[A-Za-z0-9+/]{40,})' -- . ':!addons/gut' >/dev/null 2>&1; then
  echo "!! a file looks like it contains a base64-encoded keystore:" >&2
  git grep -lE '^(MII[A-Za-z0-9+/]{60,}|/u3\+7Q[A-Za-z0-9+/]{40,})' -- . ':!addons/gut' >&2
  exit 1
fi
echo "check_no_secrets: OK (no keystores, keys or ads_release.json tracked)"
