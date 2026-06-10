-- Business question: how reliable is delivery? % on-time vs estimate, average delay.
-- On time = customer received order on or before the estimated delivery date.
-- delay_days < 0 means early; > 0 means late.
-- Breakdown by state shows logistics quality differences across regions.

WITH delivered AS (
    SELECT
        o.order_id,
        c.customer_state,
        o.order_estimated_delivery_date::date  AS estimated,
        o.order_delivered_customer_date::date  AS actual,
        (o.order_delivered_customer_date::date
         - o.order_estimated_delivery_date::date) AS delay_days
    FROM   orders o
    JOIN   customers c ON c.customer_id = o.customer_id
    WHERE  o.order_status = 'delivered'
      AND  o.order_delivered_customer_date IS NOT NULL
)
SELECT
    customer_state,
    COUNT(*)                                                          AS delivered_orders,
    SUM(CASE WHEN delay_days <= 0 THEN 1 ELSE 0 END)                  AS on_time_orders,
    ROUND(
        100.0 * SUM(CASE WHEN delay_days <= 0 THEN 1 ELSE 0 END) / COUNT(*),
        2
    )                                                                 AS on_time_pct,
    ROUND(AVG(delay_days)::numeric, 2)                                AS avg_delay_days,
    ROUND(AVG(GREATEST(delay_days, 0))::numeric, 2)                   AS avg_lateness_days
FROM delivered
GROUP BY customer_state
ORDER BY delivered_orders DESC;
