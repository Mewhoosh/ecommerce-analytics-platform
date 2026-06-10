-- Business question: which product categories drive the most revenue?
-- LEFT JOIN to translation: some categories have no English name.
-- COALESCE picks first non-null label so unmapped categories still show up.

SELECT
    COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
    COUNT(DISTINCT o.order_id)                  AS orders,
    COUNT(*)                                    AS items_sold,
    SUM(oi.price + oi.freight_value)            AS revenue,
    ROUND(AVG(oi.price + oi.freight_value), 2)  AS avg_item_value
FROM   orders o
JOIN   order_items oi ON oi.order_id = o.order_id
JOIN   products   p   ON p.product_id = oi.product_id
LEFT JOIN product_category_translation t
                      ON t.product_category_name = p.product_category_name
WHERE  o.order_status = 'delivered'
GROUP BY 1
ORDER BY revenue DESC;
