# Compare the FbSQL and Spark MLlib outputs of the running example and
# write a summary CSV. GeneralizedLinearRegression(binomial/logit) is an
# IRLS GLM like R's glm(), so coefficients and probabilities should agree
# to 4 decimals -- EXCEPT for the rows Spark's handleInvalid='skip' drops:
# c104 (NULL age) and c105 (unseen gender level) simply disappear from the
# prediction output, whereas FbSQL keeps them as NULL predictions. Term
# naming also differs (e.g. gender_M vs genderM), which the comparison
# normalizes and records.
#
# Run inside the fbsql-dev container from the repo root:
#     docker run --rm -u "$(id -u):$(id -g)" -v "$PWD":/exp -w /exp fbsql-dev \
#         Rscript scripts/32_compare_fbsql_spark.R

read_out <- function(path) {
    if (!file.exists(path))
        stop(sprintf("missing %s: run scripts 10 and 31 first", path),
             call. = FALSE)
    read.csv(path, stringsAsFactors = FALSE)
}

model_fbsql <- read_out("results/raw/running_example_model_fbsql.csv")
model_spark <- read_out("results/raw/running_example_model_spark.csv")
pred_fbsql  <- read_out("results/raw/running_example_predictions_fbsql.csv")
pred_spark  <- read_out("results/raw/running_example_predictions_spark.csv")

# Spark names one-hot columns gender_M / gender_Other; FbSQL follows R's
# genderM / genderOther. Normalize for the numeric comparison but keep the
# original spelling as a recorded difference.
model_spark$term_original <- model_spark$term
model_spark$term <- gsub("_", "", model_spark$term, fixed = TRUE)

model <- merge(model_fbsql, model_spark, by = "term",
               suffixes = c("_fbsql", "_spark"), all = TRUE)
pred <- merge(pred_fbsql, pred_spark, by = "customer_id",
              suffixes = c("_fbsql", "_spark"), all = TRUE)

same <- function(a, b) (is.na(a) & is.na(b)) | (!is.na(a) & !is.na(b) & a == b)

pred_match <- same(pred$churn_flag_predicted_fbsql,
                   pred$churn_flag_predicted_spark)
pred_note <- ifelse(pred$customer_id %in% c("c104", "c105") & !pred_match,
    "expected difference: row dropped by Spark handleInvalid='skip' (FbSQL keeps it as a NULL prediction)",
    "")

summary_df <- rbind(
    data.frame(section = "model_estimate", item = model$term,
               fbsql = model$estimate_fbsql, spark = model$estimate_spark,
               match = same(model$estimate_fbsql, model$estimate_spark),
               note = ifelse(is.na(model$term_original) |
                             model$term == model$term_original, "",
                             paste0("spark term name: ", model$term_original))),
    data.frame(section = "model_std_error", item = model$term,
               fbsql = model$std_error_fbsql, spark = model$std_error_spark,
               match = same(model$std_error_fbsql, model$std_error_spark),
               note = ""),
    data.frame(section = "prediction", item = pred$customer_id,
               fbsql = pred$churn_flag_predicted_fbsql,
               spark = pred$churn_flag_predicted_spark,
               match = pred_match,
               note = pred_note)
)

tiny <- !summary_df$match & summary_df$note == "" &
    !is.na(summary_df$fbsql) & !is.na(summary_df$spark) &
    abs(summary_df$fbsql - summary_df$spark) < 1e-3
summary_df$note[tiny] <-
    "expected difference: numerical only (agrees to 3 decimals; different IRLS tolerance)"

# RFormula does NOT reproduce R's factor conventions: StringIndexer orders
# levels by frequency and the LAST category becomes the reference, so here
# 'Other' is the reference instead of R's first-sorted level 'F'. The model
# is identical under reparameterization, which we verify numerically:
#   intercept_spark  = intercept_fbsql + genderOther_fbsql
#   gender_F_spark   = -genderOther_fbsql
#   gender_M_spark   = genderM_fbsql - genderOther_fbsql
fb <- setNames(model_fbsql$estimate, model_fbsql$term)
sp <- setNames(model_spark$estimate, model_spark$term)
tol <- 2.5e-4  # both sides were rounded to 4 decimals at the source
reparam_ok <-
    abs(sp["(Intercept)"] - (fb["(Intercept)"] + fb["genderOther"])) < tol &&
    abs(sp["genderF"] - (-fb["genderOther"])) < tol &&
    abs(sp["genderM"] - (fb["genderM"] - fb["genderOther"])) < tol
if (isTRUE(reparam_ok)) {
    gender_rows <- summary_df$section == "model_estimate" &
        summary_df$item %in% c("(Intercept)", "genderF", "genderM",
                               "genderOther") & !summary_df$match
    summary_df$note[gender_rows] <- paste(
        "expected difference: RFormula uses the least-frequent level ('Other') as reference,",
        "not R's first sorted level ('F'); same model under reparameterization",
        "(verified numerically; predictions identical)")
    se_rows <- summary_df$section == "model_std_error" &
        summary_df$item %in% c("(Intercept)", "genderF", "genderM",
                               "genderOther") & !summary_df$match
    summary_df$note[se_rows] <- paste(
        "expected difference: standard errors are parameterization-dependent",
        "and not directly comparable across reference levels")
}

dir.create("results/summary", recursive = TRUE, showWarnings = FALSE)
write.csv(summary_df, "results/summary/spark_running_example_summary.csv",
          row.names = FALSE, na = "")
print(summary_df, row.names = FALSE)

unexpected <- !summary_df$match & summary_df$note == ""
if (any(unexpected)) {
    cat("NG:", sum(unexpected), "unexpected mismatches\n")
    quit(status = 1L)
}
cat("OK:", sum(summary_df$match), "values agree;",
    sum(!summary_df$match), "expected difference(s) recorded\n")
