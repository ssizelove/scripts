#!/bin/bash
# verify-signing.sh — robust entitlements/profile check for an .xcarchive (handles spaces)

set -euo pipefail

# 1) Resolve archive path (argument or latest)
if [[ $# -ge 1 ]]; then
  ARCHIVE_PATH="$1"
else
  # Find the most recent .xcarchive under the default Archives folder
  ARCHIVE_PATH="$(find "$HOME/Library/Developer/Xcode/Archives" -type d -name "*.xcarchive" -print0 \
    | xargs -0 stat -f "%m %N" 2>/dev/null \
    | sort -nr \
    | head -n1 \
    | cut -d' ' -f2-)"
fi

if [[ -z "${ARCHIVE_PATH:-}" || ! -d "$ARCHIVE_PATH" ]]; then
  echo "❌ Could not locate an .xcarchive. Pass one explicitly:"
  echo "   ./verify-signing.sh \"/full/path/Your Archive.xcarchive\""
  exit 1
fi

echo "📦 Using archive:"
echo "   $ARCHIVE_PATH"
echo

# 2) Locate the .app inside the archive (don’t assume Runner.app)
APP_PATH="$(find "$ARCHIVE_PATH/Products/Applications" -maxdepth 1 -type d -name "*.app" | head -n1 || true)"
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "❌ No .app found under: $ARCHIVE_PATH/Products/Applications"
  exit 1
fi

echo "🟩 App bundle:"
echo "   $APP_PATH"
echo

# 3) Entitlements (look for aps-environment)
echo "=== Embedded Entitlements (expect 'production' for TestFlight/App Store) ==="
if ! codesign -d --entitlements :- "$APP_PATH" 2>/dev/null | grep -A3 -E "aps-environment|com.apple.developer.aps-environment"; then
  echo "⚠️  No aps-environment key found in embedded entitlements."
fi
echo

# 4) Embedded provisioning profile (works for manual & automatic signing)
echo "=== Embedded Provisioning Profile (name, team, app id, aps env) ==="
if [[ -f "$APP_PATH/embedded.mobileprovision" ]]; then
  security cms -D -i "$APP_PATH/embedded.mobileprovision" 2>/dev/null \
    | /usr/bin/xpath -q -e \
      '//*[local-name()="Name" or local-name()="AppIDName" or local-name()="TeamIdentifier" or local-name()="application-identifier" or local-name()="aps-environment"]/text()' \
      2>/dev/null || true

  # Fallback grep if xpath not available:
  security cms -D -i "$APP_PATH/embedded.mobileprovision" 2>/dev/null \
    | grep -E "Name|AppIDName|TeamIdentifier|application-identifier|aps-environment" || true
else
  echo "⚠️  No embedded.mobileprovision found (OK for manual/profiles-in-managed case, but unusual)."
fi
echo

# 5) Code-signing identity details
echo "=== Code Sign Identity (expect Apple Distribution for Release) ==="
codesign -dv --verbose=4 "$APP_PATH" 2>&1 | grep -E "Authority|TeamIdentifier|Sealed Resources" || true
echo

# 6) Info: which entitlements file Xcode *thinks* it used (from the CodeResources)
echo "=== Declared entitlements file inside bundle (if any) ==="
if [[ -f "$APP_PATH/CodeResources" ]]; then
  /usr/libexec/PlistBuddy -c "Print files2" "$APP_PATH/CodeResources" 2>/dev/null | grep -i entitlements || echo "(not listed)"
else
  echo "(No CodeResources plist present)"
fi
echo

echo "✅ Done."
echo "Check above for:"
echo "  • aps-environment = production (for TestFlight/App Store pushes)"
echo "  • Provisioning profile ties to the correct Team & App ID"
echo "  • CodeSign Authority = Apple Distribution"
