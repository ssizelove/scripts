#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f pubspec.yaml ]]; then
  echo "Run this from your Flutter project root (pubspec.yaml missing)."
  exit 1
fi

# Extract top-level dependencies: lines under `dependencies:` until next block
DEPS=$(awk '
  $0 ~ /^dependencies:$/ {deps=1; next}
  $0 ~ /^(dev_dependencies|dependency_overrides|flutter:)/ {deps=0}
  deps && $0 ~ /^[[:space:]]+[a-zA-Z0-9_]+:/ {
    gsub(":",""); gsub(" ",""); print $1
  }' pubspec.yaml | sort -u)

echo "=== Packages not referenced by imports in lib/ (heuristic) ==="
for p in $DEPS; do
  [[ "$p" == "flutter" ]] && continue
  if ! grep -R -n "package:$p/" lib >/dev/null 2>&1; then
    echo "$p"
  fi
done
