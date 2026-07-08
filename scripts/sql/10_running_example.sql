-- Customer churn running example, executed against the FbSQL extension.
-- Loaded data comes from /exp/data/customer.csv (2025 = training, 2026 =
-- scoring; c104 has NULL age, c105 has a gender level unseen in 2025).
CREATE TABLE customer (
    customer_id VARCHAR,
    created_at  TIMESTAMP,
    age         INTEGER,
    gender      VARCHAR,
    churn_flag  BOOLEAN
);

\copy customer FROM '/exp/data/customer.csv' WITH (FORMAT csv, HEADER true)

CREATE TABLE logit_model AS
SELECT *
FROM
 fbsql.fit_glm(
  relation => $$
   SELECT churn_flag, age, gender
   FROM customer
   WHERE DATE_PART('YEAR', created_at) = 2025
  $$,
  formula => 'churn_flag ~ age + gender',
  family => 'binomial')
;

\copy (SELECT term, round(estimate::numeric, 4) AS estimate, round(std_error::numeric, 4) AS std_error FROM logit_model ORDER BY term) TO '/exp/results/raw/running_example_model_fbsql.csv' WITH (FORMAT csv, HEADER true)

-- on_new_levels => 'na': the unseen level (c105) predicts NULL, everything
-- else predicts normally, so one relation covers all 2026 customers.
\copy (SELECT customer_id, round(churn_flag_predicted::numeric, 4) AS churn_flag_predicted FROM fbsql.predict_glm(relation => $$ SELECT customer_id, age, gender FROM customer WHERE DATE_PART('YEAR', created_at) = 2026 $$, model => $$ SELECT * FROM logit_model $$, on_new_levels => 'na') AS p(customer_id varchar, age integer, gender varchar, churn_flag_predicted double precision) ORDER BY customer_id) TO '/exp/results/raw/running_example_predictions_fbsql.csv' WITH (FORMAT csv, HEADER true)
