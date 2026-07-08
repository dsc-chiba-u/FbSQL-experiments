#!/usr/bin/env bash
# Run the customer churn running example against the FbSQL extension inside
# a temporary fbsql-dev container. Writes raw outputs to results/raw/.
set -euo pipefail
cd "$(dirname "$0")/.."

FBSQL_ROOT="${FBSQL_ROOT:-$(cd ../FbSQL 2>/dev/null && pwd || true)}"
[ -n "$FBSQL_ROOT" ] && [ -f "$FBSQL_ROOT/fbsql.control" ] || {
    echo "NG: FbSQL repo not found; set FBSQL_ROOT" >&2; exit 1;
}

CONTAINER=fbsql-exp-running-example

docker run --rm -d --name "$CONTAINER" \
    -e POSTGRES_HOST_AUTH_METHOD=trust \
    -v "$FBSQL_ROOT":/fbsql -v "$PWD":/exp -w /fbsql \
    fbsql-dev >/dev/null

cleanup() {
    docker exec "$CONTAINER" chown -R "$(id -u):$(id -g)" /exp/results \
        >/dev/null 2>&1 || true
    docker stop "$CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Waiting for PostgreSQL to become ready..."
for _ in $(seq 1 60); do
    if docker exec "$CONTAINER" psql -U postgres -c "SELECT 1" >/dev/null 2>&1; then
        break
    fi
    sleep 1
done
sleep 2
docker exec "$CONTAINER" psql -U postgres -c "SELECT 1" >/dev/null

docker exec "$CONTAINER" make install >/dev/null
docker exec "$CONTAINER" psql -U postgres \
    -c "CREATE EXTENSION fbsql CASCADE;" >/dev/null
docker exec "$CONTAINER" psql -U postgres -v ON_ERROR_STOP=1 \
    -f /exp/scripts/sql/10_running_example.sql

echo "OK: wrote results/raw/running_example_model_fbsql.csv and running_example_predictions_fbsql.csv"
