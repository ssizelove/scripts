#!/usr/bin/env bash
set -euo pipefail

# firebase_align.sh
# Reset local Firebase config and regenerate lib/firebase_options.dart
# for a specific Firebase *project id* and app *bundle/package id*.
#
# Usage:
#   ~/scripts/firebase_align.sh <FIREBASE_PROJECT_ID> <APP_ID> [PROJECT_DIR]
# Example:
#   ~/scripts/firebase_align.sh adhd-organizer-v2 com.sizelove.adhdapp ~/dev/adhd_app
#
# Notes:
# - Uses the FVM-safe runner for FlutterFire CLI.
# - Requires the Firebase CLI ('firebase') to be installed & logged in.

PROJECT_ID="${1:-}"; APP_ID="${2:-}"; APP_DIR="${3:-$PWD}"
[[ -n "$PROJECT_ID" && -n "$APP_ID" ]] || { echo "usage: $(basename "$0") <project_id> <bundle_or_package_id> [project_dir]"; exit 1; }
cd "$APP_DIR" || { echo "Project dir not found: $APP_DIR"; exit 1; }
[[ -f pubspec.yaml ]] || { echo "Run from your Flutter project root (pubspec.yaml missing)"; exit 1; }

echo "────────────────────────────────────────────────────────"
echo "🔧 Firebase align"
echo "  project:   $PROJECT_ID"
echo "  app id:    $APP_ID   (iOS bundle id + Android package name)"
echo "  projectDir: $APP_DIR"
echo "────────────────────────────────────────────────────────"

# 0) sanity: firebase CLI present?
if ! command -v firebase >/dev/null 2>&1; then
  echo "❌ 'firebase' CLI not found."
  echo "   Install without npm:    curl -Lo \$HOME/bin/firebase https://firebase.tools/bin/macos/latest && chmod +x \$HOME/bin/firebase && export PATH=\"\$HOME/bin:\$PATH\""
  echo "   Then run: firebase login"
  exit 1
fi

# 0.1) sanity: flutterfire CLI via FVM?
if ! fvm dart pub global run flutterfire_cli:flutterfire --version >/dev/null 2>&1; then
  echo "ℹ️  Activating FlutterFire CLI under FVM Dart..."
  fvm dart pub global activate flutterfire_cli
fi

echo "✅ firebase version: $(firebase --version)"
echo "✅ flutterfire version: $(fvm dart pub global run flutterfire_cli:flutterfire --version || echo unknown)"

# 1) backup/remove local config that can confuse the CLI
STAMP="$(date +%Y%m%d-%H%M%S)"
for f in firebase.json .firebaserc lib/firebase_options.dart; do
  if [[ -f "$f" ]]; then
    cp "$f" "$f.bak.$STAMP"
    rm -f "$f"
    echo "🧹 removed $f (backup at $f.bak.$STAMP)"
  fi
done

# 2) force-generate options for this project + exact IDs
echo "⚙️  Running FlutterFire configure (explicit)…"
fvm dart pub global run flutterfire_cli:flutterfire configure \
  --project="$PROJECT_ID" \
  --platforms=ios,android \
  --ios-bundle-id="$APP_ID" \
  --android-package-name="$APP_ID" \
  --out=lib/firebase_options.dart

# 3) quick verify the generated file
if [[ ! -f lib/firebase_options.dart ]]; then
  echo "❌ lib/firebase_options.dart was not generated."
  exit 2
fi

PROJ_LINE="$(grep -E "projectId:\s*'[^']+'" lib/firebase_options.dart | head -n1 || true)"
IOS_LINE="$(grep -E "iosBundleId:\s*'[^']+'" lib/firebase_options.dart | head -n1 || true)"

echo "────────────────────────────────────────────────────────"
echo "🔎 Generated lib/firebase_options.dart summary:"
echo "   ${PROJ_LINE:-projectId not found}"
if [[ -n "$IOS_LINE" ]]; then
  echo "   ${IOS_LINE}"
else
  echo "   (iosBundleId line not found here; that’s ok on non-iOS targets)"
fi
echo "────────────────────────────────────────────────────────"

echo "✅ Firebase alignment complete."
echo "Next:"
echo "  1) fvm flutter clean && fvm flutter pub get"
echo "  2) fvm flutter run -d \"iPhone 16 Plus\""
echo "  3) (optional) add a debug log to print DefaultFirebaseOptions.currentPlatform.projectId at startup"
