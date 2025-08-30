#!/usr/bin/env bash
set -euo pipefail

# Run from project root (where lib/ exists).
if [[ ! -d lib ]]; then
  echo "Run this from your Flutter project root (lib/ missing)."
  exit 1
fi

# Build a list of all Dart files under lib/
FILES=$(find lib -type f -name '*.dart' | sort)

# Collect every referenced path appearing in import/export statements in lib/
# Works with default BSD grep on macOS (no ripgrep needed).
REFERENCES=$(
  grep -R \
       -E '^(import|export)\s+["'\''](package:[^"'\'' ]+|(\.\./)*lib/[^"'\'' ]+|(\.\/)[^"'\'' ]+|[^"'\'' ]+)["'\'']' \
       lib 2>/dev/null \
  | sed -E 's/.*["'\'']([^"'\'' ]+)["'\''].*/\1/' \
  | sed -E "s#^package:${PWD##*/}/##" \
  | sed -E 's#^(\.\/|/)+##' \
  | sed -E 's#^lib/##' \
  | sort -u
)

# Files to never flag as unused (entry points etc.)
ALWAYS_KEEP="^main\.dart$|^firebase_options\.dart$"

echo "=== Unused Dart files (no import/export reference found) ==="
while IFS= read -r f; do
  rel="${f#lib/}"
  # Skip always-keep files
  if echo "$rel" | grep -Eq "$ALWAYS_KEEP"; then
    continue
  fi
  # If rel not in REFERENCES, print it
  if ! echo "$REFERENCES" | grep -Fxq "$rel"; then
    echo "$f"
  fi
done <<< "$FILES"
