#!/usr/bin/env bash
# English variant entry point. Its ROM analysis configuration and game hooks
# remain at the repository root for backwards compatibility with upstream.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [ "$#" -eq 0 ]; then set -- all; fi
POKANTO_LANGUAGE_DISPATCHED=1 exec "$ROOT/build.sh" "$@"
