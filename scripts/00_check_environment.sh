#!/usr/bin/env bash
# Verify the prerequisites for the FbSQL experiments:
#  - docker is available
#  - the fbsql-dev image exists (built in the FbSQL repo)
#  - the FbSQL repo itself is reachable (FBSQL_ROOT or sibling ../FbSQL)
set -euo pipefail
cd "$(dirname "$0")/.."

FBSQL_ROOT="${FBSQL_ROOT:-$(cd ../FbSQL 2>/dev/null && pwd || true)}"

fail() { echo "NG: $1" >&2; exit 1; }

command -v docker >/dev/null || fail "docker is not installed"
docker info >/dev/null 2>&1 || fail "docker daemon is not reachable"
docker image inspect fbsql-dev >/dev/null 2>&1 \
    || fail "fbsql-dev image not found; run scripts/docker-build.sh in the FbSQL repo"
[ -n "$FBSQL_ROOT" ] && [ -f "$FBSQL_ROOT/fbsql.control" ] \
    || fail "FbSQL repo not found; set FBSQL_ROOT or clone it as a sibling directory"

echo "OK: docker, fbsql-dev image, and FbSQL repo at $FBSQL_ROOT"
