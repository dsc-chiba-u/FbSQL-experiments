#!/usr/bin/env bash
# Smoke test for the Spark MLlib comparison environment: verify that the
# official Spark image runs PySpark in local mode and that pyspark.ml
# (including RFormula) is importable.
set -euo pipefail
cd "$(dirname "$0")/.."

SPARK_IMAGE="${SPARK_IMAGE:-fbsql-exp-spark}"

docker image inspect "$SPARK_IMAGE" >/dev/null 2>&1 || {
    echo "NG: $SPARK_IMAGE not found; build it with:" >&2
    echo "    docker build -t fbsql-exp-spark -f docker/spark/Dockerfile ." >&2
    exit 1
}

# spark-submit needs a *.py path (stdin is treated as a jar), so the probe
# is written to a file inside the container first.
docker run --rm -u 0 "$SPARK_IMAGE" bash -c '
cat > /tmp/smoke.py <<EOF
from pyspark.sql import SparkSession
from pyspark.ml.feature import RFormula

spark = SparkSession.builder.getOrCreate()
print("SPARK_VERSION:", spark.version)
print("RFORMULA_OK:", RFormula(formula="y ~ x").getFormula())
spark.stop()
EOF
/opt/spark/bin/spark-submit --master "local[1]" /tmp/smoke.py 2>/dev/null
'
echo "OK: Spark local mode and pyspark.ml are available."
