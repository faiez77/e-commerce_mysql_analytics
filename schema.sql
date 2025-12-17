CREATE  DATABASE sales_analytics;
USE sales_analytics;

CREATE TABLE customers (
  customer_id INT PRIMARY KEY,
  customer_name VARCHAR(50),
  city VARCHAR(50),
  state VARCHAR(50),
  signup_date DATE
);

CREATE TABLE products (
  product_id INT PRIMARY KEY,
  product_name VARCHAR(50),
  category VARCHAR(50),
  price INT
);
CREATE TABLE orders (
  order_id INT PRIMARY KEY,
  customer_id INT,
  order_date DATE,
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE order_items (
  order_item_id INT PRIMARY KEY,
  order_id INT,
  product_id INT,
  quantity INT,
  FOREIGN KEY (order_id) REFERENCES orders(order_id),
  FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- sample data

INSERT INTO customers VALUES
(1, 'Amit Sharma', 'Indore', 'MP', '2023-01-10'),                                                      
(2, 'Neha Verma', 'Bhopal', 'MP', '2023-02-15'),                                       
(3, 'Rahul Singh', 'Delhi', 'Delhi', '2023-03-05'),                                                
(4, 'Priya Mehta', 'Mumbai', 'MH', '2023-03-20');

INSERT INTO products VALUES
(101, 'iPhone 13', 'Mobile', 60000),
(102, 'Samsung S21', 'Mobile', 50000),
(103, 'OnePlus Nord', 'Mobile', 30000),
(104, 'Dell Laptop', 'Laptop', 70000),
(105, 'HP Laptop', 'Laptop', 65000);

INSERT INTO orders VALUES
(1001, 1, '2023-06-10'),
(1002, 2, '2023-06-15'),
(1003, 3, '2023-07-05'),
(1004, 1, '2023-07-20'),
(1005, 4, '2023-08-10');

INSERT INTO order_items VALUES
(1, 1001, 101, 1),
(2, 1001, 103, 2),
(3, 1002, 102, 1),
(4, 1003, 104, 1),
(5, 1004, 103, 1),
(6, 1004, 105, 1),
(7, 1005, 101, 1);

(select * from orders o   JOIN order_items oi ON o.order_id = oi.order_id  
                          JOIN products p ON oi.product_id = p.product_id;

  
)
-- Monthly Revenue
SELECT 
  DATE_FORMAT(o.order_date, '%Y-%m') AS month,
   SUM(p.price * oi.quantity) AS revenue
FROM orders o
 JOIN order_items oi ON o.order_id = oi.order_id
 JOIN products p ON oi.product_id = p.product_id
 GROUP BY month
 ORDER BY month;

--  Month-over-Month Sales Growth[Are sales increasing or decreasing? = MOM]

 -- first we making view to reuse previous as table 
CREATE VIEW monthly_sale AS
SELECT 
  DATE_FORMAT(o.order_date, '%Y-%m') AS month,
  SUM(p.price * oi.quantity) AS revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
 GROUP BY month;

-- using window function lag for previous month column
SELECT month , revenue,
  LAG(revenue) OVER (ORDER BY month) AS prev_month_revenue 
  FROM monthly_sale;
 SELECT   month,  revenue, prev_month_revenue,
  ROUND(
    (revenue - prev_month_revenue) * 100 / prev_month_revenue,
    2
  ) AS mom_growth_percent
FROM (
  SELECT
    month,
    revenue,
    LAG(revenue) OVER (ORDER BY month) AS prev_month_revenue
  FROM monthly_sale
) t;

-- top 3 product by revenue [which product perform best every month ]
SELECT *
FROM ( 
   SELECT 
    DATE_FORMAT(o.order_date, '%Y-%m') AS month,
    p.category,
    p.product_name, 
    SUM(p.price * oi.quantity) AS revenue,
    dense_rank() OVER (
      PARTITION BY DATE_FORMAT(o.order_date, '%Y-%m')
      ORDER BY SUM(p.price * oi.quantity) DESC
    ) AS top_rnk
  FROM orders o
  JOIN order_items oi ON o.order_id = oi.order_id
  JOIN products p ON oi.product_id = p.product_id
  GROUP BY month, p.product_name , p.category
) s
WHERE top_rnk <= 3;

-- Customer lifetime value(CLV)
SELECT
  c.customer_name,
  SUM(p.price * oi.quantity) AS lifetime_value
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
GROUP BY c.customer_name
ORDER BY lifetime_value DESC;

 --  Customer segmentation
  SELECT
  customer_name,
  total_spent,
  CASE
    WHEN customer_segment = 1 THEN 'High Value'
    WHEN customer_segment = 2 THEN 'Mid Value'
    WHEN customer_segment = 3 THEN 'Low Value'
  END AS customer_category
FROM (
  SELECT
    c.customer_name,
    SUM(p.price * oi.quantity) AS total_spent,
    NTILE(3) OVER (ORDER BY SUM(p.price * oi.quantity) DESC) AS customer_segment
  FROM customers c
  JOIN orders o ON c.customer_id = o.customer_id
  JOIN order_items oi ON o.order_id = oi.order_id
  JOIN products p ON oi.product_id = p.product_id
  GROUP BY c.customer_name
) a;

