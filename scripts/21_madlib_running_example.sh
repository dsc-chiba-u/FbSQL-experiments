#!/usr/bin/env bash
# Run the customer churn running example on Apache MADlib inside a
# temporary fbsql-exp-madlib container. Writes raw outputs to results/raw/.
set -euo pipefail
cd "$(dirname "$0")/.."

CONTAINER=fbsql-exp-madlib-run

docker image inspect fbsql-exp-madlib >/dev/null 2>&1 || {
    echo "NG: fbsql-exp-madlib image not found; build it with:" >&2
    echo "    docker build -t fbsql-exp-madlib -f docker/madlib/Dockerfile ." >&2
    exit 1
}

docker run --rm -d --name "$CONTAINER" \
    -e POSTGRES_HOST_AUTH_METHOD=trust \
    -v "$PWD":/exp -w /exp \
    fbsql-exp-madlib >/dev/null

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

echo "Installing the MADlib schema (madpack)..."
docker exec -u postgres "$CONTAINER" /usr/local/madlib/bin/madpack \
    -p postgres -c postgres@localhost:5432/postgres install >/dev/null

docker exec "$CONTAINER" psql -U postgres -v ON_ERROR_STOP=1 \
    -f /exp/scripts/sql/21_madlib_running_example.sql

echo "OK: wrote results/raw/running_example_model_madlib.csv and running_example_predictions_madlib.csv"
