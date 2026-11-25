#!/usr/bin/env bash
# Runs the checks a pull request must pass, stopping at the first failure.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter not found. Add it to PATH first, for example:" >&2
  echo "  export PATH=$FLUTTER_ROOT/bin:\$PATH" >&2
  exit 127
fi

echo "==> flutter pub get"
flutter pub get

echo "==> flutter analyze"
flutter analyze

echo "==> flutter test"
flutter test

echo "All checks passed."
