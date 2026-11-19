#!/usr/bin/env bash
# Imports the owner's dragon images (assets/creatures/raw/<dragon_id>.png)
# into game art: cut-out WebP, thumbnail, mask, silhouette (D-49).
# Pinned Python deps in tools/art/requirements.txt (rembg 2.0.67, model
# isnet-general-use, SHA-256 checked by the tool). Fails loudly on any
# missing, misnamed, wrong-size or badly cut file; per-file report on stdout,
# build/art/report.json and docs/ART_STATUS.md.
#   scripts/import_art.sh                 # every roster dragon
#   scripts/import_art.sh forest_drake    # some dragons
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
VENV="${ART_VENV:-$HOME/.cache/legend-arrow/artvenv}"
REQ="tools/art/requirements.txt"
STAMP="$VENV/.requirements.sha256"
want="$(sha256sum "$REQ" | cut -d' ' -f1)"
if [[ ! -x "$VENV/bin/python" || "$(cat "$STAMP" 2>/dev/null)" != "$want" ]]; then
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install --quiet --require-virtualenv -r "$REQ"
  echo "$want" > "$STAMP"
fi
exec "$VENV/bin/python" tools/art/import_art.py "$@"
