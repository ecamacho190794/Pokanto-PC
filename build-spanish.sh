#!/usr/bin/env bash
# Compatibility wrapper: keep the historical alias, but route all Spanish builds
# through the same language-specific pipeline used by ./build.sh spanish.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
exec "$ROOT/languages/es/build.sh" "$@"
