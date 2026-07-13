#!/usr/bin/env bash
# Overhead microbenchmark for the FbSQL language layer. This is NOT a
# performance claim (performance is an explicit non-goal of the paper);
# it bounds the price of the interface: fit_glm() versus calling
# stats::glm() directly in R on identical data, and predict_glm() scaling
# with the number of scored rows.
#
# Data is fully deterministic (generate_series arithmetic; no RNG), so
# reruns are comparable. Times are machine-dependent by nature; the paper
# reports them as measured on the pinned reference environment.
#
# Outputs:
#   results/raw/overhead_benchmark_runs.csv   every timed run
#   results/summary/overhead_benchmark.csv    median per (n, op)
set -euo pipefail
cd "$(dirname "$0")/.."

CONTAINER=fbsql-overhead
SIZES="${SIZES:-1000 10000 100000}"
REPS="${REPS:-3}"

mkdir -p results/raw results/summary
RAW=results/raw/overhead_benchmark_runs.csv
SUMMARY=results/summary/overhead_benchmark.csv

docker run --rm -d --name "$CONTAINER" \
    -e POSTGRES_HOST_AUTH_METHOD=trust \
    fbsql-dev >/dev/null
cleanup() { docker stop "$CONTAINER" >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "Waiting for PostgreSQL..."
for _ in $(seq 1 60); do
    docker exec "$CONTAINER" psql -U postgres -c "SELECT 1" >/dev/null 2>&1 && break
    sleep 1
done
sleep 2
docker exec "$CONTAINER" psql -U postgres -q \
    -c "CREATE EXTENSION IF NOT EXISTS fbsql CASCADE;" >/dev/null

echo "n,op,rep,ms" > "$RAW"

time_sql() {  # $1 = SQL; prints elapsed ms (server round trip via \timing)
    docker exec "$CONTAINER" psql -U postgres -qAt \
        -c '\timing on' -c "$1" 2>&1 \
        | grep -oE 'Time: [0-9.]+' | tail -1 | grep -oE '[0-9.]+'
}

for N in $SIZES; do
    echo "== n = $N =="
    docker exec -i "$CONTAINER" psql -U postgres -q <<SQL
DROP TABLE IF EXISTS bench_train, bench_score, bench_model;
CREATE TABLE bench_train AS
SELECT ((i % 100)::float8) / 10.0                        AS x1,
       (ARRAY['F','M','Other'])[1 + (i % 3)]             AS gender,
       (0.3 * (((i % 100)::float8) / 10.0) - 1.5
            + 2.0 * sin(i::float8)) > 0                  AS churn_flag
FROM generate_series(1, $N) AS s(i);
CREATE TABLE bench_score AS SELECT x1, gender FROM bench_train;
CREATE TABLE bench_model AS
SELECT * FROM fbsql.fit_glm(
    relation => \$\$ SELECT * FROM bench_train \$\$,
    formula  => 'churn_flag ~ x1 + gender',
    family   => 'binomial');
SQL
    for REP in $(seq 1 "$REPS"); do
        MS=$(time_sql "SELECT count(*) FROM fbsql.fit_glm(
                relation => \$\$ SELECT * FROM bench_train \$\$,
                formula  => 'churn_flag ~ x1 + gender',
                family   => 'binomial');")
        echo "$N,fit_glm,$REP,$MS" >> "$RAW"

        MS=$(docker exec "$CONTAINER" Rscript -e "
            i <- seq_len($N)
            d <- data.frame(
                x1 = (i %% 100) / 10,
                gender = factor(c('F','M','Other')[1 + (i %% 3)]),
                churn_flag = (0.3 * ((i %% 100) / 10) - 1.5
                              + 2 * sin(i)) > 0)
            t <- system.time(
                glm(churn_flag ~ x1 + gender, data = d,
                    family = binomial()))[['elapsed']]
            cat(round(t * 1000, 3))")
        echo "$N,r_glm,$REP,$MS" >> "$RAW"

        MS=$(time_sql "SELECT count(*) FROM fbsql.predict_glm(
                relation => \$\$ SELECT * FROM bench_score \$\$,
                model    => \$\$ SELECT * FROM bench_model \$\$
            ) AS p(x1 float8, gender text,
                   churn_flag_predicted float8);")
        echo "$N,predict_glm,$REP,$MS" >> "$RAW"
    done
done

# Median per (n, op).
python3 - "$RAW" "$SUMMARY" <<'EOF'
import csv, statistics, sys
rows = list(csv.DictReader(open(sys.argv[1])))
keys = sorted({(int(r['n']), r['op']) for r in rows})
with open(sys.argv[2], 'w', newline='') as f:
    w = csv.writer(f)
    w.writerow(['n', 'op', 'median_ms', 'reps'])
    for n, op in keys:
        v = [float(r['ms']) for r in rows
             if int(r['n']) == n and r['op'] == op]
        w.writerow([n, op, round(statistics.median(v), 1), len(v)])
EOF

echo "OK: wrote $RAW and $SUMMARY"
cat "$SUMMARY"
