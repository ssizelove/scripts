Dev Scripts (Flutter iOS + Android)

Handy scripts to bootstrap and keep Flutter projects sane on macOS (iOS + Android). Built for repeatability: clone → align → run.

PREREQS (copy/paste all):
	1.	Install FVM (Flutter Version Manager):
dart pub global activate fvm
echo ‘export PATH=”$HOME/.pub-cache/bin:$PATH”’ >> ~/.zshrc && source ~/.zshrc
	2.	Install a Flutter SDK via FVM and set it per project:
cd <your_project_or_workspace_dir>
fvm install 3.35.2
fvm use 3.35.2
fvm flutter doctor
	3.	Install Firebase CLI (no npm):
mkdir -p “$HOME/bin”
curl -Lo “$HOME/bin/firebase” https://firebase.tools/bin/macos/latest
chmod +x “$HOME/bin/firebase”
echo ‘export PATH=”$HOME/bin:$PATH”’ >> ~/.zshrc && source ~/.zshrc
firebase login
firebase –version
	4.	Install FlutterFire CLI (FVM-safe) and set an alias:
fvm dart pub global activate flutterfire_cli
echo “alias flutterfire=‘fvm dart pub global run flutterfire_cli:flutterfire’” >> ~/.zshrc && source ~/.zshrc
flutterfire –version
	5.	(iOS) CocoaPods recommended version:
sudo gem uninstall cocoapods -aIx || true
sudo gem install –no-document cocoapods -v 1.15.2 -n /usr/local/bin
pod –version
	6.	(Android) Ensure Java 17 and SDK tools:
export JAVA_HOME=”$(”/usr/libexec/java_home” -v 17)”
yes | sdkmanager –licenses || true
sdkmanager “platform-tools” “platforms;android-35” “build-tools;35.0.0” || true

FILES
	•	mobile_align.sh — One-stop aligner for iOS & Android: sets iOS PRODUCT_BUNDLE_IDENTIFIER, ensures Info.plist uses $(PRODUCT_BUNDLE_IDENTIFIER), fixes CocoaPods base configs & runs pod install (or calls ios_align.sh), sets Android applicationId and namespace (supports Kotlin DSL build.gradle.kts), moves MainActivity.kt to the new package path and updates package line.
	•	firebase_align.sh — Reset & regenerate lib/firebase_options.dart for a given Firebase project ID and bundle/package ID (FVM-safe, forces explicit IDs).
	•	flutter-new — Wrapper around flutter create that scaffolds a project and runs iOS alignment automatically.
	•	fix_ios_pods.rb — Idempotent fixer: writes canonical ios/Flutter/Debug|Profile|Release.xcconfig and sets Runner → Base Configuration.
	•	verify_ios_pods.rb — Prints Runner Base Configs and validates xcconfig contents + Pods support files.
	•	keepawake.sh — Keep the Mac awake during long builds (optional).
	•	cheatsheet, usage.txt, startup_help.txt — personal notes.

Tip: mobile_align.sh subsumes most iOS/Android one-offs; use the Ruby verifiers for targeted checks.

NEW PROJECT (iOS + Android)
cd ~/dev
flutter-new myapp –org com.example –platforms ios,android
open -a Simulator && fvm flutter run -d “iPhone 16 Plus”

ALIGN AN EXISTING/CLOTHED PROJECT
From the project root:
~/scripts/mobile_align.sh “$PWD” com.sizelove.adhdapp
(Platform-specific: ~/scripts/mobile_align.sh –ios or ~/scripts/mobile_align.sh –android)

iOS alignment does:
	•	Ensures ios/Podfile exists
	•	Writes canonical ios/Flutter/*.xcconfig (2 lines each)
	•	Sets Runner → Base Configuration to those xcconfigs
	•	Runs pod install (or ios_align.sh)
	•	Ensures Info.plist uses $(PRODUCT_BUNDLE_IDENTIFIER)

Android alignment does:
	•	Sets applicationId and namespace to your target (supports Kotlin DSL build.gradle.kts)
	•	Moves MainActivity.kt into the correct package path & updates package line
	•	(Optional) Gradle clean

POINT THE APP AT THE RIGHT FIREBASE PROJECT/APPS
Use the reset + force-configure script (FVM-safe):
~/scripts/firebase_align.sh adhd-organizer-v2 com.sizelove.adhdapp ~/dev/adhd_app

What it does:
	•	Backs up & removes local firebase.json, .firebaserc, and lib/firebase_options.dart
	•	Runs FlutterFire CLI with explicit:
–project=adhd-organizer-v2
–ios-bundle-id=com.sizelove.adhdapp
–android-package-name=com.sizelove.adhdapp
	•	Writes a fresh lib/firebase_options.dart
	•	Prints a quick summary (projectId, iosBundleId)

Build after alignment:
fvm flutter clean
fvm flutter pub get
fvm flutter run -d “iPhone 16 Plus”

WHEN iOS GETS WEIRD
ruby ~/scripts/verify_ios_pods.rb
if any row shows “(none)” or checks fail:
ruby ~/scripts/fix_ios_pods.rb
(cd ios && pod install)
ruby ~/scripts/verify_ios_pods.rb
fvm flutter clean && fvm flutter run -d “iPhone 16 Plus”

RENAME APP OR BUNDLE ID (optional)
dart pub global activate rename
rename setAppName –value “My Cool App”

rename setBundleId –value “com.example.mycoolapp”   # only if you want a new identity

fvm flutter clean && (cd ios && pod install) && fvm flutter run
If you change IDs, re-run:
~/scripts/mobile_align.sh “$PWD” <new.id>
~/scripts/firebase_align.sh  <new.id>

GIT HYGIENE (important)
Track:
	•	ios/Podfile
	•	ios/Flutter/Generated.xcconfig
	•	ios/Flutter/Debug.xcconfig
	•	ios/Flutter/Profile.xcconfig
	•	ios/Flutter/Release.xcconfig
	•	ios/Runner.xcodeproj (workspace can be regenerated, but the project should be tracked)

Ignore:
	•	ios/Pods/
	•	ios/Podfile.lock
	•	ios/Flutter/ephemeral/
	•	ios/Flutter/flutter_export_environment.sh
	•	**/DerivedData/
	•	*.xcworkspace/xcuserdata/
	•	android/local.properties
	•	**/build/
	•	.dart_tool/, .pub/, .pub-cache/, etc.

The aligner ensures Podfile + xcconfigs are kept in Git (and any rogue ios/.gitignore won’t hide them).

TROUBLESHOOTING QUICKIES
	•	Missing: ios/Flutter/Generated.xcconfig
Run: fvm flutter pub get
Then: ~/scripts/mobile_align.sh –ios
	•	CocoaPods warning: “did not set the base configuration …”
Run: ruby ~/scripts/fix_ios_pods.rb && (cd ios && pod install)
Then: fvm flutter clean && fvm flutter run
	•	CocoaPods 1.16.x oddities (platform_name)
Prefer 1.15.2:
sudo gem uninstall cocoapods -aIx
sudo gem install –no-document cocoapods -v 1.15.2 -n /usr/local/bin
	•	Android: Gradle/JDK mismatch
Ensure Java 17:
export JAVA_HOME=”$(”/usr/libexec/java_home” -v 17)”
	•	Android SDK / licenses
yes | sdkmanager –licenses
sdkmanager “platform-tools” “platforms;android-35” “build-tools;35.0.0”
	•	Flutter/Dart mismatch or “Invalid kernel binary format version” with FlutterFire
Always run FlutterFire via FVM:
fvm dart pub global activate flutterfire_cli
(optional alias)
echo “alias flutterfire=‘fvm dart pub global run flutterfire_cli:flutterfire’” >> ~/.zshrc && source ~/.zshrc
If the CLI keeps failing, hard reset:
rm -f ~/.pub-cache/bin/flutterfire
fvm dart pub global deactivate flutterfire_cli || true
fvm dart pub global activate flutterfire_cli
	•	Flutter version per project (FVM)
fvm install 3.35.2 && fvm use 3.35.2 && fvm flutter pub get

ONE-LINERS
	•	Show iOS Base Configs: ruby ~/scripts/verify_ios_pods.rb
	•	Force-add critical iOS files: git add -f ios/Podfile ios/Flutter/*.xcconfig
	•	Keep Mac awake during long builds: ~/scripts/keepawake.sh

# Verify bundle/package IDs + Firebase linkage
ruby -e 'require "xcodeproj";p=Xcodeproj::Project.open("ios/Runner.xcodeproj");t=p.targets.find{|x|x.name=="Runner"};puts "iOS: #{t.build_configurations.map{|c|c.build_settings["PRODUCT_BUNDLE_IDENTIFIER"]}.uniq}";'
grep -nE 'applicationId\s*=' android/app/build.gradle.kts
grep -nE 'namespace\s*=' android/app/build.gradle.kts
grep -A3 'projectId' lib/firebase_options.dart

