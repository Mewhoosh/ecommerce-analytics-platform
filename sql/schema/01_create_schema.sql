-- E-commerce Analytics Platform — schema
-- Source: Brazilian E-Commerce dataset by Olist (Kaggle)
-- Tables created in dependency order (parents before children).


-- Grain: one row = a customer in the context of a single order.
-- The same person placing multiple orders has multiple customer_id values
-- but the same customer_unique_id. Use customer_unique_id for CLV/retention.
CREATE TABLE customers (
    customer_id              VARCHAR(32)  PRIMARY KEY,
    customer_unique_id       VARCHAR(32)  NOT NULL,
    customer_zip_code_prefix VARCHAR(5)   NOT NULL,  -- VARCHAR to keep leading zeros (e.g. "01151")
    customer_city            VARCHAR(50)  NOT NULL,
    customer_state           CHAR(2)      NOT NULL
);

CREATE INDEX idx_customers_unique_id ON customers(customer_unique_id);


-- Grain: one row = one order.
CREATE TABLE orders (
    order_id                      VARCHAR(32)  PRIMARY KEY,
    customer_id                   VARCHAR(32)  NOT NULL REFERENCES customers(customer_id),

    order_status                  VARCHAR(20)  NOT NULL
                                  CHECK (order_status IN (
                                      'delivered', 'shipped', 'canceled',
                                      'unavailable', 'invoiced', 'processing',
                                      'created', 'approved'
                                  )),

    -- TIMESTAMPTZ stores UTC internally — production-safe default.
    order_purchase_timestamp      TIMESTAMPTZ  NOT NULL,
    order_approved_at             TIMESTAMPTZ,           -- null when never approved (e.g. canceled)
    order_delivered_carrier_date  TIMESTAMPTZ,           -- null when never shipped
    order_delivered_customer_date TIMESTAMPTZ,           -- null while in transit
    order_estimated_delivery_date TIMESTAMPTZ  NOT NULL  -- assigned at purchase time
);

CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_purchase_ts ON orders(order_purchase_timestamp);
CREATE INDEX idx_orders_status      ON orders(order_status);
