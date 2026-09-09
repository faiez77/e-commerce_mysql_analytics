# 📊 E-Commerce Sales & Customer Analytics (MySQL)

End-to-end SQL analytics project on **real e-commerce transactional data** — from schema design through business-ready insights. Built to answer the questions a real analytics/BI team would ask: revenue trends, product performance, customer value, and churn risk.

## Objective

Analyze transactional e-commerce data in MySQL to answer:

- How is monthly revenue trending, and what's the month-over-month growth?
- Which products/categories drive the most revenue?
- Who are the most valuable customers (CLV), and how do they segment (RFM)?
- Which customers are at risk of churn?
- Does payment method affect order value, and how do review scores vary by category?

## Project Structure

```
├── sql/
│   ├── schema.sql               # DDL: tables, keys, indexes, constraints
│   └── load_data.sql            # LOAD DATA INFILE script
├── scripts/
│   └── map_olist_data.py        # Maps the real Olist dataset into this schema
├── data/                        # Generated CSVs (customers, products, orders,
│                                 # order_items, payments, reviews)
├── screenshots/                 # MySQL Workbench output — see insights.md
├── analysis_queries.sql         # All 12 analysis queries
├── insights.md                  # Business findings + verified run results
└── README.md
```

## Tech Stack

`MySQL 8.0+` · `SQL (Window Functions, CTEs, Subqueries)` · `Python / pandas (data mapping)`

## Dataset

Built from the real, public **[Olist Brazilian E-Commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)** (~100K orders, 2016–2018), sampled down to a ~10,000-order window (Jan 2017 – Aug 2018) and mapped into a clean 6-table schema. See [`scripts/map_olist_data.py`](scripts/map_olist_data.py) for the full mapping logic.

**A real data-modeling detail worth knowing:** Olist's raw `customers` table has a `customer_id` that's actually one-per-**order**, not one per person — the true recurring customer is `customer_unique_id`. This project uses `customer_unique_id` as the customer key, which is the correct approach (a lot of tutorials get this wrong, which silently breaks repeat-purchase and RFM analysis).

**A sampling bug I caught and fixed:** the first version of the sampling logic drew 10,000 *individual orders* uniformly at random. That silently destroys repeat-purchase signal — for a repeat customer to appear as "repeat" in a ~10% random order sample, every one of their orders has to independently survive the draw. That version measured a 0.34% repeat-purchase rate; the true rate in the full dataset is ~3.1%. The fix samples by **customer** instead (keeping each sampled customer's full order history intact), which — after also avoiding an intermediate overcorrection that *over*-represented repeat customers — now reproduces the true population repeat rate almost exactly (~2.9% sample vs. ~3.1% population). Full writeup in [`insights.md`](insights.md).

Two fields are reasonable synthesized proxies, disclosed for transparency:

- `product_name` — Olist only provides a product *category*, not a display name, so names are generated from category + product id.
- `customer.signup_date` — approximated as each customer's first order date in the sample (Olist has no registration date).

## Schema

Six normalized tables: `customers`, `products`, `orders`, `order_items`, `payments`, `reviews`.
See [`schema.sql`](schema.sql) for full DDL with foreign keys.

## How to Run

1. `mysql -u root -p < sql/schema.sql` — creates the database and tables
2. Find your server's allowed import folder: `SHOW VARIABLES LIKE 'secure_file_priv';`
3. Copy all 6 CSVs from this project's `data/` folder directly into that folder
4. `mysql -u root -p < sql/load_data.sql` — loads the CSVs (see comments at the top of the file for details)
5. Run queries from `analysis_queries.sql` individually, or via Workbench

## Analysis Performed

| #  | Question                         | Technique                |
| --- | -------------------------------- | ------------------------ |
| 1  | Monthly revenue trend            | `GROUP BY`, aggregate    |
| 2  | Month-over-month growth %        | `LAG()` window function  |
| 3  | Top products by revenue          | `RANK()` window function |
| 4  | Top categories by revenue share  | Window `SUM() OVER ()`   |
| 5  | RFM customer segmentation        | `NTILE(5)`, CTEs, `CASE` |
| 6  | Customer Lifetime Value          | Aggregate + `RANK()`     |
| 7  | Churn risk (90-day inactivity)   | `DATEDIFF`, CTEs         |
| 8  | Repeat purchase rate             | Conditional aggregation  |
| 9  | Payment method analysis          | `GROUP BY` aggregate     |
| 10 | Review score by category         | Multi-table joins        |
| 11 | Order status / cancellation rate | `GROUP BY` aggregate     |
| 12 | Cumulative revenue               | Running `SUM() OVER()`   |

Full queries: [`analysis_queries.sql`](analysis_queries.sql)

## Key Insights

See [`insights.md`](insights.md) for real findings from this dataset — including the sampling-bug story above (now verified end-to-end: the corrected repeat-purchase rate of 2.91%, confirmed by direct query against the loaded MySQL database, matches the true population rate almost exactly) — plus screenshots of the actual query output. That kind of catch-and-correct story is genuinely worth walking through in an interview: it's a concrete example of validating your own work rather than trusting the first number you compute.

## Author

Faiez — final-year engineering student, IIT Indore.
