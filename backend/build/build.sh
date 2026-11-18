#!/usr/bin/env bash
# Builds the backend and assembles the Cloud Foundry deployment folder backend/dist.
#   build.sh [debug|release]   (default: release)
set -euo pipefail
cd "$(dirname "$0")/.."
BUILD_TYPE="${1:-release}"

dub build --build="$BUILD_TYPE" --compiler="${DC:-ldc2}"

rm -rf dist && mkdir -p dist
cp build/bin/gdpr dist/
cp -r config public dist/
echo "Backend built ($BUILD_TYPE) -> backend/dist"
