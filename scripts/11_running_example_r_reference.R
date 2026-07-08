# R reference for the customer churn running example: fit and predict with
# stats::glm() on the same data/customer.csv, writing CSVs shaped like the
# FbSQL outputs (results/raw/running_example_*_fbsql.csv).
#
# Run inside the fbsql-dev container (pinned R) from the repo root:
#     docker run --rm -u "$(id -u):$(id -g)" -v "$PWD":/exp -w /exp fbsql-dev \
#         Rscript scripts/11_running_example_r_reference.R

customer <- read.csv("data/customer.csv", stringsAsFactors = FALSE)
customer$churn_flag <- as.logical(customer$churn_flag)
customer$year <- as.integer(substr(customer$created_at, 1, 4))

train <- customer[customer$year == 2025, ]
score <- customer[customer$year == 2026, ]

fit <- stats::glm(churn_flag ~ age + gender, data = train,
                  family = stats::binomial())

coefs <- summary(fit)$coefficients
model_out <- data.frame(term      = rownames(coefs),
                        estimate  = round(coefs[, 1], 4),
                        std_error = round(coefs[, 2], 4),
                        row.names = NULL)
model_out <- model_out[order(model_out$term), ]

# R's predict() errors on factor levels unseen at fit time, so mimic
# FbSQL's on_new_levels => 'na': predict only rows with known levels and
# report NA for the rest.
known <- score$gender %in% fit$xlevels$gender
pred <- rep(NA_real_, nrow(score))
pred[known] <- stats::predict(fit, newdata = score[known, ],
                              type = "response")
pred_out <- data.frame(customer_id          = score$customer_id,
                       churn_flag_predicted = round(pred, 4))
pred_out <- pred_out[order(pred_out$customer_id), ]

dir.create("results/raw", recursive = TRUE, showWarnings = FALSE)
write.csv(model_out, "results/raw/running_example_model_r.csv",
          row.names = FALSE, na = "")
write.csv(pred_out, "results/raw/running_example_predictions_r.csv",
          row.names = FALSE, na = "")
cat("OK: wrote results/raw/running_example_model_r.csv and running_example_predictions_r.csv\n")
