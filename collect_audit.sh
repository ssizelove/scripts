#!/usr/bin/env bash
set -euo pipefail

OUT="adhd_app_audit.md"
APP="${PWD##*/}"
SEP() { printf '\n\n---\n\n' >> "$OUT"; }
ADD() { printf "\n\n### %s\n\n" "$1" >> "$OUT"; shift; }

echo "# Audit: $APP" > "$OUT"
date >> "$OUT"

ADD "Flutter / Dart versions"
{
  echo '```'
  (flutter --version || true)
  (fvm flutter --version || true)
  echo
  (flutter doctor -v || true)
  echo '```'
} >> "$OUT"

ADD "Project structure (depth 3)"
{
  echo '```'
  if command -v tree >/dev/null; then
    tree -L 3 -I 'build|.dart_tool|.fvm|Pods|ephemeral|DerivedData|.git|android/.gradle|android/.idea|*.xcworkspace|*.xcuserdata'
  else
    # tree fallback
    find . -maxdepth 3 \
      -not -path "*/build/*" \
      -not -path "*/.dart_tool/*" \
      -not -path "*/.fvm/*" \
      -not -path "*/Pods/*" \
      -not -path "*/ephemeral/*" \
      -not -path "*/DerivedData/*" \
      -not -path "*/.git/*" \
      -not -path "*/android/.gradle/*" \
      -not -path "*/android/.idea/*" \
      -not -path "*/*.xcworkspace/*" \
      -not -path "*/*.xcuserdata/*"
  fi
  echo '```'
} >> "$OUT"

ADD "pubspec.yaml"
{ echo '```yaml'; sed -n '1,220p' pubspec.yaml; echo '```'; } >> "$OUT"

ADD "lib/firebase_options.dart (safe to show)"
{ echo '```dart'; sed -n '1,200p' lib/firebase_options.dart 2>/dev/null || echo 'MISSING'; echo '```'; } >> "$OUT"

ADD "Key Dart files (main/login/auth/tasks)"
for f in \
  lib/main.dart \
  lib/login_page.dart \
  lib/auth_selector_page.dart \
  lib/auth_gate.dart \
  lib/tasks.dart
do
  echo -e "\n\n#### ${f}\n" >> "$OUT"
  echo '```dart' >> "$OUT"
  sed -n '1,400p' "$f" 2>/dev/null || echo "MISSING: $f" >> "$OUT"
  echo '```' >> "$OUT"
done

ADD "All providers (files mentioning Riverpod providers)"
{
  echo '```'
  grep -R -nE 'Provider<|StateProvider|FutureProvider|StreamProvider|Notifier|Riverpod' lib 2>/dev/null || echo "(none found)"
  echo '```'
} >> "$OUT"

ADD "Entire lib/ (concatenated, up to ~200 lines per file)"
for f in $(find lib -type f -name '*.dart' | sort); do
  echo -e "\n\n#### ${f}\n" >> "$OUT"
  echo '```dart' >> "$OUT"
  sed -n '1,200p' "$f" >> "$OUT"
  echo '```' >> "$OUT"
done

ADD "iOS Podfile"
{ echo '```ruby'; sed -n '1,240p' ios/Podfile 2>/dev/null || echo 'MISSING'; echo '```'; } >> "$OUT"

ADD "iOS xcconfigs"
for f in ios/Flutter/Generated.xcconfig ios/Flutter/Debug.xcconfig ios/Flutter/Profile.xcconfig ios/Flutter/Release.xcconfig; do
  echo -e "\n\n#### ${f}\n" >> "$OUT"
  echo '```ini' >> "$OUT"
  sed -n '1,120p' "$f" 2>/dev/null || echo "MISSING: $f" >> "$OUT"
  echo '```' >> "$OUT"
done

ADD "Android build.gradle & wrapper"
{ echo '```'; sed -n '1,240p' android/app/build.gradle 2>/dev/null || echo 'MISSING'; echo '```'; } >> "$OUT"

{ echo '```'; sed -n '1,200p' android/build.gradle 2>/dev/null || true; echo '```'; } >> "$OUT"

{ echo '```'; sed -n '1,200p' android/gradle/wrapper/gradle-wrapper.properties 2>/dev/null || true; echo '```'; } >> "$OUT"

ADD ".gitignore (root)"
{ echo '```'; sed -n '1,240p' .gitignore 2>/dev/null || echo 'MISSING'; echo '```'; } >> "$OUT"

ADD "flutter analyze (summary)"
{
  echo '```'
  (flutter analyze || true)
  echo '```'
} >> "$OUT"

ADD "dart pub outdated (summary)"
{
  echo '```'
  (dart pub outdated || true)
  echo '```'
} >> "$OUT"

echo
echo "Wrote $OUT"
