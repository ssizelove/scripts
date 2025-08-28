Dev Scripts (Flutter iOS + Android)

Handy scripts to bootstrap and keep Flutter projects sane on macOS (iOS + Android). Built for repeatability: clone → align → run.

Files
	•	mobile_align.sh — One-stop aligner for iOS & Android (Podfile, xcconfigs, Base Configs, Pod install, Java 17, Android SDK path, local.properties, precache).
	•	flutter-new — Wrapper around flutter create that scaffolds a project and runs iOS alignment automatically.
	•	fix_ios_pods.rb — Idempotent fixer: sets Runner Base Configs to Flutter xcconfigs, writes canonical xcconfigs, and ensures Pods play nice.
	•	verify_ios_pods.rb — Prints the Runner target’s Base Configs and checks xcconfig contents + Pods support files.
	•	keepawake.sh — Small helper to keep the Mac awake during long builds (optional).
	•	cheatsheet — Quick reference commands (personal notes).
	•	usage.txt, startup_help.txt — Getting started snippets (personal notes).

Tip: mobile_align.sh subsumes most one-offs; keep the others for targeted tasks or when you want to verify/repair iOS only.

#############################################
0) New project (iOS + Android ready)
cd ~/dev
flutter-new myapp --org com.example --platforms ios,android
open -a Simulator && flutter run -d "iPhone 16 Plus"

1) Align an existing/cloned project
mobile_align.sh           # aligns iOS + Android
# or:
mobile_align.sh --ios
mobile_align.sh --android

What it does (iOS):
	•	Ensures ios/Podfile exists (writes a minimal one if missing)
	•	Writes canonical ios/Flutter/Debug|Profile|Release.xcconfig (2 lines each)
	•	Sets Runner → Base Configuration → those xcconfigs
	•	Runs pod install
	•	Removes ios/.gitignore (prevents it from ignoring Generated.xcconfig)
	•	Force-tracks ios/Podfile + all .xcconfig files in Git

What it does (Android):
	•	Precache Android artifacts for the current Flutter
	•	Ensures android/local.properties points to your SDK
	•	Verifies Java 17; tries to set JAVA_HOME if missing
	•	Installs core SDK components (if sdkmanager is on PATH)
	•	Prints Gradle wrapper version

2) “iOS is weird again”
ruby ~/scripts/verify_ios_pods.rb
# if any row shows "(none)" or xcconfig checks fail:
ruby ~/scripts/fix_ios_pods.rb
(cd ios && pod install)
ruby ~/scripts/verify_ios_pods.rb
flutter clean
open -a Simulator && flutter run -d "iPhone 16 Plus"

3) Rename app or bundleId (optional)
dart pub global activate rename
rename setAppName  --value "My Cool App"
# rename setBundleId --value "com.example.mycoolapp"   # only if you want a new app identity
flutter clean && (cd ios && pod install) && flutter run

Git Hygiene (important)

Track these:
	•	ios/Podfile
	•	ios/Flutter/Generated.xcconfig
	•	ios/Flutter/Debug.xcconfig
	•	ios/Flutter/Profile.xcconfig
	•	ios/Flutter/Release.xcconfig
	•	ios/Runner.xcodeproj (workspace can be regenerated but project should be tracked)

Ignore these:
	•	ios/Pods/
	•	ios/Podfile.lock
	•	ios/Flutter/ephemeral/
	•	ios/Flutter/flutter_export_environment.sh
	•	**/DerivedData/
	•	*.xcworkspace/xcuserdata/
	•	android/local.properties
	•	**/build/
	•	.dart_tool/, .pub/, .pub-cache/, etc.

The aligner auto-removes ios/.gitignore and force-adds Podfile + xcconfigs, so clones won’t break.

⸻

Troubleshooting Quickies
	•	“Missing: ios/Flutter/Generated.xcconfig”
	•	Run: flutter pub get (or fvm flutter pub get)
	•	Then re-run: mobile_align.sh --ios
	•	CocoaPods warning: “did not set the base configuration…”
	•	Run: ruby ~/scripts/fix_ios_pods.rb && (cd ios && pod install)
	•	Then flutter clean && flutter run
	•	CocoaPods 1.16.x oddities (e.g., platform_name)
	•	Prefer 1.15.2:
sudo gem uninstall cocoapods -aIx && sudo gem install --no-document cocoapods -v 1.15.2 -n /usr/local/bin
	•	Android: Gradle/JDK mismatch
	•	Ensure Java 17:
export JAVA_HOME="$("/usr/libexec/java_home" -v 17)"
	•	Accept licenses / install tools:
yes | sdkmanager --licenses && sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0"
	•	Flutter version mismatch / Dart SDK error
	•	Use FVM per project:
fvm install 3.35.2 && fvm use 3.35.2 && fvm flutter pub get


One-liners
	•	Show iOS Base Configs:
		ruby ~/scripts/verify_ios_pods.rb
	•	Force add critical iOS files:
		git add -f ios/Podfile ios/Flutter/*.xcconfig
	•	Keep Mac awake during long builds:
		~/scripts/keepawake.sh

