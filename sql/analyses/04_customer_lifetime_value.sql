-- Business question: how do we rank customers by lifetime value (CLV)?
-- CLV = total realized revenue per unique customer.
-- Olist has a very low repeat rate (~3%) — most customers are one-shot.
-- This pattern itself is the insight (acquisition-heavy, retention-poor).

WITH order_totals AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.order_purchase_timestamp,
        SUM(oi.price + oi.freight_value) AS order_value
    FROM   orders o
    JOIN   order_items oi ON oi.order_id = o.order_id
    WHERE  o.order_status = 'delivered'
    GROUP BY o.order_id, o.customer_id, o.order_purchase_timestamp
),
customer_summary AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT ot.order_id)        AS orders_count,
        SUM(ot.order_value)                AS clv,
        ROUND(AVG(ot.order_value), 2)      AS avg_order_value,
        MIN(ot.order_purchase_timestamp)   AS first_purchase,
        MAX(ot.order_purchase_timestamp)   AS last_purchase
    FROM   customers c
    JOIN   order_totals ot ON ot.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
)
SELECT
    customer_unique_id,
    orders_count,
    clv,
    avg_order_value,
    first_purchase::date  AS first_purchase,
    last_purchase::date   AS last_purchase,
    (last_purchase::date - first_purchase::date) AS days_active
FROM customer_summary
ORDER BY clv DESC
LIMIT 25;
