#!/usr/bin/env bash
# Regenerate Phosphor Regular/Fill subset fonts from official Phosphor source TTFs.
# Requires: pip install fonttools  (pyftsubset)
# Run from repo root: ./tool/subset_phosphor_icons.sh
#
# phosphor-icons/core releases ship SVG assets only. Source icon fonts (TTF) are
# published in the companion phosphor-icons/web repo (linked from core release notes).

set -euo pipefail

# Pinned to match phosphoricons_flutter 1.0.0 / @phosphor-icons/core v2.0.8 baseline.
PHOSPHOR_WEB_RELEASE="v2.1.2"
BASE_URL="https://github.com/phosphor-icons/web/raw/${PHOSPHOR_WEB_RELEASE}/src"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FONT_DIR="$(dirname "$0")/fonts"
OUT="$ROOT/assets/fonts"

mkdir -p "$FONT_DIR"

download_if_missing() {
  local url="$1"
  local dest="$2"
  if [[ ! -f "$dest" ]]; then
    echo "Downloading $(basename "$dest") from phosphor-icons/web ${PHOSPHOR_WEB_RELEASE} ..."
    curl -fsSL "$url" -o "$dest"
  fi
}

download_if_missing "${BASE_URL}/regular/Phosphor.ttf" "${FONT_DIR}/Phosphor.ttf"
download_if_missing "${BASE_URL}/fill/Phosphor-Fill.ttf" "${FONT_DIR}/Phosphor-Fill.ttf"

REGULAR='U+E03E,U+E058,U+E06C,U+E08E,U+E108,U+E13A,U+E150,U+E156,U+E182,U+E19A,U+E242,U+EA88,U+E2F0,U+E316,U+E32A,U+ED60,U+E47C,U+E67E'
FILL='U+E150,U+E2F0,U+ED60'
ARGS=(--layout-features='*' --glyph-names --symbol-cmap --legacy-cmap
      --notdef-glyph --notdef-outline --recommended-glyphs
      --name-IDs='*' --name-legacy --name-languages='*')

pyftsubset "${FONT_DIR}/Phosphor.ttf" --unicodes="$REGULAR" \
  --output-file="$OUT/Phosphor-Regular-subset.ttf" "${ARGS[@]}"

pyftsubset "${FONT_DIR}/Phosphor-Fill.ttf" --unicodes="$FILL" \
  --output-file="$OUT/Phosphor-Fill-subset.ttf" "${ARGS[@]}"

echo "Wrote assets/fonts/Phosphor-Regular-subset.ttf and Phosphor-Fill-subset.ttf"
