#!/usr/bin/env bash
# Copies version-checked Built-in Kotlin build.gradle patches into pub-cache.
# Run after `flutter pub get` when building with AGP 9 built-in Kotlin enabled.
# See docs/DEPENDENCIES.md § Android Built-in Kotlin / KGP.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCK_FILE="$PROJECT_ROOT/pubspec.lock"
MANIFEST_FILE="$SCRIPT_DIR/kgp-patches/manifest.json"

if [[ ! -f "$LOCK_FILE" ]]; then
  echo "pubspec.lock not found at $LOCK_FILE" >&2
  exit 1
fi

if [[ -z "${PUB_CACHE:-}" ]]; then
  PUB_CACHE="$HOME/.pub-cache"
fi
PUB_HOSTED="$PUB_CACHE/hosted/pub.dev"

get_locked_version() {
  local package="$1"
  awk -v pkg="$package" '
    $0 ~ "^  " pkg ":$" { found=1; next }
    found && $0 ~ /^  [a-zA-Z0-9_]+:/ { exit 1 }
    found && $0 ~ /version: "/ {
      gsub(/.*version: "/, "")
      gsub(/".*/, "")
      print
      exit
    }
  ' "$LOCK_FILE"
}

apply_patch() {
  local package="$1"
  local patch_file="$2"
  local target_rel="$3"
  local locked_version expected_prefix expected_version
  local patch_source plugin_dir patch_target

  locked_version="$(get_locked_version "$package")"
  expected_prefix="${patch_file%-build.gradle}"
  expected_version="${expected_prefix#*-}"

  if [[ "$locked_version" != "$expected_version" ]]; then
    echo "Locked version for '$package' is '$locked_version' but patch expects '$expected_version'. Update scripts/kgp-patches/ before patching." >&2
    exit 1
  fi

  patch_source="$SCRIPT_DIR/kgp-patches/$patch_file"
  plugin_dir="$PUB_HOSTED/${package}-${locked_version}"
  patch_target="$plugin_dir/$target_rel"

  if [[ ! -f "$patch_source" ]]; then
    echo "Patch file missing: $patch_source" >&2
    exit 1
  fi
  if [[ ! -d "$plugin_dir" ]]; then
    echo "Plugin not found in pub cache: $plugin_dir (run flutter pub get)" >&2
    exit 1
  fi

  cp "$patch_source" "$patch_target"
  echo "Patched: $patch_target"
}

apply_patch "pedometer" "pedometer-4.2.0-build.gradle" "android/build.gradle"
apply_patch "share_plus" "share_plus-13.1.0-build.gradle" "android/build.gradle"
apply_patch "workmanager_android" "workmanager_android-0.9.0+2-build.gradle" "android/build.gradle"

echo "KGP plugin patches applied."
