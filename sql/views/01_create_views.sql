-- Views layer for the Power BI dashboard.
-- Each view encapsulates a piece of business logic so the BI tool consumes
-- a clean, denormalized shape instead of re-implementing joins in DAX.


-- One row per order, enriched with totals and customer geography.
-- This is the main fact table for the dashboard.
CREATE OR REPLACE VIEW vw_orders_enriched AS
WITH order_totals AS (
    SELECT
        order_id,
        COUNT(*)                    AS items_count,
        COUNT(DISTINCT seller_id)   AS sellers_count,
        SUM(price)                  AS items_subtotal,
        SUM(freight_value)          AS freight_total,
        SUM(price + freight_value)  AS order_value
    FROM order_items
    GROUP BY order_id
)
SELECT
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    c.customer_state,
    c.customer_city,
    o.order_status,
    o.order_purchase_timestamp,
    DATE_TRUNC('month', o.order_purchase_timestamp)::date AS purchase_month,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    (o.order_delivered_customer_date::date
     - o.order_estimated_delivery_date::date) AS delivery_delay_days,
    ot.items_count,
    ot.sellers_count,
    ot.order_value,
    ot.items_subtotal,
    ot.freight_total
FROM   orders o
JOIN   customers c     ON c.customer_id = o.customer_id
JOIN   order_totals ot ON ot.order_id   = o.order_id;


-- Monthly revenue with month-over-month growth.
-- Delivered orders only.
CREATE OR REPLACE VIEW vw_monthly_revenue AS
WITH monthly AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp)::date AS month,
        COUNT(DISTINCT o.order_id)             AS orders,
        COUNT(DISTINCT c.customer_unique_id)   AS customers,
        SUM(oi.price + oi.freight_value)       AS revenue
    FROM   orders o
    JOIN   order_items oi ON oi.order_id = o.order_id
    JOIN   customers c    ON c.customer_id = o.customer_id
    WHERE  o.order_status = 'delivered'
    GROUP BY 1
)
SELECT
    month,
    orders,
    customers,
    revenue,
    LAG(revenue) OVER (ORDER BY month) AS revenue_prev_month,
    ROUND(
        100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
              / NULLIF(LAG(revenue) OVER (ORDER BY month), 0),
        2
    ) AS mom_growth_pct
FROM monthly;


-- One row per unique customer with CLV and RFM-derived segment.
-- Snapshot date = latest order date in the dataset (so recency is relative).
CREATE OR REPLACE VIEW vw_customer_clv AS
WITH snapshot AS (
    SELECT MAX(order_purchase_timestamp)::date AS as_of FROM orders
),
metrics AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id)                  AS orders_count,
        SUM(oi.price + oi.freight_value)            AS clv,
        ROUND(AVG(oi.price + oi.freight_value), 2)  AS avg_item_value,
        MIN(o.order_purchase_timestamp)::date       AS first_purchase,
        MAX(o.order_purchase_timestamp)::date       AS last_purchase
    FROM   customers c
    JOIN   orders o       ON o.customer_id = c.customer_id
    JOIN   order_items oi ON oi.order_id   = o.order_id
    WHERE  o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
scored AS (
    SELECT
        m.customer_unique_id,
        m.orders_count,
        m.clv,
        m.avg_item_value,
        m.first_purchase,
        m.last_purchase,
        (m.last_purchase - m.first_purchase) AS days_active,
        (s.as_of - m.last_purchase)          AS recency_days,
        NTILE(5) OVER (ORDER BY (s.as_of - m.last_purchase) DESC) AS r_score,
        NTILE(5) OVER (ORDER BY m.orders_count)                   AS f_score,
        NTILE(5) OVER (ORDER BY m.clv)                            AS m_score
    FROM   metrics m
    CROSS JOIN snapshot s
)
SELECT
    customer_unique_id,
    orders_count,
    clv,
    avg_item_value,
    first_purchase,
    last_purchase,
    days_active,
    recency_days,
    r_score, f_score, m_score,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 4 AND f_score >= 2                  THEN 'Loyal'
        WHEN r_score >= 4                                   THEN 'Promising'
        WHEN r_score <= 2 AND f_score >= 4                  THEN 'At Risk'
        WHEN r_score <= 2                                   THEN 'Lost'
        ELSE 'Needs Attention'
    END AS segment
FROM scored;


-- Per-state delivery performance: on-time rate, average delay/lateness.
CREATE OR REPLACE VIEW vw_delivery_summary AS
WITH delivered AS (
    SELECT
        c.customer_state,
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
GROUP BY customer_state;
