#!/usr/bin/env python3
import os, re, sys, argparse
from collections import deque, defaultdict

IMPORT_RE = re.compile(r"""^\s*(import|export)\s+['"]([^'"]+)['"]""")
PART_RE   = re.compile(r"""^\s*part\s+['"]([^'"]+)['"]""")
# We ignore "part of" here; it's handled by PART_RE edges.

def norm(p):
    return os.path.normpath(p).replace("\\", "/")

def resolve_path(spec, cwd, package_name):
    # Handle dart: and package: imports
    if spec.startswith("dart:"):
        return None  # SDK library, ignore
    if spec.startswith("package:"):
        # Example: package:adhd_app/pages/home_page.dart
        # Map package root -> lib/
        try:
            pkg, rel = spec[len("package:"):].split("/", 1)
        except ValueError:
            return None
        if pkg != package_name:
            # External package; we don't traverse into dependencies' lib
            return None
        return norm(os.path.join("lib", rel))
    # Relative import/part: './x.dart' or '../y.dart'
    return norm(os.path.join(cwd, spec))

def collect_edges(file_path, package_name):
    edges = set()
    if not os.path.exists(file_path):
        return edges
    cwd = os.path.dirname(file_path)
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            for line in f:
                m = IMPORT_RE.match(line) or PART_RE.match(line)
                if m:
                    spec = m.group(2) if m.lastindex == 2 else m.group(1)
                    target = resolve_path(spec, cwd, package_name)
                    if target and target.endswith(".dart") and os.path.exists(target):
                        edges.add(target)
    except Exception:
        pass
    return edges

def main():
    ap = argparse.ArgumentParser(description="Find reachable vs unreferenced Dart files starting at entrypoint.")
    ap.add_argument("--entry", default="lib/main.dart", help="Entrypoint Dart file (default: lib/main.dart)")
    ap.add_argument("--package", default=None, help="Your package name (from pubspec.yaml). If omitted, inferred from current dir name.")
    args = ap.parse_args()

    entry = norm(args.entry)
    if not os.path.exists(entry):
        print(f"Entry file not found: {entry}", file=sys.stderr)
        sys.exit(1)

    package_name = args.package or os.path.basename(os.getcwd())

    # Build graph by BFS
    graph = defaultdict(set)
    reachable = set()
    q = deque([entry])
    reachable.add(entry)

    while q:
        cur = q.popleft()
        for nxt in collect_edges(cur, package_name):
            graph[cur].add(nxt)
            if nxt not in reachable:
                reachable.add(nxt)
                q.append(nxt)

    # All local dart files in lib/
    all_dart = []
    for root, _, files in os.walk("lib"):
        for fn in files:
            if fn.endswith(".dart"):
                all_dart.append(norm(os.path.join(root, fn)))

    unreferenced = sorted(set(all_dart) - reachable)

    print("\n=== Reachable (used) files ===")
    for f in sorted(reachable):
        print(f)

    print("\n=== Unreferenced (candidates to quarantine) ===")
    for f in unreferenced:
        print(f)

    print("\nTip: Move unreferenced files into lib/_attic/ (git keeps history).")

if __name__ == "__main__":
    main()
