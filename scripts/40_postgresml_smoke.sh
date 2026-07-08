#!/usr/bin/env bash
# Smoke test for the PostgresML comparison environment: start the official
# image, wait for the bundled PostgreSQL, and verify pgml.version().
#
# The image ships PostgreSQL with the pgml extension preinstalled in the
# 'postgresml' database (user 'postgresml'), plus a dashboard we ignore.
set -euo pipefail
cd "$(dirname "$0")/.."

PGML_IMAGE="${PGML_IMAGE:-ghcr.io/postgresml/postgresml:2.7.12}"
CONTAINER=fbsql-exp-pgml-smoke

docker image inspect "$PGML_IMAGE" >/dev/null 2>&1 || {
    echo "NG: $PGML_IMAGE not found; docker pull it first" >&2
    exit 1
}

docker run --rm -d --name "$CONTAINER" "$PGML_IMAGE" tail -f /dev/null >/dev/null  # empty CMD would exit immediately
trap 'docker stop "$CONTAINER" >/dev/null 2>&1 || true' EXIT

echo "Waiting for PostgresML to become ready..."
for _ in $(seq 1 120); do
    if docker exec "$CONTAINER" sudo -u postgresml psql -d postgresml \
            -c "SELECT pgml.version()" >/dev/null 2>&1; then
        break
    fi
    sleep 1
done
docker exec "$CONTAINER" sudo -u postgresml psql -d postgresml -c "SELECT pgml.version()" >/dev/null

docker exec "$CONTAINER" sudo -u postgresml psql -d postgresml \
    -c "SELECT pgml.version();" \
    -c "\dt pgml.*"
echo "OK: PostgresML is running and pgml responds."
