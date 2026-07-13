# FbSQL-experiments

Reproducible experiments, smoke tests, and comparison material for
[FbSQL](https://github.com/dsc-chiba-u/FbSQL), a closure-preserving
formula-based PostgreSQL extension for statistical modeling in SQL.

This is the companion repository in the two-repository layout:

- **FbSQL** — the PostgreSQL extension itself, its documentation, CI, PGXN
  packaging, and (under `paper/`) the JSS manuscript.
- **FbSQL-experiments** (this repo) — reproducible experiments, smoke tests,
  comparisons against other SQL-ML systems, and generation of the
  manuscript's tables, figures, and CSVs. Results are committed to git.

## Comparison targets

| Tier | Systems | Treatment |
|---|---|---|
| 1 | Apache MADlib | required experiments |
| 2 | Apache Spark MLlib, PostgresML | experiments if feasible |
| 3 | Apache Hivemall, H2O-3 + Sparkling Water | literature-based comparison |

BigQuery ML is not OSS and is excluded from the OSS comparison; the paper's
Discussion may mention it as a non-OSS SQL-ML example.

Tier 1/2 rows of the comparison table are backed by executed experiments in
this repo; Tier 3 rows (Hivemall, H2O-3 + Sparkling Water) are
literature-based, with per-claim sources recorded in
`results/summary/related_work_notes.csv`. Cells that could not be verified
remain `TBD`.

## Layout

```
data/                 hand-written deterministic inputs
  customer.csv        running-example data (2025 training, 2026 scoring)
  related_work.csv    related-work comparison template (source of truth)
scripts/              numbered pipeline scripts (see numbering below)
R/                    shared R helpers (as they emerge)
results/raw/          raw outputs of individual runs
results/summary/      parity and summary CSVs
results/figures/      generated figures
results/tables/       generated manuscript tables
docs/dev-log.md       development log
```

### Script numbering

- `00-09` environment / install / smoke tests
- `10-19` FbSQL running example and R parity tests
- `20-29` Apache MADlib comparisons
- `30-39` Spark MLlib comparisons
- `40-49` PostgresML comparisons
- `50-59` design comparison tables
- `60-69` figures
- `70-79` manuscript tables

## Running the running-example pipeline

Prerequisites: docker, the `fbsql-dev` image built in the FbSQL repo
(`scripts/docker-build.sh` there), and the FbSQL repo checked out as a
sibling directory (or point `FBSQL_ROOT` at it). All R steps run inside the
same pinned container image — no host R needed.

```bash
scripts/00_check_environment.sh
scripts/10_running_example_fbsql.sh
docker run --rm -u "$(id -u):$(id -g)" -v "$PWD":/exp -w /exp fbsql-dev \
    Rscript scripts/11_running_example_r_reference.R
docker run --rm -u "$(id -u):$(id -g)" -v "$PWD":/exp -w /exp fbsql-dev \
    Rscript scripts/12_running_example_parity.R
```

Step 12 writes `results/summary/running_example_parity.csv` and fails if any
FbSQL value disagrees with R's `glm()` / `predict.glm()` (both rounded to 4
decimals).

## MADlib comparison (Tier 1)

The MADlib environment is pinned by `docker/madlib/Dockerfile` (the MADlib
project's own CI base image for PostgreSQL 11, with the 1.21.0 release built
from the Apache source archive). This is an API-design comparison, not a
performance benchmark, so the older PostgreSQL major is acceptable.

```bash
docker build -t fbsql-exp-madlib -f docker/madlib/Dockerfile .
scripts/20_madlib_smoke.sh              # madpack install + madlib.version()
scripts/21_madlib_running_example.sh    # same churn example on MADlib
docker run --rm -u "$(id -u):$(id -g)" -v "$PWD":/exp -w /exp fbsql-dev \
    Rscript scripts/22_compare_fbsql_madlib.R
```

Step 22 writes `results/summary/madlib_running_example_summary.csv`;
hand-curated design observations live in
`results/summary/madlib_api_design_notes.csv`. Expected design differences
(e.g. MADlib silently scoring unseen factor levels as the reference level)
are annotated rather than treated as failures.

## Spark MLlib comparison (Tier 2)

Spark is compared because RFormula gives it a formula-shaped interface —
the closest contrast to FbSQL's claim that formulas and SQL design
principles can coexist. The environment is pinned by
`docker/spark/Dockerfile` (official Spark 3.5.1 image + numpy, which
pyspark.ml needs but the official image lacks):

```bash
docker build -t fbsql-exp-spark -f docker/spark/Dockerfile .
scripts/30_spark_smoke.sh              # local-mode PySpark + RFormula import
scripts/31_spark_running_example.sh    # churn example via RFormula + GLR pipeline
docker run --rm -u "$(id -u):$(id -g)" -v "$PWD":/exp -w /exp fbsql-dev \
    Rscript scripts/32_compare_fbsql_spark.R
```

Headline findings: predictions match R/FbSQL to 4 decimals (GLR is an IRLS
GLM), but RFormula picks the least-frequent level as the factor reference,
so coefficient tables agree only after reparameterization (verified
numerically in step 32); the default pipeline errors on NULL features and
`handleInvalid="skip"` silently drops rows. Design observations live in
`results/summary/spark_api_design_notes.csv`.

## PostgresML comparison (Tier 2)

PostgresML is compared as the other PostgreSQL-extension SQL-ML system. Its
official image ships the extension preinstalled (`PGML_IMAGE` overrides the
default `ghcr.io/postgresml/postgresml:2.7.12`; note the image is ~15 GB):

```bash
docker pull ghcr.io/postgresml/postgresml:2.7.12
scripts/40_postgresml_smoke.sh              # pgml.version() + catalog tables
scripts/41_postgresml_running_example.sh    # churn example + NULL/categorical probes
docker run --rm -u "$(id -u):$(id -g)" -v "$PWD":/exp -w /exp fbsql-dev \
    Rscript scripts/42_compare_fbsql_postgresml.R
```

Numeric agreement with FbSQL/R is NOT expected here (PostgresML fits its own
estimators behind an algorithm-name API and predicts class labels); the
deliverables are `results/summary/postgresml_api_design_notes.csv` and the
probe logs under `results/raw/`.

Regenerate the related-work table draft from its CSV source:

```bash
docker run --rm -u "$(id -u):$(id -g)" -v "$PWD":/exp -w /exp fbsql-dev \
    Rscript scripts/50_make_related_work_table.R
```

## Interface overhead microbenchmark

Script 13 bounds the price of the FbSQL language layer — it is not a
performance claim. On deterministic synthetic data (no RNG;
`generate_series` arithmetic) it times `fit_glm()` against calling
`stats::glm()` directly in R on identical data, and `predict_glm()`
scoring the same rows, at 10^3 / 10^4 / 10^5 rows, three runs each:

```bash
scripts/13_overhead_benchmark.sh
```

Raw runs land in `results/raw/overhead_benchmark_runs.csv`, medians in
`results/summary/overhead_benchmark.csv` (the source of the paper's
overhead table). Times are machine-dependent; the committed numbers are
from the pinned reference environment.

## Paper tables

The manuscript's table assets (`FbSQL/paper/tables/*.{tex,md}`) are
generated here — the paper never hand-edits them. Script 51 condenses
`data/related_work.csv` for print (drift checks stop it if the curated
condensation no longer matches the CSV) and renders `data/customer.csv`
as the running-example dataset table:

```bash
docker run --rm -u "$(id -u):$(id -g)" \
    -v "$PWD":/exp -v "$(cd ../FbSQL && pwd)":/fbsql \
    -e FBSQL_ROOT=/fbsql -w /exp fbsql-dev \
    Rscript scripts/51_generate_paper_tables.R
```

## Reproducibility

- All input data is hand-written and deterministic (no RNG so far; any
  future generator must take a fixed seed).
- Results are committed to git so changes show up as diffs.
- No developer-specific paths; scripts resolve the FbSQL repo via
  `FBSQL_ROOT` or the sibling-directory convention.
- The execution environment is pinned by the FbSQL repo's Docker image
  (PostgreSQL 16 + PL/R 8.4.8.6 + R 4.2.2).

## License

MIT © Data Science Core
