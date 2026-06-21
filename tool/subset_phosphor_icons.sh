#!/usr/bin/env bash
# Regenerate Phosphor Regular/Fill subset fonts from phosphoricons_flutter pub-cache.
# Requires: pip install fonttools  (pyftsubset)
# Run from repo root: ./tool/subset_phosphor_icons.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG="${PUB_CACHE:-$HOME/.pub-cache}/hosted/pub.dev/phosphoricons_flutter-1.0.0/lib/fonts"
OUT="$ROOT/assets/fonts"

if [[ ! -d "$PKG" ]]; then
  echo "Source fonts not found at $PKG" >&2
  exit 1
fi

REGULAR='U+E03E,U+E058,U+E06C,U+E08E,U+E108,U+E13A,U+E150,U+E156,U+E182,U+E19A,U+E242,U+EA88,U+E2F0,U+E316,U+E32A,U+ED60,U+E47C,U+E67E'
FILL='U+E150,U+E2F0,U+ED60'
ARGS=(--layout-features='*' --glyph-names --symbol-cmap --legacy-cmap
      --notdef-glyph --notdef-outline --recommended-glyphs
      --name-IDs='*' --name-legacy --name-languages='*')

pyftsubset "$PKG/Phosphor.ttf" --unicodes="$REGULAR" \
  --output-file="$OUT/Phosphor-Regular-subset.ttf" "${ARGS[@]}"

pyftsubset "$PKG/Phosphor-Fill.ttf" --unicodes="$FILL" \
  --output-file="$OUT/Phosphor-Fill-subset.ttf" "${ARGS[@]}"

echo "Wrote assets/fonts/Phosphor-Regular-subset.ttf and Phosphor-Fill-subset.ttf"
