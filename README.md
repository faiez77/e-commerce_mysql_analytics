🎯 Project Title :  📊 E‑Commerce Sales & Customer Analytics using MySQL

🎯 Project Objective

The objective of this project is to use MySQL to analyze transactional e‑commerce data and extract meaningful business insights such as:

Monthly revenue trends

Month‑over‑month (MoM) growth

Customer Lifetime Value (CLV)

Top‑performing products and categories

Customer Segmentation Using RFM analysis 
[
RFM analysis means :

| Metric            | Meaning                         | Business Insight |
| ----------------- | ------------------------------- | ---------------- |
| R – Recency       | How recently customer purchased | Engagement       |
| F – Frequency     | How often customer purchased    | Loyalty          |
| M – Monetary      | How much customer spent         | Value            |

]

## Business Questions Answered
- How is monthly revenue trending?
- What is the month-over-month sales growth?
- Which products and categories generate the most revenue?
- Who are the most valuable customers?
- Which customers are at risk of churn?

The goal is to convert raw transactional data into decision‑ready insights.

🔹 Dataset Description

The data is synthetic (sample data) but modeled after real production schemas.


Tables Used

⿡ customers

column	description:
customer_id	Unique customer identifier
customer_name	Customer name
signup_date	Registration date

⿢ orders

column	description:
order_id	Unique order ID
customer_id	Customer placing the order
order_date	Order date

⿣ order_items

column	description:
order_id	Order reference
product_id	Product purchased
quantity	Units purchased

⿤ products

column	description:
product_id	Product ID
product_name	Product name
category	Product category
price	Unit price


Note: We are using window function which is compatible with MYSQL 8.0+ and MYSQL workbench only.



