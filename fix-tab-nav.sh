#!/usr/bin/env bash
set -euo pipefail

TARGET_FILE="lib/pages/home_shell.dart"
BACKUP_FILE="${TARGET_FILE}.bak"
TMP_FILE="$(mktemp)"

if [[ ! -f "$TARGET_FILE" ]]; then
  echo "❌ $TARGET_FILE not found (expected lib/pages/home_shell.dart)"
  exit 1
fi

cp "$TARGET_FILE" "$BACKUP_FILE"

# Replace any Navigator push on tab change with Riverpod tab state
awk '
  /onDestinationSelected:/ {
    print "            onDestinationSelected: (i) =>";
    print "                ref.read(currentTabProvider.notifier).state = i,";
    skip=1; next
  }
  skip==1 && /Navigator\.push/ { next }
  skip==1 && /Navigator\.pushReplacement/ { next }
  skip==1 && /, *$/ { skip=0; print; next }
  { print }
' "$BACKUP_FILE" > "$TMP_FILE"

mv "$TMP_FILE" "$TARGET_FILE"
echo "✅ Patched $TARGET_FILE (backup at $BACKUP_FILE)"
