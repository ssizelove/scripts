Dev Scripts (Project-Agnostic)

These scripts help bootstrap and align Flutter projects for iOS and Android. They are project-agnostic. Pass the bundle/package ID or Firebase project ID as arguments when you run them.

Scripts

flutter-new <app_name> –org com.example –platforms ios,android
Wrapper for flutter create. Creates a new project with iOS + Android scaffolding. Ensures Podfile and xcconfigs are in place.

mobile_align.sh <project_dir> <bundle_id>
Align both iOS and Android to the given id.
	•	Android: sets applicationId + namespace, moves MainActivity.kt, fixes manifests.
	•	iOS: sets PRODUCT_BUNDLE_IDENTIFIER, ensures Info.plist uses $(PRODUCT_BUNDLE_IDENTIFIER), rewrites ios/Flutter/*.xcconfig, runs pod install.

android_set_package.sh <bundle_id> [project_dir]
Android-only: moves MainActivity.kt, fixes package + manifests.

ios_set_bundle_id.rb ios/Runner.xcodeproj <bundle_id>
iOS-only: sets PRODUCT_BUNDLE_IDENTIFIER in Runner configs.

firebase_align.sh <firebase_project_id> <bundle_or_package_id> [project_dir]
Resets Firebase config and regenerates lib/firebase_options.dart. Removes old firebase.json, .firebaserc, firebase_options.dart. Runs flutterfire configure with explicit ids.

fix_ios_pods.rb
Ensures canonical ios/Flutter/Debug|Profile|Release.xcconfig and sets Runner → Base Configurations.

verify_ios_pods.rb
Checks xcconfigs and Pods support files for proper includes and warns if pod install is missing.

rebuild_all.sh <project_dir>
Performs full clean of Flutter, Android, iOS Pods, DerivedData. Re-aligns IDs and re-installs pods.

collect_audit.sh
Generates a markdown audit of your project: versions, structure, pubspec, lib files, Podfile, analyze output, outdated packages.

find_unused_dart.sh
Lists unused Dart files under lib/ that are not imported anywhere.

find_unused_deps.sh
Lists pubspec dependencies not referenced in lib/.

reachable_files.py
Python helper to print reachable vs unreferenced Dart files starting from lib/main.dart.

fix-tab-nav.sh
One-off script to patch tab navigation to use Riverpod provider instead of Navigator pushes.

keepawake.sh
Runs macOS caffeinate to keep the machine awake during long builds.

Workflow

Create a new app:
flutter-new ornaments –org com.sizelove –platforms ios,android

Align IDs:
~/scripts/mobile_align.sh $PWD com.sizelove.ornaments

Link Firebase:
~/scripts/firebase_align.sh ornaments-prod com.sizelove.ornaments $PWD

Run on iOS simulator:
fvm flutter clean
(cd ios && pod install)
open -a Simulator
fvm flutter run -d “iPhone 16 Plus”

Run on web:
fvm flutter run -d chrome

Troubleshooting

CocoaPods warning “did not set the base configuration…”:
ruby ~/scripts/fix_ios_pods.rb && (cd ios && pod install)

Missing ios/Flutter/Generated.xcconfig:
fvm flutter pub get && ~/scripts/mobile_align.sh $PWD com.example.myapp

Switch bundle/package ID later:
~/scripts/mobile_align.sh $PWD com.new.id
~/scripts/firebase_align.sh new-firebase-proj com.new.id $PWD

Cheatsheet One-Liners

List all devices (sim, chrome, android, etc.):
flutter devices

Run on simulator:
open -a Simulator
flutter run -d “iPhone 16 Plus”

Run on web:
flutter run -d chrome

Clean & rebuild if things feel off:
flutter clean
(cd ios && pod install)

Show iOS Base Configs:
ruby ~/scripts/verify_ios_pods.rb

Force-add critical iOS files:
git add -f ios/Podfile ios/Flutter/*.xcconfig

Keep Mac awake during long builds:
~/scripts/keepawake.sh

