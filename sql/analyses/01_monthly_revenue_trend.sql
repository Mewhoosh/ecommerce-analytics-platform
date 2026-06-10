-- Business question: how does revenue evolve month over month?
-- Revenue counts only delivered orders (intent vs realized).
-- Order value = SUM(price + freight) over its line items.

WITH monthly AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
        SUM(oi.price + oi.freight_value)                AS revenue
    FROM   orders o
    JOIN   order_items oi ON oi.order_id = o.order_id
    WHERE  o.order_status = 'delivered'
    GROUP BY 1
)
SELECT
    month,
    revenue,
    LAG(revenue) OVER (ORDER BY month) AS revenue_prev_month,
    ROUND(
        100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
              / LAG(revenue) OVER (ORDER BY month),
        2
    ) AS mom_growth_pct
FROM monthly
ORDER BY month;
