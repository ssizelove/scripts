#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${1:-}"; APP_ID="${2:-}"; APP_DIR="${3:-$PWD}"
if [[ -z "$PROJECT_ID" || -z "$APP_ID" ]]; then
  echo "usage: $(basename "$0") <firebase_project_id> <bundle_or_package_id> [project_dir]"
  exit 1
fi

cd "$APP_DIR" || { echo "Project dir not found: $APP_DIR"; exit 1; }
[[ -f pubspec.yaml ]] || { echo "Run from Flutter project root"; exit 1; }

if ! command -v firebase >/dev/null 2>&1; then
  echo "❌ firebase CLI not found. See https://firebase.google.com/docs/cli"
  exit 1
fi

if ! fvm dart pub global run flutterfire_cli:flutterfire --version >/dev/null 2>&1; then
  fvm dart pub global activate flutterfire_cli
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
for f in firebase.json .firebaserc lib/firebase_options.dart; do
  [[ -f "$f" ]] && { cp "$f" "$f.bak.$STAMP"; rm -f "$f"; echo "🧹 removed $f (backup at $f.bak.$STAMP)"; }
done

fvm dart pub global run flutterfire_cli:flutterfire configure \
  --project="$PROJECT_ID" \
  --platforms=ios,android \
  --ios-bundle-id="$APP_ID" \
  --android-package-name="$APP_ID" \
  --out=lib/firebase_options.dart

[[ -f lib/firebase_options.dart ]] || { echo "❌ flutterfire failed"; exit 2; }

echo "✅ Firebase aligned: project=$PROJECT_ID appId=$APP_ID"
