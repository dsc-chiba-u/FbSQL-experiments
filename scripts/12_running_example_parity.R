# Compare the FbSQL and R outputs of the running example (both rounded to
# 4 decimals at the source) and write a parity summary. Exits non-zero on
# any mismatch so the pipeline can be used as a check.
#
# Run inside the fbsql-dev container from the repo root:
#     docker run --rm -u "$(id -u):$(id -g)" -v "$PWD":/exp -w /exp fbsql-dev \
#         Rscript scripts/12_running_example_parity.R

read_out <- function(path) {
    if (!file.exists(path))
        stop(sprintf("missing %s: run scripts 10 and 11 first", path),
             call. = FALSE)
    read.csv(path, stringsAsFactors = FALSE)
}

model_fbsql <- read_out("results/raw/running_example_model_fbsql.csv")
model_r     <- read_out("results/raw/running_example_model_r.csv")
pred_fbsql  <- read_out("results/raw/running_example_predictions_fbsql.csv")
pred_r      <- read_out("results/raw/running_example_predictions_r.csv")

model <- merge(model_fbsql, model_r, by = "term",
               suffixes = c("_fbsql", "_r"), all = TRUE)
pred <- merge(pred_fbsql, pred_r, by = "customer_id",
              suffixes = c("_fbsql", "_r"), all = TRUE)

same <- function(a, b) (is.na(a) & is.na(b)) | (!is.na(a) & !is.na(b) & a == b)

parity <- rbind(
    data.frame(section = "model", item = model$term,
               fbsql = model$estimate_fbsql, r = model$estimate_r,
               match = same(model$estimate_fbsql, model$estimate_r)),
    data.frame(section = "model_std_error", item = model$term,
               fbsql = model$std_error_fbsql, r = model$std_error_r,
               match = same(model$std_error_fbsql, model$std_error_r)),
    data.frame(section = "prediction", item = pred$customer_id,
               fbsql = pred$churn_flag_predicted_fbsql,
               r = pred$churn_flag_predicted_r,
               match = same(pred$churn_flag_predicted_fbsql,
                            pred$churn_flag_predicted_r))
)

dir.create("results/summary", recursive = TRUE, showWarnings = FALSE)
write.csv(parity, "results/summary/running_example_parity.csv",
          row.names = FALSE, na = "")
print(parity, row.names = FALSE)

if (all(parity$match)) {
    cat("OK: FbSQL and R agree on all", nrow(parity), "values\n")
} else {
    cat("NG:", sum(!parity$match), "mismatches\n")
    quit(status = 1L)
}
