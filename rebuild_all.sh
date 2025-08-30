#!/usr/bin/env bash
set -euo pipefail
PROJ="${1:-$PWD}"
cd "$PROJ" || { echo "Project not found: $PROJ"; exit 1; }

echo "🧹 Full Flutter clean in $PWD"
flutter clean || true
fvm flutter pub get || flutter pub get
fvm flutter precache --ios --android || flutter precache --ios --android

echo "📱 Android cleanup"
pushd android >/dev/null
./gradlew clean || true
rm -rf .gradle app/build build
popd >/dev/null

echo "🍎 iOS cleanup"
pushd ios >/dev/null
rm -rf Pods Podfile.lock
pod repo update
pod install
popd >/dev/null
rm -rf ~/Library/Developer/Xcode/DerivedData/*

if [[ -x "$HOME/scripts/mobile_align.sh" ]]; then
  "$HOME/scripts/mobile_align.sh" --ios --android
fi

echo "✅ Full rebuild done."
echo 'Run iOS:     fvm flutter run -d "iPhone 16 Plus"'
echo 'Run Android: fvm flutter run -d emulator-5554'
