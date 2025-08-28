#!/usr/bin/env bash
set -euo pipefail

# ------------------------------
# Config / helpers
# ------------------------------
FLUTTER="flutter"; [[ -d ".fvm/flutter_sdk" ]] && FLUTTER="fvm flutter"
say()  { printf "\033[1;32m%s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m%s\033[0m\n" "$*"; }
die()  { printf "\033[1;31m%s\033[0m\n" "$*"; exit 1; }

DO_IOS=true
DO_ANDROID=true
while (($#)); do
  case "$1" in
    --ios) DO_IOS=true; DO_ANDROID=false;;
    --android) DO_ANDROID=true; DO_IOS=false;;
    --both) DO_IOS=true; DO_ANDROID=true;;
    *) warn "Unknown flag $1 ignored";;
  esac
  shift || true
done

[[ -f pubspec.yaml ]] || die "Run from project root (pubspec.yaml missing)."
say "▶ Using: $($FLUTTER --version | head -n1)"

IN_GIT=false; git rev-parse --is-inside-work-tree >/dev/null 2>&1 && IN_GIT=true

# ------------------------------
# iOS alignment
# ------------------------------
align_ios() {
  say "=== iOS: align ==="

  # Nuke nested ios/.gitignore (overrides root rules)
  if [[ -f ios/.gitignore ]]; then
    warn "Removing ios/.gitignore (it can ignore xcconfigs)"
    rm -f ios/.gitignore
    $IN_GIT && git rm --cached -q ios/.gitignore || true
  fi

  # Scaffolding + artifacts
  say "▶ flutter pub get"
  $FLUTTER pub get
  say "▶ flutter create --platforms=ios ."
  $FLUTTER create --platforms=ios .
  say "▶ flutter precache --ios"
  $FLUTTER precache --ios

  [[ -f ios/Flutter/Generated.xcconfig ]] || die "Generated.xcconfig missing."

  # Podfile (create minimal if missing)
  if [[ ! -f ios/Podfile ]]; then
    warn "Podfile missing — writing minimal Podfile"
    cat > ios/Podfile <<'PODFILE'
platform :ios, '15.0'
ENV['COCOAPODS_DISABLE_STATS'] = 'true'
project 'Runner', { 'Debug' => :debug, 'Profile' => :release, 'Release' => :release }

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "Missing: #{generated_xcode_build_settings_path}. Run 'flutter pub get' first."
  end
  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}"
end

require File.expand_path(File.join(flutter_root, 'packages', 'flutter_tools', 'bin', 'podhelper'), __FILE__)
flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks! :linkage => :static
  use_modular_headers!
  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
end

post_install do |installer|
  installer.pods_project.targets.each do |t|
    t.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end
PODFILE
  fi

  # Canonical xcconfigs (Pods include first, then Generated)
  say "▶ write ios/Flutter/*.xcconfig"
  mkdir -p ios/Flutter
  printf '#include? "../Pods/Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig"\n#include? "Generated.xcconfig"\n'   > ios/Flutter/Debug.xcconfig
  printf '#include? "../Pods/Target Support Files/Pods-Runner/Pods-Runner.profile.xcconfig"\n#include? "Generated.xcconfig"\n' > ios/Flutter/Profile.xcconfig
  printf '#include? "../Pods/Target Support Files/Pods-Runner/Pods-Runner.release.xcconfig"\n#include? "Generated.xcconfig"\n' > ios/Flutter/Release.xcconfig

  # Set Base Configs on Runner
  say "▶ set Base Configurations on Runner target"
  if ! ruby -e "require 'xcodeproj'" >/dev/null 2>&1; then
    warn "Installing 'xcodeproj' gem (one-time)…"
    gem install --no-document xcodeproj >/dev/null
  fi
  ruby <<'RUBY'
require 'xcodeproj'
p = Xcodeproj::Project.open('ios/Runner.xcodeproj')
t = p.targets.find { |x| x.name == 'Runner' } or abort("Runner target not found")
def ensure_ref(p, rel) p.files.find { |f| f.path == rel } || p.new_file(rel) end
{'Debug'=>'Flutter/Debug.xcconfig','Profile'=>'Flutter/Profile.xcconfig','Release'=>'Flutter/Release.xcconfig'}.each do |name,rel|
  cfg = t.build_configurations.find{|c|c.name==name} or abort("Config #{name} missing")
  cfg.base_configuration_reference = ensure_ref(p, rel)
end
p.save
RUBY

  # Force-track essentials
  if $IN_GIT; then
    say "▶ ensure Podfile + xcconfigs are tracked in Git"
    git add -f ios/Podfile ios/Flutter/Generated.xcconfig ios/Flutter/Debug.xcconfig ios/Flutter/Profile.xcconfig ios/Flutter/Release.xcconfig 2>/dev/null || true
  fi

  # Pods
  say "▶ pod install"
  (cd ios && pod install)
  say "✓ iOS aligned"
}

# ------------------------------
# Android alignment
# ------------------------------
align_android() {
  say "=== Android: align ==="

  # Precache Android artifacts
  say "▶ flutter precache --android"
  $FLUTTER precache --android

  # Ensure Android scaffold
  say "▶ flutter create --platforms=android ."
  $FLUTTER create --platforms=android .

  # Java 17 check
  if command -v java >/dev/null 2>&1; then
    JVER=$(java -version 2>&1 | head -n1)
    echo "Java: $JVER"
  else
    warn "Java not found. Install Temurin 17 (JDK 17) and set JAVA_HOME."
  fi

  # Try to auto-configure JAVA_HOME for macOS Temurin 17
  if [[ -z "${JAVA_HOME:-}" ]]; then
    if /usr/libexec/java_home -v 17 >/dev/null 2>&1; then
      export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
      warn "Set JAVA_HOME to $JAVA_HOME for this shell. Consider adding to ~/.zprofile."
    fi
  fi

  # Android SDK path & local.properties
  ANDROID_SDK_DEFAULT="$HOME/Library/Android/sdk"
  if [[ -z "${ANDROID_SDK_ROOT:-}" ]]; then
    export ANDROID_SDK_ROOT="$ANDROID_SDK_DEFAULT"
  fi
  if [[ ! -d "$ANDROID_SDK_ROOT" ]]; then
    warn "Android SDK not found at $ANDROID_SDK_ROOT. Install Android Studio to get it."
  fi

  mkdir -p android
  if [[ ! -f android/local.properties ]]; then
    say "▶ writing android/local.properties"
    cat > android/local.properties <<EOF
sdk.dir=${ANDROID_SDK_ROOT}
EOF
  fi

  # Core SDK components (best-effort)
  if command -v sdkmanager >/dev/null 2>&1; then
    say "▶ sdkmanager essentials (licenses, platform-tools, latest platform/build-tools)"
    yes | sdkmanager --licenses >/dev/null || true
    sdkmanager "platform-tools" >/dev/null || true
    sdkmanager "platforms;android-35" >/dev/null || true
    sdkmanager "build-tools;35.0.0" >/dev/null || true
  else
    warn "sdkmanager not on PATH. Open Android Studio → SDK Manager to install platform-tools, Android 35, Build-tools 35."
  fi

  # Gradle sanity (print wrapper version)
  if [[ -f android/gradle/wrapper/gradle-wrapper.properties ]]; then
    echo "Gradle wrapper:"
    grep -E '^distributionUrl=' android/gradle/wrapper/gradle-wrapper.properties || true
  fi

  # Force-track nothing Android-specific (local.properties should stay untracked)
  if $IN_GIT; then
    # Ensure .gitignore ignores local.properties; add if missing
    if ! grep -q '^android/local.properties$' .gitignore 2>/dev/null; then
      echo "android/local.properties" >> .gitignore
      git add .gitignore
      warn "Added android/local.properties to .gitignore"
    fi
  fi

  say "✓ Android aligned (Java 17 + SDK path + essentials)"
}

# ------------------------------
# Run
# ------------------------------
$DO_IOS && align_ios
$DO_ANDROID && align_android

say "✅ Done. Next:"
echo "   $FLUTTER clean"
echo "   open -a Simulator && $FLUTTER run -d \"iPhone 16 Plus\"   # iOS"
echo "   $FLUTTER run -d chrome                                    # Web"
echo "   adb devices && $FLUTTER run -d <deviceId>                  # Android device/emulator"
