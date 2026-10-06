#!/usr/bin/env bash
set -euo pipefail

NEW_PKG="${1:-}"
APP_DIR="${2:-$PWD}"

if [[ -z "$NEW_PKG" ]]; then
  echo "usage: $(basename "$0") <new.package.id> [project_dir]"
  exit 1
fi

cd "$APP_DIR/android/app/src" || { echo "Run from project root"; exit 1; }

# 1) Move Kotlin source tree to match package
CUR_DIR=$(find main/kotlin -type f -name "MainActivity.kt" -exec dirname {} \; | head -n1)
[[ -n "${CUR_DIR:-}" ]] || { echo "MainActivity.kt not found"; exit 1; }

NEW_DIR="main/kotlin/$(echo "$NEW_PKG" | tr '.' '/')"
mkdir -p "$NEW_DIR"
mv "$CUR_DIR"/* "$NEW_DIR"/ 2>/dev/null || true
sed -i '' -E "s/^package .*/package ${NEW_PKG}/" "$NEW_DIR/MainActivity.kt"

# 2) Update AndroidManifest package attrs
for f in main/AndroidManifest.xml debug/AndroidManifest.xml profile/AndroidManifest.xml; do
  [[ -f "$f" ]] || continue
  if grep -q 'package=' "$f"; then
    sed -i '' -E "s/package=\"[^\"]+\"/package=\"${NEW_PKG}\"/" "$f"
  fi
done

echo "✅ Android package set to ${NEW_PKG}"
