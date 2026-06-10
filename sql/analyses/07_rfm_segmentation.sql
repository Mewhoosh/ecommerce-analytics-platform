-- Business question: segment customers by RFM (Recency, Frequency, Monetary).
-- Each customer scored 1-5 on each axis using NTILE(5); higher = better.
-- Note on Recency: lower recency_days = more recent = better, so we ORDER BY DESC
--   to put the worst (oldest) customers in tile 1 and best (most recent) in tile 5.
-- Segments are a simple rule-based mapping over (R, F, M).

WITH snapshot AS (
    -- "Today" for this analysis = the latest order date in the dataset.
    SELECT MAX(order_purchase_timestamp)::date AS as_of FROM orders
),
customer_metrics AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id)            AS frequency,
        SUM(oi.price + oi.freight_value)      AS monetary,
        MAX(o.order_purchase_timestamp)::date AS last_purchase
    FROM   customers c
    JOIN   orders o       ON o.customer_id = c.customer_id
    JOIN   order_items oi ON oi.order_id   = o.order_id
    WHERE  o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
rfm AS (
    SELECT
        cm.customer_unique_id,
        (s.as_of - cm.last_purchase) AS recency_days,
        cm.frequency,
        cm.monetary
    FROM customer_metrics cm
    CROSS JOIN snapshot s
),
scored AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency)         AS f_score,
        NTILE(5) OVER (ORDER BY monetary)          AS m_score
    FROM rfm
)
SELECT
    customer_unique_id,
    recency_days,
    frequency,
    monetary,
    r_score, f_score, m_score,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 4 AND f_score >= 2                  THEN 'Loyal'
        WHEN r_score >= 4                                   THEN 'Promising'
        WHEN r_score <= 2 AND f_score >= 4                  THEN 'At Risk'
        WHEN r_score <= 2                                   THEN 'Lost'
        ELSE 'Needs Attention'
    END AS segment
FROM scored
ORDER BY monetary DESC
LIMIT 100;
