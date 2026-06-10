-- Business question: cohort retention — what % of customers from a given
-- acquisition month come back N months later?
-- A "cohort" is grouped by the month of the customer's first delivered order.
-- For Olist, repeat purchase rate is low (~3%); the shape of decay is the insight.
-- Limited to the first 6 months after first purchase for readability.

WITH first_purchase AS (
    SELECT
        c.customer_unique_id,
        DATE_TRUNC('month', MIN(o.order_purchase_timestamp))::date AS cohort_month
    FROM   customers c
    JOIN   orders o ON o.customer_id = c.customer_id
    WHERE  o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
customer_activity AS (
    SELECT DISTINCT
        c.customer_unique_id,
        DATE_TRUNC('month', o.order_purchase_timestamp)::date AS active_month
    FROM   customers c
    JOIN   orders o ON o.customer_id = c.customer_id
    WHERE  o.order_status = 'delivered'
),
cohort_activity AS (
    SELECT
        fp.cohort_month,
        ca.active_month,
        (EXTRACT(YEAR  FROM AGE(ca.active_month, fp.cohort_month)) * 12
       + EXTRACT(MONTH FROM AGE(ca.active_month, fp.cohort_month)))::int AS months_since,
        COUNT(DISTINCT ca.customer_unique_id) AS active_customers
    FROM   first_purchase fp
    JOIN   customer_activity ca
              ON ca.customer_unique_id = fp.customer_unique_id
    GROUP BY fp.cohort_month, ca.active_month
),
cohort_size AS (
    SELECT cohort_month, COUNT(*) AS cohort_size
    FROM   first_purchase
    GROUP BY cohort_month
)
SELECT
    ca.cohort_month,
    cs.cohort_size,
    ca.months_since,
    ca.active_customers,
    ROUND(100.0 * ca.active_customers / cs.cohort_size, 2) AS retention_pct
FROM   cohort_activity ca
JOIN   cohort_size cs ON cs.cohort_month = ca.cohort_month
WHERE  ca.months_since <= 6
ORDER BY ca.cohort_month, ca.months_since;
