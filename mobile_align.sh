#!/usr/bin/env bash
set -euo pipefail

# mobile_align.sh — unify Android + iOS IDs for a Flutter app (Groovy or Kotlin DSL)
# Usage:
#   ~/scripts/mobile_align.sh /path/to/flutter_project [com.sizelove.adhdapp]

APP_DIR="${1:-$PWD}"
NEW_ID="${2:-com.sizelove.adhdapp}"

cd "$APP_DIR" || { echo "Project not found: $APP_DIR"; exit 1; }
[[ -f pubspec.yaml ]] || { echo "Run from your Flutter project root (pubspec.yaml missing)"; exit 1; }

STAMP="$(date +%Y%m%d-%H%M%S)"
if command -v git >/dev/null 2>&1 && [ -d .git ]; then
  git add -A || true
  git commit -m "checkpoint before mobile_align ($STAMP)" || true
fi

echo "────────────────────────────────────────────────────────"
echo "🔧 ANDROID: setting package/applicationId/namespace = ${NEW_ID}"
echo "────────────────────────────────────────────────────────"
ANDROID_APP="android/app"
GRADLE_GROOVY="$ANDROID_APP/build.gradle"
GRADLE_KTS="$ANDROID_APP/build.gradle.kts"

if [[ -f "$GRADLE_KTS" ]]; then
  GRADLE_FILE="$GRADLE_KTS"
  IS_KTS=1
elif [[ -f "$GRADLE_GROOVY" ]]; then
  GRADLE_FILE="$GRADLE_GROOVY"
  IS_KTS=0
else
  echo "Missing $GRADLE_GROOVY and $GRADLE_KTS"
  exit 1
fi

# 1) applicationId / namespace in build.gradle(.kts)
if [[ "$IS_KTS" -eq 1 ]]; then
  # Kotlin DSL examples:
  # defaultConfig { applicationId = "com.example.app" }
  # android { namespace = "com.example.app" }
  if grep -qE 'applicationId\s*=' "$GRADLE_FILE"; then
    sed -i '' -E "s#applicationId\s*=\s*\"[^\"]+\"#applicationId = \"${NEW_ID}\"#g" "$GRADLE_FILE"
  else
    # Insert inside defaultConfig { ... }
    sed -i '' -E "s/(defaultConfig\s*\\{)/\\1\n        applicationId = \"${NEW_ID}\"/g" "$GRADLE_FILE"
  fi
  if grep -qE 'namespace\s*=' "$GRADLE_FILE"; then
    sed -i '' -E "s#namespace\s*=\s*\"[^\"]+\"#namespace = \"${NEW_ID}\"#g" "$GRADLE_FILE"
  else
    # Insert inside android { ... }
    sed -i '' -E "s/(android\s*\\{)/\\1\n    namespace = \"${NEW_ID}\"/g" "$GRADLE_FILE"
  fi
else
  # Groovy DSL
  if grep -q 'applicationId "' "$GRADLE_FILE"; then
    sed -i '' -E "s/applicationId \"[^\"]+\"/applicationId \"${NEW_ID//\//\\/}\"/" "$GRADLE_FILE"
  else
    sed -i '' -E "s/(defaultConfig\s*\{)/\\1\n        applicationId \"${NEW_ID//\//\\/}\"/" "$GRADLE_FILE"
  fi
  if grep -q 'namespace "' "$GRADLE_FILE"; then
    sed -i '' -E "s/namespace \"[^\"]+\"/namespace \"${NEW_ID//\//\\/}\"/" "$GRADLE_FILE"
  else
    sed -i '' -E "s/(android\s*\{)/\\1\n    namespace \"${NEW_ID//\//\\/}\"/" "$GRADLE_FILE"
  fi
fi

# 2) Move Kotlin source tree to match package
SRC_ROOT="$ANDROID_APP/src/main/kotlin"
if [[ -d "$SRC_ROOT" ]]; then
  MAIN_KT="$(find "$SRC_ROOT" -type f -name "MainActivity.kt" -maxdepth 10 2>/dev/null | head -n1 || true)"
  if [[ -n "${MAIN_KT:-}" ]]; then
    CUR_DIR="$(dirname "$MAIN_KT")"
    NEW_DIR="$SRC_ROOT/$(echo "$NEW_ID" | tr '.' '/')"
    mkdir -p "$NEW_DIR"
    # Move contents if not already there
    if [[ "$CUR_DIR" != "$NEW_DIR" ]]; then
      mv "$CUR_DIR"/* "$NEW_DIR"/ 2>/dev/null || true
      # Update package declaration
      sed -i '' -E "s/^package .*/package ${NEW_ID}/" "$NEW_DIR/MainActivity.kt"
      # Clean empty old dirs
      find "$SRC_ROOT" -type d -empty -delete || true
      echo "✅ MainActivity moved to $NEW_DIR"
    else
      # Still update package line just in case
      sed -i '' -E "s/^package .*/package ${NEW_ID}/" "$NEW_DIR/MainActivity.kt"
      echo "ℹ️  MainActivity already in $NEW_DIR"
    fi
  else
    echo "ℹ️  MainActivity.kt not found under $SRC_ROOT (OK for older templates)"
  fi
else
  echo "ℹ️  $SRC_ROOT not present (Java template or different structure)"
fi

# 3) Update manifest package attributes (main/debug/profile) if present
for MF in "$ANDROID_APP/src/main/AndroidManifest.xml" \
          "$ANDROID_APP/src/debug/AndroidManifest.xml" \
          "$ANDROID_APP/src/profile/AndroidManifest.xml"; do
  [[ -f "$MF" ]] || continue
  if grep -q 'package=' "$MF"; then
    sed -i '' -E "s/package=\"[^\"]+\"/package=\"${NEW_ID}\"/" "$MF"
  fi
done

echo "────────────────────────────────────────────────────────"
echo "🍎  iOS: setting PRODUCT_BUNDLE_IDENTIFIER = ${NEW_ID}"
echo "────────────────────────────────────────────────────────"
IOS_PROJ="ios/Runner.xcodeproj"
[[ -d "$IOS_PROJ" ]] || { echo "Missing $IOS_PROJ"; exit 1; }

# Inline Ruby to update all Runner configs (note the '-' before args)
/usr/bin/env ruby - "$IOS_PROJ" "$NEW_ID" <<'RUBY'
require 'xcodeproj'
proj_path = ARGV[0]
bundle_id = ARGV[1]
p = Xcodeproj::Project.open(proj_path)
t = p.targets.find { |x| x.name == 'Runner' } or abort "Runner target not found"
t.build_configurations.each do |cfg|
  cfg.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = bundle_id
end
p.save
puts "✅ Set PRODUCT_BUNDLE_IDENTIFIER=#{bundle_id} for Runner (all configs)"
RUBY

# Ensure Info.plist uses $(PRODUCT_BUNDLE_IDENTIFIER)
PLIST="ios/Runner/Info.plist"
/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$PLIST" >/dev/null 2>&1 || true
if /usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$PLIST" 2>/dev/null | grep -vq '\$\(' ; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier \$(PRODUCT_BUNDLE_IDENTIFIER)" "$PLIST" || true
fi
echo "✅ Info.plist uses \$(PRODUCT_BUNDLE_IDENTIFIER)"
# 4) Align Pods
if [[ -x "$HOME/scripts/ios_align.sh" ]]; then
  echo "📚 Running ios_align.sh"
  "$HOME/scripts/ios_align.sh"
else
  echo "📚 Running 'pod install' in ios/"
  (cd ios && pod install)
fi

if command -v git >/dev/null 2>&1 && [ -d .git ]; then
  git add -A || true
  git commit -m "mobile_align: set IDs to ${NEW_ID}" || true
fi

echo "────────────────────────────────────────────────────────"
echo "✅ Done. IDs set to: ${NEW_ID}"
echo "Next:"
echo "  1) flutterfire configure   # select the project + the iOS/Android apps using ${NEW_ID}"
echo "  2) fvm flutter clean && fvm flutter pub get"
echo "  3) fvm flutter run -d \"iPhone 16 Plus\""
echo "────────────────────────────────────────────────────────"
