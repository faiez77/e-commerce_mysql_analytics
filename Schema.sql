-- ============================================================
-- E-Commerce Sales & Customer Analytics — Schema
-- Target: MySQL 8.0+ (uses window functions)
-- ============================================================

CREATE DATABASE ecommerce_analytics;
USE ecommerce_analytics;

CREATE TABLE customers (
    customer_id     INT PRIMARY KEY,
    customer_name   VARCHAR(100) NOT NULL,
    city            VARCHAR(50),
    state           VARCHAR(50),
    signup_date     DATE NOT NULL
);

CREATE TABLE products (
    product_id      INT PRIMARY KEY,
    product_name    VARCHAR(100) NOT NULL,
    category        VARCHAR(50) NOT NULL,
    price           DECIMAL(10,2) NOT NULL
);

CREATE TABLE orders (
    order_id        INT PRIMARY KEY,
    customer_id     INT NOT NULL,
    order_date      DATE NOT NULL,
    order_status    ENUM('Delivered','Shipped','Canceled','Processing','Invoiced','Unavailable','Approved','Created') NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE order_items (
    order_item_id   INT PRIMARY KEY,
    order_id        INT NOT NULL,
    product_id      INT NOT NULL,
    quantity        INT NOT NULL,
    unit_price      DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE TABLE payments (
    payment_id      INT PRIMARY KEY,
    order_id        INT NOT NULL,
    payment_type    VARCHAR(30) NOT NULL,
    payment_value   DECIMAL(10,2) NOT NULL,
    installments    INT DEFAULT 1,
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

CREATE TABLE reviews (
    review_id       INT PRIMARY KEY,
    order_id        INT NOT NULL,
    review_score    TINYINT NOT NULL CHECK (review_score BETWEEN 1 AND 5),
    review_date     DATE NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

-- Helpful indexes for analytical queries
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_date ON orders(order_date);
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_product ON order_items(product_id);
CREATE INDEX idx_payments_order ON payments(order_id);
CREATE INDEX idx_reviews_order ON reviews(order_id);
