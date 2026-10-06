#!/usr/bin/env bash
set -euo pipefail

flutter --version
flutter clean
dart pub get

# Quick analyzer pass
dart analyze || true

# Smoke-import compile
dart run tool/smoke_import.dart

# Sim build to catch iOS issues earlier
flutter build ios --simulator -v
echo "✅ Flutter smoke build OK"
