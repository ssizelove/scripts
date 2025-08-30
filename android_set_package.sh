#!/usr/bin/env bash
set -euo pipefail
PKG="com.sizelove.adhdapp"
APP_DIR="${1:-$PWD}"

cd "$APP_DIR/android/app/src" || { echo "Run from project root"; exit 1; }

# 1) Move Kotlin source tree to match package
# Detect current path (e.g., main/kotlin/com/old/path)
CUR_DIR=$(find main/kotlin -type f -name "MainActivity.kt" -exec dirname {} \;)
if [[ -z "${CUR_DIR:-}" ]]; then
  echo "MainActivity.kt not found"; exit 1
fi

# Build desired path
NEW_DIR="main/kotlin/$(echo "$PKG" | tr '.' '/')"
mkdir -p "$NEW_DIR"

# Move files
mv "$CUR_DIR"/* "$NEW_DIR"/

# Fix package line in Kotlin
sed -i '' -E "s/^package .*/package ${PKG}/" "$NEW_DIR/MainActivity.kt"

# 2) Update all AndroidManifests' package attributes (debug/profile/main)
for f in main/AndroidManifest.xml debug/AndroidManifest.xml profile/AndroidManifest.xml; do
  [[ -f "$f" ]] || continue
  # Replace package="...":
  if grep -q 'package=' "$f"; then
    sed -i '' -E "s/package=\"[^\"]+\"/package=\"${PKG}\"/" "$f"
  else
    # Some templates omit package= on manifest; skip
    :
  fi
done

echo "✅ Android package set to ${PKG}"
