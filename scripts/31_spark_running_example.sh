#!/usr/bin/env bash
# Run the customer churn running example on Spark MLlib (local mode) inside
# the official Spark image. Writes raw outputs to results/raw/.
set -euo pipefail
cd "$(dirname "$0")/.."

SPARK_IMAGE="${SPARK_IMAGE:-fbsql-exp-spark}"

docker image inspect "$SPARK_IMAGE" >/dev/null 2>&1 || {
    echo "NG: $SPARK_IMAGE not found; build it with:" >&2
    echo "    docker build -t fbsql-exp-spark -f docker/spark/Dockerfile ." >&2
    exit 1
}

# -u 0: the image's default user cannot write to the bind mount.
docker run --rm -u 0 -v "$PWD":/exp "$SPARK_IMAGE" \
    /opt/spark/bin/spark-submit --master 'local[1]' \
    /exp/scripts/31_spark_running_example.py

docker run --rm -u 0 -v "$PWD":/exp "$SPARK_IMAGE" \
    chown -R "$(id -u):$(id -g)" /exp/results

echo "OK: Spark running example finished."
