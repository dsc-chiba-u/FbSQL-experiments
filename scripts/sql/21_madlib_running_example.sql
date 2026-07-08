-- Customer churn running example on Apache MADlib, for API-design
-- comparison with FbSQL (not a performance benchmark).
--
-- The deliberate contrast: FbSQL takes formula => 'churn_flag ~ age +
-- gender' and handles the factor itself, while MADlib's array interface
-- requires manual one-hot encoding of gender before training.
CREATE TABLE customer (
    customer_id VARCHAR,
    created_at  TIMESTAMP,
    age         INTEGER,
    gender      VARCHAR,
    churn_flag  BOOLEAN
);

\copy customer FROM '/exp/data/customer.csv' WITH (FORMAT csv, HEADER true)

-- Manual one-hot encoding (reference level F dropped by hand).
CREATE TABLE customer_2025_encoded AS
SELECT churn_flag,
       age::double precision,
       (gender = 'M')::int     AS gender_m,
       (gender = 'Other')::int AS gender_other
FROM customer
WHERE DATE_PART('YEAR', created_at) = 2025;

SELECT madlib.logregr_train(
    'customer_2025_encoded',                  -- source table (by name)
    'churn_model',                            -- output table (by name)
    'churn_flag',                             -- dependent variable
    'ARRAY[1, age, gender_m, gender_other]'   -- independent variables
);

-- What the model relation looks like (structure is part of the comparison).
\d churn_model

-- Coefficients live in parallel arrays; term names exist only in the
-- analyst's head, so we attach them manually for the comparison output.
\copy (SELECT unnest(ARRAY['(Intercept)','age','genderM','genderOther']) AS term, round(unnest(coef)::numeric, 4) AS estimate, round(unnest(std_err)::numeric, 4) AS std_error FROM churn_model) TO '/exp/results/raw/running_example_model_madlib.csv' WITH (FORMAT csv, HEADER true)

-- Scoring relation with the same manual encoding. Note what happens to the
-- 2026-only level 'Nonbinary' (c105): both dummies are 0, so it is silently
-- scored as the reference level F -- no error, no NULL.
CREATE TABLE customer_2026_encoded AS
SELECT customer_id,
       age::double precision,
       (gender = 'M')::int     AS gender_m,
       (gender = 'Other')::int AS gender_other
FROM customer
WHERE DATE_PART('YEAR', created_at) = 2026;

\copy (SELECT c.customer_id, round(madlib.logregr_predict_prob(m.coef, ARRAY[1, c.age, c.gender_m, c.gender_other])::numeric, 4) AS churn_flag_predicted FROM customer_2026_encoded c CROSS JOIN churn_model m ORDER BY c.customer_id) TO '/exp/results/raw/running_example_predictions_madlib.csv' WITH (FORMAT csv, HEADER true)

-- NULL handling at fit time: append one NULL-age row and retrain to see
-- how MADlib reports dropped rows.
CREATE TABLE customer_2025_with_null AS
SELECT * FROM customer_2025_encoded
UNION ALL
SELECT true, NULL, 0, 0;

SELECT madlib.logregr_train(
    'customer_2025_with_null',
    'churn_model_nullcheck',
    'churn_flag',
    'ARRAY[1, age, gender_m, gender_other]');

SELECT num_rows_processed, num_missing_rows_skipped
FROM churn_model_nullcheck;
