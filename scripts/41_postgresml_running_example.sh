#!/usr/bin/env bash
# Run the customer churn running example on PostgresML inside a temporary
# container. Writes raw outputs to results/raw/, including a probe of how
# pgml.train() reacts to a text (categorical) feature column.
set -euo pipefail
cd "$(dirname "$0")/.."

PGML_IMAGE="${PGML_IMAGE:-ghcr.io/postgresml/postgresml:2.7.12}"
CONTAINER=fbsql-exp-pgml-run

docker image inspect "$PGML_IMAGE" >/dev/null 2>&1 || {
    echo "NG: $PGML_IMAGE not found; docker pull it first" >&2
    exit 1
}

docker run --rm -d --name "$CONTAINER" -v "$PWD":/exp "$PGML_IMAGE" tail -f /dev/null >/dev/null  # empty CMD would exit immediately

cleanup() {
    docker exec "$CONTAINER" chown -R "$(id -u):$(id -g)" /exp/results \
        >/dev/null 2>&1 || true
    docker stop "$CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

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
    -v ON_ERROR_STOP=1 -f /exp/scripts/sql/41_postgresml_running_example.sql

# The in-container psql runs as the postgresml user, which cannot write to
# the bind mount, so \copy targets /tmp and we copy the file out here.
docker exec "$CONTAINER" cat /tmp/running_example_predictions_postgresml.csv \
    > results/raw/running_example_predictions_postgresml.csv

# NULL probe: pgml.predict() rejects NULL features outright (hard error,
# not a NULL prediction). Captured as a finding.
echo "Probing NULL feature handling..."
{
    docker exec "$CONTAINER" sudo -u postgresml psql -d postgresml \
        -c "SELECT pgml.predict('fbsql_churn', ARRAY[NULL::real]);" 2>&1
} | tee results/raw/postgresml_null_probe.log || true

# Categorical probe: does pgml.train() accept a text feature column at all?
# Failure here is itself a finding, so it is captured instead of aborting.
echo "Probing categorical (text) feature handling..."
{
    docker exec "$CONTAINER" sudo -u postgresml psql -d postgresml \
        -c "CREATE TABLE customer_2025_train_cat AS
            SELECT age::real, gender, churn_flag::int AS churn_flag
            FROM customer WHERE DATE_PART('YEAR', created_at) = 2025;" \
        -c "SELECT *
            FROM pgml.train(
                project_name  => 'fbsql_churn_cat',
                task          => 'classification',
                relation_name => 'customer_2025_train_cat',
                y_column_name => 'churn_flag');" 2>&1
} | tee results/raw/postgresml_categorical_probe.log || true

echo "OK: wrote results/raw/running_example_predictions_postgresml.csv and postgresml_categorical_probe.log"
