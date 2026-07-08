# Customer churn running example on Apache Spark MLlib, for API-design
# comparison with FbSQL (not a performance benchmark).
#
# Spark is not SQL-ML in FbSQL's sense: SQL (spark.sql) is used to define
# the training/scoring relations, but the model itself is fit through the
# DataFrame/Pipeline API. RFormula provides an R-formula-style interface
# (one-hot encoding of string columns with the first level dropped), and
# GeneralizedLinearRegression(binomial/logit) is the closest analogue of
# glm(). Predictions come back as a DataFrame from model.transform().
import csv
import os

from pyspark.sql import SparkSession
from pyspark.ml import Pipeline
from pyspark.ml.feature import RFormula
from pyspark.ml.regression import GeneralizedLinearRegression

OUT_DIR = "/exp/results/raw"

spark = SparkSession.builder.getOrCreate()
spark.sparkContext.setLogLevel("ERROR")

customer = (spark.read.csv("/exp/data/customer.csv", header=True)
            .selectExpr("customer_id",
                        "timestamp(created_at) AS created_at",
                        "cast(age AS double) AS age",
                        "gender",
                        "cast(churn_flag AS boolean) AS churn_flag"))
customer.createOrReplaceTempView("customer")

# SQL defines the relations; the label must be numeric for RFormula.
train = spark.sql("""
    SELECT cast(churn_flag AS double) AS churn_flag, age, gender
    FROM customer
    WHERE year(created_at) = 2025
""")
score = spark.sql("""
    SELECT customer_id, age, gender
    FROM customer
    WHERE year(created_at) = 2026
""")

formula = RFormula(formula="churn_flag ~ age + gender")
glr = GeneralizedLinearRegression(family="binomial", link="logit")
pipeline = Pipeline(stages=[formula, glr])

model = pipeline.fit(train)
glr_model = model.stages[-1]

# Term names live in the ML attribute metadata of the assembled features
# vector, not in the model itself.
attrs = (model.transform(train)
         .schema["features"].metadata["ml_attr"]["attrs"])
feature_names = [a["name"] for group in attrs.values()
                 for a in sorted(group, key=lambda a: a["idx"])]

summary = glr_model.summary
terms = ["(Intercept)"] + feature_names
estimates = [glr_model.intercept] + list(glr_model.coefficients)
std_errors = summary.coefficientStandardErrors
# Spark orders standard errors as coefficients then intercept.
std_errors = [std_errors[-1]] + list(std_errors[:-1])

os.makedirs(OUT_DIR, exist_ok=True)
with open(f"{OUT_DIR}/running_example_model_spark.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["term", "estimate", "std_error"])
    for t, e, s in sorted(zip(terms, estimates, std_errors)):
        w.writerow([t, round(e, 4), round(s, 4)])

# Default behavior first: transform() on rows with a NULL age (c104) and an
# unseen gender level (c105) fails, which is itself a finding.
print("=== default handleInvalid='error' on 2026 data ===")
try:
    model.transform(score).select("customer_id", "prediction").collect()
    print("transform succeeded (unexpected)")
except Exception as exc:  # noqa: BLE001 - the message is the data we want
    first_line = str(exc).splitlines()[0]
    print("transform failed as shipped:", first_line[:300])

# handleInvalid='skip' silently DROPS the offending rows -- the output
# relation changes granularity, unlike FbSQL's NULL-preserving policy.
formula_skip = RFormula(formula="churn_flag ~ age + gender",
                        handleInvalid="skip")
model_skip = Pipeline(stages=[formula_skip, glr]).fit(train)
pred_rows = (model_skip.transform(score)
             .select("customer_id", "prediction")
             .collect())
pred = {r["customer_id"]: round(r["prediction"], 4) for r in pred_rows}

all_ids = sorted(r["customer_id"]
                 for r in score.select("customer_id").collect())
with open(f"{OUT_DIR}/running_example_predictions_spark.csv", "w",
          newline="") as f:
    w = csv.writer(f)
    w.writerow(["customer_id", "churn_flag_predicted"])
    for cid in all_ids:
        # Rows dropped by handleInvalid='skip' get an empty prediction so
        # the CSV keeps the scoring relation's granularity for comparison.
        w.writerow([cid, pred.get(cid, "")])

print("=== handleInvalid='skip' predictions (dropped rows have no output) ===")
for cid in sorted(pred):
    print(cid, pred[cid])
print("rows in scoring relation:", score.count(),
      "/ rows in prediction output:", len(pred_rows))

spark.stop()
print("OK: wrote running_example_model_spark.csv and running_example_predictions_spark.csv")
