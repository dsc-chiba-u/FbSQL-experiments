# Put the FbSQL and PostgresML running-example outputs side by side and
# write a summary CSV. Unlike the MADlib comparison, numeric agreement is
# NOT expected: PostgresML fits its own estimator (scikit-learn/linfa
# behind an algorithm-name API) rather than an R-parity GLM, and its
# pgml.predict() output scale (class label vs probability) is part of what
# this comparison documents. The script is informational and never fails
# on value differences.
#
# Run inside the fbsql-dev container from the repo root:
#     docker run --rm -u "$(id -u):$(id -g)" -v "$PWD":/exp -w /exp fbsql-dev \
#         Rscript scripts/42_compare_fbsql_postgresml.R

read_out <- function(path) {
    if (!file.exists(path))
        stop(sprintf("missing %s: run scripts 10 and 41 first", path),
             call. = FALSE)
    read.csv(path, stringsAsFactors = FALSE)
}

pred_fbsql <- read_out("results/raw/running_example_predictions_fbsql.csv")
pred_pgml  <- read_out("results/raw/running_example_predictions_postgresml.csv")

pred <- merge(pred_fbsql, pred_pgml, by = "customer_id",
              suffixes = c("_fbsql", "_postgresml"), all = TRUE)

summary_df <- data.frame(
    section     = "prediction",
    item        = pred$customer_id,
    fbsql       = pred$churn_flag_predicted_fbsql,
    postgresml  = pred$churn_flag_predicted_postgresml,
    note        = "values not expected to match: FbSQL is an R-parity GLM probability; PostgresML output comes from its own estimator (see api design notes)"
)

dir.create("results/summary", recursive = TRUE, showWarnings = FALSE)
write.csv(summary_df, "results/summary/postgresml_running_example_summary.csv",
          row.names = FALSE, na = "")
print(summary_df[, c("item", "fbsql", "postgresml")], row.names = FALSE)
cat("OK: wrote results/summary/postgresml_running_example_summary.csv\n")
