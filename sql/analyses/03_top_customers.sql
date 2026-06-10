-- Business question: who are our top spenders?
-- Shows ROW_NUMBER vs RANK vs DENSE_RANK side by side to compare behavior on ties.
-- Customer identity = customer_unique_id (not per-order customer_id).

WITH customer_revenue AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id)        AS orders_count,
        SUM(oi.price + oi.freight_value)  AS total_spent
    FROM   customers c
    JOIN   orders o       ON o.customer_id  = c.customer_id
    JOIN   order_items oi ON oi.order_id    = o.order_id
    WHERE  o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT
    customer_unique_id,
    orders_count,
    total_spent,
    ROW_NUMBER() OVER (ORDER BY total_spent DESC) AS row_num,    -- always unique
    RANK()       OVER (ORDER BY total_spent DESC) AS rnk,         -- ties share, then gap
    DENSE_RANK() OVER (ORDER BY total_spent DESC) AS dense_rnk    -- ties share, no gap
FROM customer_revenue
ORDER BY total_spent DESC
LIMIT 25;
