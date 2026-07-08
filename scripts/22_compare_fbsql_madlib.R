# Compare the FbSQL and MADlib outputs of the running example and write a
# summary CSV. Both systems fit the same logistic regression, so
# coefficients and probabilities should agree to 4 decimals -- EXCEPT for
# customer c105, whose gender level was unseen at fit time: FbSQL returns
# NULL under on_new_levels => 'na' (or errors by default), while MADlib's
# manual one-hot encoding silently scores it as the reference level. That
# expected difference is the design finding, so it does not fail the run.
#
# Run inside the fbsql-dev container from the repo root:
#     docker run --rm -u "$(id -u):$(id -g)" -v "$PWD":/exp -w /exp fbsql-dev \
#         Rscript scripts/22_compare_fbsql_madlib.R

read_out <- function(path) {
    if (!file.exists(path))
        stop(sprintf("missing %s: run scripts 10 and 21 first", path),
             call. = FALSE)
    read.csv(path, stringsAsFactors = FALSE)
}

model_fbsql  <- read_out("results/raw/running_example_model_fbsql.csv")
model_madlib <- read_out("results/raw/running_example_model_madlib.csv")
pred_fbsql   <- read_out("results/raw/running_example_predictions_fbsql.csv")
pred_madlib  <- read_out("results/raw/running_example_predictions_madlib.csv")

model <- merge(model_fbsql, model_madlib, by = "term",
               suffixes = c("_fbsql", "_madlib"), all = TRUE)
pred <- merge(pred_fbsql, pred_madlib, by = "customer_id",
              suffixes = c("_fbsql", "_madlib"), all = TRUE)

same <- function(a, b) (is.na(a) & is.na(b)) | (!is.na(a) & !is.na(b) & a == b)

note_for <- function(id, match) {
    ifelse(id == "c105" & !match,
           "expected difference: unseen level; FbSQL NULL by policy, MADlib silently scores as reference level",
           "")
}

summary_df <- rbind(
    data.frame(section = "model_estimate", item = model$term,
               fbsql = model$estimate_fbsql, madlib = model$estimate_madlib,
               match = same(model$estimate_fbsql, model$estimate_madlib),
               note = ""),
    data.frame(section = "model_std_error", item = model$term,
               fbsql = model$std_error_fbsql, madlib = model$std_error_madlib,
               match = same(model$std_error_fbsql, model$std_error_madlib),
               note = ""),
    local({
        m <- same(pred$churn_flag_predicted_fbsql,
                  pred$churn_flag_predicted_madlib)
        data.frame(section = "prediction", item = pred$customer_id,
                   fbsql = pred$churn_flag_predicted_fbsql,
                   madlib = pred$churn_flag_predicted_madlib,
                   match = m,
                   note = note_for(pred$customer_id, m))
    })
)

# Tiny numeric differences (4th decimal) are expected: MADlib's IRLS uses
# its own convergence tolerance, so standard errors can differ in the last
# rounded digit while agreeing to 3 decimals.
tiny <- !summary_df$match & summary_df$note == "" &
    !is.na(summary_df$fbsql) & !is.na(summary_df$madlib) &
    abs(summary_df$fbsql - summary_df$madlib) < 1e-3
summary_df$note[tiny] <-
    "expected difference: numerical only (agrees to 3 decimals; different IRLS tolerance)"

dir.create("results/summary", recursive = TRUE, showWarnings = FALSE)
write.csv(summary_df, "results/summary/madlib_running_example_summary.csv",
          row.names = FALSE, na = "")
print(summary_df, row.names = FALSE)

unexpected <- !summary_df$match & summary_df$note == ""
if (any(unexpected)) {
    cat("NG:", sum(unexpected), "unexpected mismatches\n")
    quit(status = 1L)
}
cat("OK:", sum(summary_df$match), "values agree;",
    sum(!summary_df$match), "expected design difference(s) recorded\n")
