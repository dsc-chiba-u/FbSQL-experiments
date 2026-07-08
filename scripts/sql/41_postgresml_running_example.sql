-- Customer churn running example on PostgresML, for API-design comparison
-- with FbSQL (not a performance benchmark).
--
-- PostgresML's pgml.train() takes a relation NAME and a label column and
-- uses every other column as a feature; pgml.predict() takes the project
-- name and a homogeneous REAL array. The numeric results are NOT expected
-- to match R's glm(): the point is the shape of the API.
CREATE TABLE customer (
    customer_id VARCHAR,
    created_at  TIMESTAMP,
    age         INTEGER,
    gender      VARCHAR,
    churn_flag  BOOLEAN
);

\copy customer FROM '/exp/data/customer.csv' WITH (FORMAT csv, HEADER true)

-- Numeric-only training relation (age only): every non-label column
-- becomes a feature, so the relation must be shaped by hand first.
CREATE TABLE customer_2025_train AS
SELECT age::real,
       churn_flag::int AS churn_flag
FROM customer
WHERE DATE_PART('YEAR', created_at) = 2025;

SELECT *
FROM pgml.train(
    project_name  => 'fbsql_churn',
    task          => 'classification',
    relation_name => 'customer_2025_train',
    y_column_name => 'churn_flag'
);

-- Where the model actually lives: pgml's own catalog tables, storing a
-- serialized (binary) model rather than a relation of coefficients.
SELECT p.name, m.algorithm, m.status,
       pg_column_size(f.data) AS serialized_model_bytes
FROM pgml.projects p
JOIN pgml.models m ON m.project_id = p.id
LEFT JOIN pgml.files f ON f.model_id = m.id
WHERE p.name = 'fbsql_churn';

-- Predict for 2026 customers. pgml.predict() raises 'ERROR: array
-- contains NULL' on NULL features (probed separately in the runner
-- script), so the NULL-age row (c104) must be guarded by hand.
\copy (SELECT customer_id, CASE WHEN age IS NOT NULL THEN pgml.predict('fbsql_churn', ARRAY[age::real]) END AS churn_flag_predicted FROM customer WHERE DATE_PART('YEAR', created_at) = 2026 ORDER BY customer_id) TO '/tmp/running_example_predictions_postgresml.csv' WITH (FORMAT csv, HEADER true)
