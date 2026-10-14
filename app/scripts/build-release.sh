#!/usr/bin/env bash
# Obfuscated release build (Android only). The Dart code is obfuscated and its
# debug symbols are kept outside the app in release-symbols/<version>/ (needed
# to read crash stack traces with `flutter symbolize`).
#
#   API_BASE_URL=http://10.0.2.2:5050/api/v1 ./scripts/build-release.sh        # APK
#   API_BASE_URL=https://api.example.test/api/v1 ./scripts/build-release.sh appbundle
set -euo pipefail
cd "$(dirname "$0")/.."

: "${API_BASE_URL:?Set API_BASE_URL (the app has no built-in backend URL)}"

kind="${1:-apk}"
version="$(grep '^version:' pubspec.yaml | awk '{print $2}')"
symbols="release-symbols/${version}"

flutter build "${kind}" --release \
  --dart-define=API_BASE_URL="${API_BASE_URL}" \
  --obfuscate --split-debug-info="${symbols}/android"

echo "Built ${version}. Debug symbols: ${symbols} (keep them)."
