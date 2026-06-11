-- Additional views for Products and Operations dashboard pages.


-- Revenue and volume per product category (delivered only).
-- Left join to translation so non-mapped categories ('unknown') still show.
CREATE OR REPLACE VIEW vw_category_performance AS
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
GROUP BY 1;


-- Per-seller revenue and volume (delivered only).
CREATE OR REPLACE VIEW vw_seller_performance AS
SELECT
    s.seller_id,
    s.seller_state,
    s.seller_city,
    COUNT(DISTINCT oi.order_id)        AS orders,
    COUNT(*)                           AS items_sold,
    SUM(oi.price + oi.freight_value)   AS revenue
FROM   sellers s
JOIN   order_items oi ON oi.seller_id = s.seller_id
JOIN   orders o       ON o.order_id   = oi.order_id
WHERE  o.order_status = 'delivered'
GROUP BY s.seller_id, s.seller_state, s.seller_city;


-- Payment method breakdown.
CREATE OR REPLACE VIEW vw_payments_summary AS
SELECT
    op.payment_type,
    COUNT(*)                                       AS payments_count,
    COUNT(DISTINCT op.order_id)                    AS orders_count,
    SUM(op.payment_value)                          AS total_value,
    ROUND(AVG(op.payment_value), 2)                AS avg_value,
    ROUND(AVG(op.payment_installments::numeric), 2) AS avg_installments
FROM   order_payments op
JOIN   orders o ON o.order_id = op.order_id
WHERE  o.order_status = 'delivered'
GROUP BY op.payment_type;


-- One row per delivered order with delivery timing metrics.
-- Powers the delivery time histogram and on-time trend.
CREATE OR REPLACE VIEW vw_delivery_times AS
SELECT
    o.order_id,
    DATE_TRUNC('month', o.order_purchase_timestamp)::date AS purchase_month,
    c.customer_state,
    (o.order_delivered_customer_date::date
     - o.order_purchase_timestamp::date)             AS delivery_days,
    (o.order_delivered_customer_date::date
     - o.order_estimated_delivery_date::date)        AS delay_vs_estimated,
    CASE WHEN o.order_delivered_customer_date::date
              <= o.order_estimated_delivery_date::date
         THEN 1 ELSE 0 END                           AS is_on_time
FROM   orders o
JOIN   customers c ON c.customer_id = o.customer_id
WHERE  o.order_status = 'delivered'
  AND  o.order_delivered_customer_date IS NOT NULL;
