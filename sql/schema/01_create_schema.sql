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


-- Grain: one row = one Portuguese -> English category mapping.
-- Soft lookup (no FK from products): translation does not cover every category.
CREATE TABLE product_category_translation (
    product_category_name         VARCHAR(50)  PRIMARY KEY,
    product_category_name_english VARCHAR(50)  NOT NULL
);


-- Grain: one row = one product.
-- 610 products have no category/metadata in source data (kept as NULL).
CREATE TABLE products (
    product_id                 VARCHAR(32)   PRIMARY KEY,
    product_category_name      VARCHAR(50),               -- 610 NULLs in source
    product_name_length        SMALLINT,                  -- char count of product name
    product_description_length INTEGER,                   -- can exceed SMALLINT range
    product_photos_qty         SMALLINT,
    product_weight_g           INTEGER       CHECK (product_weight_g >= 0),
    product_length_cm          SMALLINT      CHECK (product_length_cm >= 0),
    product_height_cm          SMALLINT      CHECK (product_height_cm >= 0),
    product_width_cm           SMALLINT      CHECK (product_width_cm >= 0)
);

CREATE INDEX idx_products_category ON products(product_category_name);


-- Grain: one row = one seller. Mirror of customers structure.
CREATE TABLE sellers (
    seller_id              VARCHAR(32)  PRIMARY KEY,
    seller_zip_code_prefix VARCHAR(5)   NOT NULL,
    seller_city            VARCHAR(50)  NOT NULL,
    seller_state           CHAR(2)      NOT NULL
);


-- Grain: one row = one review attached to one order.
-- review_id alone is NOT unique (814 reviews cover multiple orders) — composite PK.
CREATE TABLE order_reviews (
    review_id              VARCHAR(32)  NOT NULL,
    order_id               VARCHAR(32)  NOT NULL REFERENCES orders(order_id),
    review_score           SMALLINT     NOT NULL CHECK (review_score BETWEEN 1 AND 5),
    review_comment_title   VARCHAR(100),                  -- 88% NULL in source
    review_comment_message TEXT,                          -- 58% NULL, can be long
    review_creation_date   TIMESTAMPTZ  NOT NULL,
    review_answer_timestamp TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (review_id, order_id)
);

CREATE INDEX idx_order_reviews_order_id ON order_reviews(order_id);
CREATE INDEX idx_order_reviews_score    ON order_reviews(review_score);

-- Grain: one row = one payment for an order.
-- One order can have multiple payments (card + voucher, two installments, etc.).
CREATE TABLE order_payments (
    order_id             VARCHAR(32)    NOT NULL REFERENCES orders(order_id),
    payment_sequential   SMALLINT       NOT NULL,
    payment_type         VARCHAR(20)    NOT NULL
                         CHECK (payment_type IN (
                             'credit_card', 'boleto', 'voucher',
                             'debit_card', 'not_defined'
                         )),
    payment_installments SMALLINT       NOT NULL CHECK (payment_installments >= 0),
    payment_value        DECIMAL(10,2)  NOT NULL CHECK (payment_value >= 0),
    PRIMARY KEY (order_id, payment_sequential)
);

CREATE INDEX idx_order_payments_type ON order_payments(payment_type);
-- No extra index for order_id — it's the leftmost column of the composite PK.