#!/usr/bin/env bash
# Runs all backend unit tests (domain, application, persistence, OData, web, CLI).
set -euo pipefail
cd "$(dirname "$0")/.."
dub test --compiler="${DC:-dmd}" "$@"
