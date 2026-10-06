#!/usr/bin/env bash
set -euo pipefail

# Run from project root (where lib/ exists).
if [[ ! -d lib ]]; then
  echo "Run this from your Flutter project root (lib/ missing)."
  exit 1
fi

APP_NAME="$(basename "$PWD")"

# Collect all dart files under lib (absolute paths, normalized)
ALL_FILES=$(find "$(pwd)/lib" -type f -name '*.dart' -print0 | xargs -0 -I{} python3 - <<'PY'
import os, sys
p = sys.argv[1]
print(os.path.realpath(p))
PY {} | sort -u)

# Parse references from every lib/*.dart file
# Recognizes: import "..."; export "..."; part "...";
REFERENCED=$(python3 - <<PY
import os, re, sys, json

ROOT = os.getcwd()
LIB = os.path.join(ROOT, "lib")
APP = os.path.basename(ROOT)

# regex for import/export/part lines (single or double quotes)
PAT = re.compile(r'^\s*(import|export|part)\s+[\'"]([^\'"]+)[\'"]', re.M)

def normpath(p):
    return os.path.realpath(p)

def resolve_uri(uri, base_file):
    """
    Resolve a Dart URI to an absolute file path if it points into lib/.
    Returns None if it's not a file under lib (e.g. dart:, package from other pkg).
    """
    # ignore dart: and asset: and http:
    if uri.startswith(("dart:", "asset:", "http:", "https:")):
        return None

    # package:APP_NAME/...
    if uri.startswith("package:%s/" % APP):
        rel = uri.split("/", 1)[1]  # drop 'package:APP_NAME/'
        abs_path = os.path.join(LIB, rel)
        return normpath(abs_path)

    # other packages -> ignore (they are not in our lib/)
    if uri.startswith("package:"):
        return None

    # Relative path: resolve relative to base_file's directory
    if uri.startswith(("./", "../")) or (not "://" in uri and not uri.startswith("/")):
        base_dir = os.path.dirname(base_file)
        abs_path = os.path.join(base_dir, uri)
        return normpath(abs_path)

    # Absolute (rare) -> if under lib, keep; else ignore
    if os.path.isabs(uri):
        if os.path.commonpath([normpath(uri), LIB]) == LIB:
            return normpath(uri)
        return None

    return None

# Walk all lib/*.dart files
referenced = set()
for root, _, files in os.walk(LIB):
    for f in files:
        if not f.endswith(".dart"):
            continue
        path = normpath(os.path.join(root, f))
        try:
            with open(path, "r", encoding="utf-8") as fh:
                text = fh.read()
        except Exception:
            continue

        for m in PAT.finditer(text):
            uri = m.group(2).strip()
            resolved = resolve_uri(uri, path)
            if resolved is not None and os.path.exists(resolved):
                referenced.add(resolved)

# Always keep main entry points and generated firebase options if present
always_keep = {
    normpath(os.path.join(LIB, "main.dart")),
    normpath(os.path.join(LIB, "firebase_options.dart")),
}

# Print newline-separated absolute paths
for p in sorted(referenced | always_keep):
    print(p)
PY
)

# Compare ALL_FILES vs REFERENCED
echo "=== Unused Dart files (no import/export/part reference found) ==="
comm -23 <(printf "%s\n" "$ALL_FILES") <(printf "%s\n" "$REFERENCED") || true
