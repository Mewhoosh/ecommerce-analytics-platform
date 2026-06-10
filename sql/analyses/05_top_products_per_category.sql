-- Business question: top 3 best-selling products in each category.
-- Classic "top N per group" pattern using ROW_NUMBER OVER (PARTITION BY ...).
-- Without PARTITION, ROW_NUMBER would rank globally; we want per-category ranking.

WITH product_revenue AS (
    SELECT
        COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
        oi.product_id,
        COUNT(*)                          AS times_sold,
        SUM(oi.price + oi.freight_value)  AS revenue
    FROM   order_items oi
    JOIN   orders o ON o.order_id = oi.order_id
    JOIN   products p ON p.product_id = oi.product_id
    LEFT JOIN product_category_translation t
                    ON t.product_category_name = p.product_category_name
    WHERE  o.order_status = 'delivered'
    GROUP BY 1, oi.product_id
),
ranked AS (
    SELECT
        category,
        product_id,
        times_sold,
        revenue,
        ROW_NUMBER() OVER (PARTITION BY category ORDER BY revenue DESC) AS rank_in_category
    FROM product_revenue
)
SELECT category, rank_in_category, product_id, times_sold, revenue
FROM   ranked
WHERE  rank_in_category <= 3
ORDER BY category, rank_in_category;
