-- ============================================================
-- E-Commerce Sales & Customer Analytics — Analysis Queries
-- MySQL 8.0+ (window functions, CTEs)
-- ============================================================
USE ecommerce_analytics;

-- ------------------------------------------------------------
-- 1. Monthly Revenue Trend
-- ------------------------------------------------------------
SELECT
    DATE_FORMAT(o.order_date, '%Y-%m') AS order_month,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS monthly_revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status <> 'Canceled'
GROUP BY order_month
ORDER BY order_month;

-- ------------------------------------------------------------
-- 2. Month-over-Month (MoM) Revenue Growth %
-- ------------------------------------------------------------
WITH monthly_revenue AS (
    SELECT
        DATE_FORMAT(o.order_date, '%Y-%m') AS order_month,
        SUM(oi.quantity * oi.unit_price) AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status <> 'Canceled'
    GROUP BY order_month
)
SELECT
    order_month,
    ROUND(revenue, 2) AS revenue,
    ROUND(LAG(revenue) OVER (ORDER BY order_month), 2) AS prev_month_revenue,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY order_month))
        / LAG(revenue) OVER (ORDER BY order_month) * 100, 2
    ) AS mom_growth_pct
FROM monthly_revenue
ORDER BY order_month;

-- ------------------------------------------------------------
-- 3. Top Products by Revenue
-- ------------------------------------------------------------
SELECT
    p.product_name,
    p.category,
    SUM(oi.quantity) AS units_sold,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS total_revenue,
    RANK() OVER (ORDER BY SUM(oi.quantity * oi.unit_price) DESC) AS revenue_rank
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
JOIN orders o ON o.order_id = oi.order_id
WHERE o.order_status <> 'Canceled'
GROUP BY p.product_id, p.product_name, p.category
ORDER BY total_revenue DESC
LIMIT 10;

-- ------------------------------------------------------------
-- 4. Top Categories by Revenue (with % of total)
-- ------------------------------------------------------------
WITH category_revenue AS (
    SELECT
        p.category,
        SUM(oi.quantity * oi.unit_price) AS revenue
    FROM order_items oi
    JOIN products p ON p.product_id = oi.product_id
    JOIN orders o ON o.order_id = oi.order_id
    WHERE o.order_status <> 'Canceled'
    GROUP BY p.category
)
SELECT
    category,
    ROUND(revenue, 2) AS revenue,
    ROUND(revenue / SUM(revenue) OVER () * 100, 2) AS pct_of_total_revenue,
    RANK() OVER (ORDER BY revenue DESC) AS category_rank
FROM category_revenue
ORDER BY revenue DESC;

-- ------------------------------------------------------------
-- 5. RFM Segmentation (Recency, Frequency, Monetary)
--    Scored 1-5 per metric via NTILE, combined into a segment
-- ------------------------------------------------------------
WITH customer_orders AS (
    SELECT
        c.customer_id,
        c.customer_name,
        DATEDIFF((SELECT MAX(order_date) FROM orders), MAX(o.order_date)) AS recency_days,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(oi.quantity * oi.unit_price) AS monetary
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status <> 'Canceled'
    GROUP BY c.customer_id, c.customer_name
),
rfm_scores AS (
    SELECT
        *,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,   -- lower recency_days = more recent = higher score
        NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
    FROM customer_orders
)
SELECT
    customer_id,
    customer_name,
    recency_days,
    frequency,
    ROUND(monetary, 2) AS monetary,
    r_score, f_score, m_score,
    (r_score + f_score + m_score) AS rfm_total,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'New / Promising'
        WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 THEN 'Churned / Lost'
        ELSE 'Needs Attention'
    END AS customer_segment
FROM rfm_scores
ORDER BY rfm_total DESC;

-- ------------------------------------------------------------
-- 6. Customer Lifetime Value (CLV) — total historical revenue
--    per customer, ranked
-- ------------------------------------------------------------
SELECT
    c.customer_id,
    c.customer_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS lifetime_value,
    ROUND(SUM(oi.quantity * oi.unit_price) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value,
    RANK() OVER (ORDER BY SUM(oi.quantity * oi.unit_price) DESC) AS clv_rank
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status <> 'Canceled'
GROUP BY c.customer_id, c.customer_name
ORDER BY lifetime_value DESC
LIMIT 20;

-- ------------------------------------------------------------
-- 7. Churn Risk — customers with no order in the last 90 days
--    (relative to the most recent order date in the dataset)
-- ------------------------------------------------------------
WITH last_order AS (
    SELECT customer_id, MAX(order_date) AS last_order_date
    FROM orders
    GROUP BY customer_id
),
dataset_max_date AS (
    SELECT MAX(order_date) AS max_date FROM orders
)
SELECT
    c.customer_id,
    c.customer_name,
    lo.last_order_date,
    DATEDIFF(dm.max_date, lo.last_order_date) AS days_since_last_order
FROM customers c
JOIN last_order lo ON lo.customer_id = c.customer_id
CROSS JOIN dataset_max_date dm
WHERE DATEDIFF(dm.max_date, lo.last_order_date) > 90
ORDER BY days_since_last_order DESC;

-- ------------------------------------------------------------
-- 8. Repeat Purchase Rate
-- ------------------------------------------------------------
WITH order_counts AS (
    SELECT customer_id, COUNT(*) AS n_orders
    FROM orders
    WHERE order_status <> 'Canceled'
    GROUP BY customer_id
)
SELECT
    COUNT(*) AS total_customers_with_orders,
    SUM(CASE WHEN n_orders > 1 THEN 1 ELSE 0 END) AS repeat_customers,
    ROUND(SUM(CASE WHEN n_orders > 1 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS repeat_purchase_rate_pct
FROM order_counts;

-- ------------------------------------------------------------
-- 9. Payment Method Preference & Avg Order Value by Method
-- ------------------------------------------------------------
SELECT
    payment_type,
    COUNT(*) AS num_orders,
    ROUND(AVG(payment_value), 2) AS avg_order_value,
    ROUND(SUM(payment_value), 2) AS total_value
FROM payments
GROUP BY payment_type
ORDER BY total_value DESC;

-- ------------------------------------------------------------
-- 10. Customer Satisfaction — Avg Review Score by Category
-- ------------------------------------------------------------
SELECT
    p.category,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    COUNT(r.review_id) AS num_reviews
FROM reviews r
JOIN orders o ON o.order_id = r.order_id
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p ON p.product_id = oi.product_id
GROUP BY p.category
ORDER BY avg_review_score DESC;

-- ------------------------------------------------------------
-- 11. Order Status Breakdown (cancellation / return rate)
-- ------------------------------------------------------------
SELECT
    order_status,
    COUNT(*) AS num_orders,
    ROUND(COUNT(*) / (SELECT COUNT(*) FROM orders) * 100, 2) AS pct_of_orders
FROM orders
GROUP BY order_status
ORDER BY num_orders DESC;

-- ------------------------------------------------------------
-- 12. Running Cumulative Revenue (window function demo)
-- ------------------------------------------------------------
WITH monthly_revenue AS (
    SELECT
        DATE_FORMAT(o.order_date, '%Y-%m') AS order_month,
        SUM(oi.quantity * oi.unit_price) AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status <> 'Canceled'
    GROUP BY order_month
)
SELECT
    order_month,
    ROUND(revenue, 2) AS revenue,
    ROUND(SUM(revenue) OVER (ORDER BY order_month), 2) AS cumulative_revenue
FROM monthly_revenue
ORDER BY order_month;
