#!/usr/bin/env bash
# Smoke test for the MADlib comparison environment: start the
# fbsql-exp-madlib container (built from docker/madlib/Dockerfile), install
# the MADlib schema with madpack, and verify madlib.version().
set -euo pipefail
cd "$(dirname "$0")/.."

CONTAINER=fbsql-exp-madlib-smoke

docker image inspect fbsql-exp-madlib >/dev/null 2>&1 || {
    echo "NG: fbsql-exp-madlib image not found; build it with:" >&2
    echo "    docker build -t fbsql-exp-madlib -f docker/madlib/Dockerfile ." >&2
    exit 1
}

docker run --rm -d --name "$CONTAINER" \
    -e POSTGRES_HOST_AUTH_METHOD=trust \
    fbsql-exp-madlib >/dev/null
trap 'docker stop "$CONTAINER" >/dev/null 2>&1 || true' EXIT

echo "Waiting for PostgreSQL to become ready..."
for _ in $(seq 1 60); do
    if docker exec "$CONTAINER" psql -U postgres -c "SELECT 1" >/dev/null 2>&1; then
        break
    fi
    sleep 1
done
sleep 2
docker exec "$CONTAINER" psql -U postgres -c "SELECT 1" >/dev/null

echo "Installing the MADlib schema (madpack)..."
docker exec -u postgres "$CONTAINER" /usr/local/madlib/bin/madpack \
    -p postgres -c postgres@localhost:5432/postgres install

docker exec "$CONTAINER" psql -U postgres -c "SELECT madlib.version();"
echo "OK: MADlib is installed and responding."
