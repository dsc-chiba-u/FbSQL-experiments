# Generate the manuscript table assets from this repository's data and
# write them into the FbSQL repo (paper/tables/). The paper never
# hand-edits these files; regenerate them here instead:
#
#   docker run --rm -u "$(id -u):$(id -g)" \
#       -v "$PWD":/exp -v "$(cd ../FbSQL && pwd)":/fbsql \
#       -e FBSQL_ROOT=/fbsql -w /exp fbsql-dev \
#       Rscript scripts/51_generate_paper_tables.R
#
# Outputs (per table: .tex for the JSS/LaTeX build, .md for the HTML
# development build):
#   paper/tables/related_work.{tex,md}     from data/related_work.csv
#   paper/tables/customer_dataset.{tex,md} from data/customer.csv
#
# Table 1 condenses the free-text CSV cells to short print labels. The
# condensation is curated below but tied to the CSV by drift checks: if a
# curated verdict no longer matches the CSV cell it summarizes, the script
# stops. The full uncondensed text stays in data/related_work.csv, which
# the table footnote points to.

fbsql_root <- Sys.getenv("FBSQL_ROOT", "../FbSQL")
out_dir <- file.path(fbsql_root, "paper", "tables")
if (!dir.exists(out_dir)) {
    stop(sprintf("output directory not found: %s (set FBSQL_ROOT)", out_dir),
         call. = FALSE)
}

## ---- Table 1: related work ---------------------------------------------

rw <- read.csv("data/related_work.csv", stringsAsFactors = FALSE,
               check.names = FALSE)

systems_expected <- c("FbSQL", "Apache MADlib", "Apache Spark MLlib",
                      "PostgresML", "Apache Hivemall",
                      "H2O-3 + Sparkling Water")
if (!identical(rw$system, systems_expected)) {
    stop("data/related_work.csv system rows changed; update the curation",
         call. = FALSE)
}
headers <- c("FbSQL", "MADlib", "Spark", "PgML", "Hivemall", "H2O")

## Each entry: print label; CSV column it condenses; the six condensed
## cells (CSV system order). Cells whose first word is a verdict
## (yes/no/partial/TBD/none) are drift-checked against the CSV.
rows <- list(
    list("License", "oss_license",
         c("MIT", "Apache-2.0", "Apache-2.0", "MIT", "Apache-2.0", "Apache-2.0")),
    list("Environment", "primary_environment",
         c("PostgreSQL extension", "PostgreSQL / Greenplum extension",
           "Spark DataFrame / Pipeline", "PostgreSQL extension",
           "Hive UDFs (retired 2022)", "H2O cluster (+ Spark)")),
    list("SQL API", "sql_api",
         c("yes", "yes", "no", "yes", "yes", "no")),
    list("Formula interface", "formula_interface",
         c("yes (R semantics)", "no (array expression)",
           "formula-shaped, not R", "no (task + algorithm)",
           "no (feature arrays)", "no (x/y lists)")),
    list("Families, links", "family_link",
         c("2 (PoC)", "5 + links", "5 + links", "none",
           "per-algorithm", "10 + links")),
    list("Factor handling", "factor_handling",
         c("automatic (R conventions)", "manual one-hot",
           "automatic; freq.-based ref.", "ordinal encoding",
           "manual vectorization", "automatic internal")),
    list("Interactions", "interaction_handling",
         c("not yet", "manual", "yes", "TBD", "TBD", "yes")),
    list("Offset", "offset",
         c("no (deliberate)", "no", "yes", "TBD", "TBD", "yes")),
    list("Weights", "weight",
         c("no (deliberate)", "no", "yes", "TBD", "TBD", "yes")),
    list("Model representation", "model_representation",
         c("one relation", "two side tables; coef.\\ arrays", "JVM object",
           "binary + catalogs", "(feature, weight) table",
           "binary (MOJO/POJO)")),
    list("Relation in", "relation_in",
         c("yes", "partial (table name)", "yes (DataFrame level)",
           "partial (table name)", "yes", "no (H2OFrame)")),
    list("Relation out", "relation_out",
         c("yes", "no", "DataFrame level", "no", "partial (manual SQL)", "no")),
    list("Named arguments", "named_arguments",
         c("yes", "positional", "host language", "yes",
           "no (option string)", "host language")),
    list("NULL handling", "null_handling",
         c("complete case; NULL in, NULL out", "complete case",
           "error, or rows dropped", "impute policy; hard error",
           "TBD", "mean imputation (default)")),
    list("Metadata", "metadata_representation",
         c("jsonb inside the relation", "summary table (call strings)",
           "object-bound attributes", "system catalogs", "none",
           "inside model object")),
    list("Prediction API", "prediction_api",
         c("relation \\(\\to\\) relation", "scalar per row",
           "DataFrame transform()", "scalar per row",
           "hand-written SQL", "frame \\(\\to\\) frame")),
    list("Reproducibility", "reproducibility_priority",
         c("R parity; pg\\_regress", "deterministic IRLS",
           "deterministic IRLS", "deterministic split; no seed",
           "seed undocumented", "seed; regularized default"))
)

## drift checks -------------------------------------------------------------
first_word <- function(x) tolower(sub("^([A-Za-z]+).*$", "\\1", trimws(x)))
verdicts <- c("yes", "no", "partial", "tbd", "none")
for (r in rows) {
    csv_col <- r[[2]]
    if (!csv_col %in% names(rw)) {
        stop(sprintf("column '%s' missing from related_work.csv", csv_col),
             call. = FALSE)
    }
    for (i in seq_along(systems_expected)) {
        curated <- r[[3]][i]
        cw <- first_word(curated)
        if (cw %in% verdicts) {
            csvw <- first_word(rw[[csv_col]][i])
            ## 'not yet' in the CSV condenses to 'not yet'; treat 'not' as
            ## its own verdict-compatible token.
            ok <- (csvw == cw) ||
                (cw == "no" && csvw == "not") || (cw == "not" && csvw == "not")
            if (!ok) {
                stop(sprintf(
                    "drift: %s / %s: curated '%s' vs CSV '%s...'",
                    r[[1]], systems_expected[i], curated,
                    substr(rw[[csv_col]][i], 1, 40)), call. = FALSE)
            }
        }
    }
}

caption_rw <- paste(
    "Design comparison of SQL-oriented machine learning systems across",
    "seventeen dimensions, condensed for print from the version-controlled",
    "comparison data in the companion repository.")

foot_rw <- paste(
    "Spark = Apache Spark MLlib; PgML = PostgresML; H2O = H2O-3 +",
    "Sparkling Water. FbSQL, MADlib, Spark, and PgML entries are backed by",
    "executed experiments in pinned Docker environments; Hivemall and H2O",
    "entries are literature-based, with per-claim sources recorded in the",
    "companion repository. TBD marks cells the reviewed documentation does",
    "not settle. This table condenses data/related\\_work.csv (companion",
    "repository), which holds the full uncondensed cell text.")

tex <- c(
    "% Generated by FbSQL-experiments/scripts/51_generate_paper_tables.R",
    "% from data/related_work.csv -- do not edit by hand.",
    "\\begin{table}[t!]",
    "\\centering",
    sprintf("\\caption{%s}", caption_rw),
    "\\label{tab:related-work}",
    "\\scriptsize",
    "\\setlength{\\tabcolsep}{3pt}",
    "\\renewcommand{\\arraystretch}{1.2}",
    paste0("\\begin{tabular}{@{}p{2.3cm}p{1.8cm}p{1.85cm}p{1.85cm}",
           "p{1.8cm}p{1.8cm}p{1.85cm}@{}}"),
    "\\toprule",
    paste0(" & ", paste(sprintf("\\textbf{%s}", headers), collapse = " & "),
           " \\\\"),
    "\\midrule",
    vapply(rows, function(r) {
        paste0(r[[1]], " & ", paste(r[[3]], collapse = " & "), " \\\\")
    }, character(1)),
    "\\bottomrule",
    "\\end{tabular}",
    "\\par\\vspace{4pt}",
    "\\begin{minipage}{0.98\\linewidth}\\scriptsize",
    foot_rw,
    "\\end{minipage}",
    "\\end{table}")
writeLines(tex, file.path(out_dir, "related_work.tex"))

md_cell <- function(x) {
    x <- gsub("\\\\\\(\\\\to\\\\\\)", "→", x)     # \(\to\) -> arrow
    x <- gsub("\\\\_", "_", x, fixed = FALSE)      # \_ -> _
    gsub("\\\\ ", " ", x, fixed = FALSE)           # \  -> space (coef.\ )
}
md <- c(
    "<!-- Generated by FbSQL-experiments/scripts/51_generate_paper_tables.R -->",
    paste0("**Table 1:** ", caption_rw),
    "",
    paste0("| | ", paste(headers, collapse = " | "), " |"),
    paste0("|---|", paste(rep("---", length(headers)), collapse = "|"), "|"),
    vapply(rows, function(r) {
        paste0("| ", r[[1]], " | ",
               paste(md_cell(r[[3]]), collapse = " | "), " |")
    }, character(1)),
    "",
    paste0("*", md_cell(foot_rw), "*"))
writeLines(md, file.path(out_dir, "related_work.md"))

## ---- Table 2: customer dataset ------------------------------------------

cu <- read.csv("data/customer.csv", stringsAsFactors = FALSE,
               colClasses = "character", check.names = FALSE)
stopifnot(identical(names(cu),
                    c("customer_id", "created_at", "age", "gender",
                      "churn_flag")))
cu[cu == "" | is.na(cu)] <- "NULL"
is_2025 <- grepl("^2025", cu$created_at)

caption_cu <- paste(
    "The customer table of the running example: twelve 2025 rows with",
    "observed churn train the model, and five 2026 rows with unknown churn",
    "are scored. Customer c104 has a NULL age; customer c105 carries a",
    "gender level unseen in 2025.")

row_tex <- function(df) {
    apply(df, 1, function(x) paste0(paste(x, collapse = " & "), " \\\\"))
}
tex2 <- c(
    "% Generated by FbSQL-experiments/scripts/51_generate_paper_tables.R",
    "% from data/customer.csv -- do not edit by hand.",
    "\\begin{table}[t!]",
    "\\centering",
    sprintf("\\caption{%s}", caption_cu),
    "\\label{tab:customer}",
    "\\small",
    "\\begin{tabular}{@{}llrll@{}}",
    "\\toprule",
    paste0("customer\\_id & created\\_at & age & gender & ",
           "churn\\_flag \\\\"),
    "\\midrule",
    row_tex(cu[is_2025, ]),
    "\\midrule",
    row_tex(cu[!is_2025, ]),
    "\\bottomrule",
    "\\end{tabular}",
    "\\end{table}")
writeLines(tex2, file.path(out_dir, "customer_dataset.tex"))

md2 <- c(
    "<!-- Generated by FbSQL-experiments/scripts/51_generate_paper_tables.R -->",
    paste0("**Table 2:** ", caption_cu),
    "",
    paste0("| ", paste(names(cu), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(cu)), collapse = "|"), "|"),
    apply(cu, 1, function(x) paste0("| ", paste(x, collapse = " | "), " |")))
writeLines(md2, file.path(out_dir, "customer_dataset.md"))

## ---- Table 3: interface overhead -----------------------------------------

ob <- read.csv("results/summary/overhead_benchmark.csv",
               stringsAsFactors = FALSE)
stopifnot(identical(names(ob), c("n", "op", "median_ms", "reps")))
sizes <- sort(unique(ob$n))
pick <- function(n, op) ob$median_ms[ob$n == n & ob$op == op]

caption_ob <- paste(
    "Median wall-clock time of three runs on the pinned reference",
    "environment: fitting through fit\\_glm() versus calling stats::glm()",
    "directly in R on identical data, and predict\\_glm() scoring the same",
    "number of rows. Reported to bound the interface overhead, not as a",
    "performance claim.")

tex3 <- c(
    "% Generated by FbSQL-experiments/scripts/51_generate_paper_tables.R",
    "% from results/summary/overhead_benchmark.csv -- do not edit by hand.",
    "\\begin{table}[t!]",
    "\\centering",
    sprintf("\\caption{%s}", caption_ob),
    "\\label{tab:overhead}",
    "\\small",
    "\\begin{tabular}{@{}rrrr@{}}",
    "\\toprule",
    paste0("rows & fit\\_glm & R glm & predict\\_glm \\\\"),
    "& (ms) & (ms) & (ms) \\\\",
    "\\midrule",
    vapply(sizes, function(n) {
        sprintf("%s & %.0f & %.0f & %.0f \\\\",
                format(n, big.mark = ",", scientific = FALSE),
                pick(n, "fit_glm"), pick(n, "r_glm"),
                pick(n, "predict_glm"))
    }, character(1)),
    "\\bottomrule",
    "\\end{tabular}",
    "\\end{table}")
writeLines(tex3, file.path(out_dir, "overhead_benchmark.tex"))

md3 <- c(
    "<!-- Generated by FbSQL-experiments/scripts/51_generate_paper_tables.R -->",
    paste0("**Table 3:** ", gsub("\\\\_", "_", caption_ob)),
    "",
    "| rows | fit_glm (ms) | R glm (ms) | predict_glm (ms) |",
    "|---|---|---|---|",
    vapply(sizes, function(n) {
        sprintf("| %s | %.0f | %.0f | %.0f |",
                format(n, big.mark = ",", scientific = FALSE),
                pick(n, "fit_glm"), pick(n, "r_glm"),
                pick(n, "predict_glm"))
    }, character(1)))
writeLines(md3, file.path(out_dir, "overhead_benchmark.md"))

cat("wrote", file.path(out_dir, c(
    "related_work.tex", "related_work.md",
    "customer_dataset.tex", "customer_dataset.md",
    "overhead_benchmark.tex", "overhead_benchmark.md")), sep = "\n")
