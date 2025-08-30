#!/usr/bin/env bash
set -euo pipefail

PROJ="${1:-$PWD}"
cd "$PROJ" || { echo "Project not found: $PROJ"; exit 1; }
[[ -f pubspec.yaml ]] || { echo "Run this from your Flutter project root"; exit 1; }

STAMP="$(date +%Y%m%d-%H%M%S)"
ATTIC="lib/_attic/$STAMP"
mkdir -p "$ATTIC"

echo "📦 Creating checkpoint commit (if git repo)…"
if command -v git >/dev/null 2>&1 && [ -d .git ]; then
  git add -A || true
  git commit -m "checkpoint before households refactor ($STAMP)" || true
fi

echo "📁 Parking old profile-related files into $ATTIC"

# Use find instead of mapfile to collect candidates
CANDIDATES=$(find lib -type f \( \
  -name 'profile*.dart' -o \
  -name 'profiles*.dart' -o \
  -name 'auth_selector*.dart' -o \
  -name 'avatar*.dart' -o \
  -name 'household_service*.dart' -o \
  -name 'profile_service*.dart' -o \
  -name 'reset_household_button*.dart' -o \
  -name 'grocery_list_page*.dart' \
\) 2>/dev/null || true)

COUNT=0
for f in $CANDIDATES; do
  [ -e "$f" ] || continue
  base="$(basename "$f")"
  dest="$ATTIC/$base"
  if [[ -e "$dest" ]]; then
    i=1
    while [[ -e "$ATTIC/${base%.dart}-$i.dart" ]]; do ((i++)); done
    dest="$ATTIC/${base%.dart}-$i.dart"
  fi
  mkdir -p "$(dirname "$dest")"
  git mv "$f" "$dest" 2>/dev/null || mv "$f" "$dest"
  echo "  ↪︎ $f -> $dest"
  COUNT=$((COUNT+1))
done

echo "🧹 Done. Moved $COUNT file(s) to $ATTIC"
if command -v git >/dev/null 2>&1 && [ -d .git ]; then
  git add -A || true
  git commit -m "park old profile flow into _attic ($STAMP)" || true
fi

echo "Next: say 'Stage 2' and I’ll give you full replacements for:"
echo " - lib/main.dart"
echo " - lib/app_providers.dart"
echo " - lib/widgets/app_lock_gate.dart"
echo " - lib/pages/home_page.dart"
