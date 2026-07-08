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

Regenerate the related-work table draft from its CSV source:

```bash
docker run --rm -u "$(id -u):$(id -g)" -v "$PWD":/exp -w /exp fbsql-dev \
    Rscript scripts/50_make_related_work_table.R
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
