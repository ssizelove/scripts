#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
usage: $(basename "$0") <project_dir> <bundle_or_package_id>

Align iOS and Android identifiers to the given ID.
Examples:
  $(basename "$0") \$PWD com.example.myapp
EOF
}

APP_DIR="${1:-}"
NEW_ID="${2:-}"
[[ -n "$APP_DIR" && -n "$NEW_ID" ]] || { usage; exit 1; }
cd "$APP_DIR" || { echo "Project not found: $APP_DIR"; exit 1; }
[[ -f pubspec.yaml ]] || { echo "Run from Flutter project root"; exit 1; }

STAMP="$(date +%Y%m%d-%H%M%S)"
if command -v git >/dev/null 2>&1 && [ -d .git ]; then
  git add -A || true
  git commit -m "checkpoint before mobile_align ($STAMP)" || true
fi

echo "──────── ANDROID"
ANDROID_APP="android/app"
GR_KTS="$ANDROID_APP/build.gradle.kts"
GR_GROOVY="$ANDROID_APP/build.gradle"
GR="$GR_KTS"; [[ -f "$GR" ]] || GR="$GR_GROOVY"
[[ -f "$GR" ]] || { echo "Missing $GR_KTS / $GR_GROOVY"; exit 1; }

# applicationId / namespace
if [[ "$GR" == *".kts" ]]; then
  grep -qE 'applicationId\s*=' "$GR" \
    && sed -i '' -E "s#applicationId\s*=\s*\"[^\"]+\"#applicationId = \"${NEW_ID}\"#g" "$GR" \
    || sed -i '' -E "s/(defaultConfig\s*\\{)/\\1\n        applicationId = \"${NEW_ID}\"/g" "$GR"
  grep -qE 'namespace\s*=' "$GR" \
    && sed -i '' -E "s#namespace\s*=\s*\"[^\"]+\"#namespace = \"${NEW_ID}\"#g" "$GR" \
    || sed -i '' -E "s/(android\s*\\{)/\\1\n    namespace = \"${NEW_ID}\"/g" "$GR"
else
  grep -q 'applicationId "' "$GR" \
    && sed -i '' -E "s/applicationId \"[^\"]+\"/applicationId \"${NEW_ID//\//\\/}\"/" "$GR" \
    || sed -i '' -E "s/(defaultConfig\s*\{)/\\1\n        applicationId \"${NEW_ID//\//\\/}\"/" "$GR"
  grep -q 'namespace "' "$GR" \
    && sed -i '' -E "s/namespace \"[^\"]+\"/namespace \"${NEW_ID//\//\\/}\"/" "$GR" \
    || sed -i '' -E "s/(android\s*\{)/\\1\n    namespace \"${NEW_ID//\//\\/}\"/" "$GR"
fi

# Move MainActivity.kt and fix package line (if kotlin tree exists)
SRC_ROOT="$ANDROID_APP/src/main/kotlin"
if [[ -d "$SRC_ROOT" ]]; then
  MAIN_KT="$(find "$SRC_ROOT" -type f -name "MainActivity.kt" -maxdepth 10 2>/dev/null | head -n1 || true)"
  if [[ -n "$MAIN_KT" ]]; then
    CUR_DIR="$(dirname "$MAIN_KT")"
    NEW_DIR="$SRC_ROOT/$(echo "$NEW_ID" | tr '.' '/')"
    mkdir -p "$NEW_DIR"
    [[ "$CUR_DIR" != "$NEW_DIR" ]] && mv "$CUR_DIR"/* "$NEW_DIR"/ 2>/dev/null || true
    sed -i '' -E "s/^package .*/package ${NEW_ID}/" "$NEW_DIR/MainActivity.kt"
    find "$SRC_ROOT" -type d -empty -delete || true
  fi
fi

# Update manifests
for MF in "$ANDROID_APP/src/main/AndroidManifest.xml" "$ANDROID_APP/src/debug/AndroidManifest.xml" "$ANDROID_APP/src/profile/AndroidManifest.xml"; do
  [[ -f "$MF" ]] || continue
  grep -q 'package=' "$MF" && sed -i '' -E "s/package=\"[^\"]+\"/package=\"${NEW_ID}\"/" "$MF"
done

echo "──────── iOS"
IOS_PROJ="ios/Runner.xcodeproj"
[[ -d "$IOS_PROJ" ]] || { echo "Missing $IOS_PROJ"; exit 1; }

# Set bundle id in all configs
/usr/bin/env ruby - "$IOS_PROJ" "$NEW_ID" <<'RUBY'
require 'xcodeproj'
proj_path, bundle_id = ARGV
p = Xcodeproj::Project.open(proj_path)
t = p.targets.find { |x| x.name == 'Runner' } or abort "Runner target not found"
t.build_configurations.each { |cfg| cfg.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = bundle_id }
p.save
puts "✅ Set PRODUCT_BUNDLE_IDENTIFIER=#{bundle_id}"
RUBY

# Ensure Info.plist uses $(PRODUCT_BUNDLE_IDENTIFIER)
PLIST="ios/Runner/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier \$(PRODUCT_BUNDLE_IDENTIFIER)" "$PLIST" 2>/dev/null || true

# Ensure canonical xcconfigs under ios/Flutter
mkdir -p ios/Flutter
printf '#include? "../Pods/Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig"\n#include? "Generated.xcconfig"\n'   > ios/Flutter/Debug.xcconfig
printf '#include? "../Pods/Target Support Files/Pods-Runner/Pods-Runner.profile.xcconfig"\n#include? "Generated.xcconfig"\n' > ios/Flutter/Profile.xcconfig
printf '#include? "../Pods/Target Support Files/Pods-Runner/Pods-Runner.release.xcconfig"\n#include? "Generated.xcconfig"\n' > ios/Flutter/Release.xcconfig

# Point Runner Base Configurations to those xcconfigs
/usr/bin/env ruby - <<'RUBY'
require 'xcodeproj'
p = Xcodeproj::Project.open('ios/Runner.xcodeproj')
t = p.targets.find{ |x| x.name == 'Runner' } or abort "Runner target not found"
{
  'Debug'=>'Flutter/Debug.xcconfig',
  'Profile'=>'Flutter/Profile.xcconfig',
  'Release'=>'Flutter/Release.xcconfig'
}.each do |name, path|
  ref = p.files.find{ |f| f.path == path } || p.new_file(path)
  cfg = t.build_configurations.find{ |c| c.name == name }
  cfg.base_configuration_reference = ref if cfg
end
p.save
puts "✅ Base Configurations set to ios/Flutter/*.xcconfig"
RUBY

# CocoaPods install
( cd ios && pod install )

echo "✅ mobile_align complete for ${NEW_ID}"
