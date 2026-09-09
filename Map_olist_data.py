"""
Maps the real Olist Brazilian E-Commerce public dataset into the
project's schema (customers, products, orders, order_items, payments,
reviews), trimmed to a medium-sized sample (~10,000 orders).

Key real-world data modeling decision:
  Olist's `customers` table has a `customer_id` that is actually
  ONE-PER-ORDER, not one per person. 
   We use customer_unique_id as our customer key
  
Fields synthesized because the real dataset doesn't contain them:
  - product_name: Olist only provides a product CATEGORY, not a
    display name. We generate a readable name from category + a
    short id suffix, clearly not a real product title.
  - customer signup_date: Olist has no signup/registration date.
    We approximate it as the customer's first order date (a common,
    reasonable proxy, but disclosed here as an approximation).

"""
import pandas as pd
import numpy as np
from pathlib import Path

RAW = Path("/home/claude/olist_raw")
OUT = Path("/home/claude/ecommerce_project/data")
OUT.mkdir(parents=True, exist_ok=True)

rng = np.random.default_rng(42)

# ---------- load raw ----------
orders_raw = pd.read_csv(RAW / "olist_orders_dataset.csv", parse_dates=["order_purchase_timestamp"])
customers_raw = pd.read_csv(RAW / "olist_customers_dataset.csv")
items_raw = pd.read_csv(RAW / "olist_order_items_dataset.csv")
payments_raw = pd.read_csv(RAW / "olist_order_payments_dataset.csv")
reviews_raw = pd.read_csv(RAW / "olist_order_reviews_dataset.csv")
products_raw = pd.read_csv(RAW / "olist_products_dataset.csv")
cat_translation = pd.read_csv(RAW / "product_category_name_translation.csv")

# ---------- sample ~10,000 orders from the well-populated window ----------
WINDOW_START, WINDOW_END = "2017-01-01", "2018-08-31"
window_orders = orders_raw[
    (orders_raw.order_purchase_timestamp >= WINDOW_START) &
    (orders_raw.order_purchase_timestamp <= WINDOW_END)
].copy()

N_ORDERS_TARGET = 10000
sampled_orders = window_orders.sample(n=N_ORDERS_TARGET, random_state=42).copy()

# ---------- customers: map to true unique person, sequential int id ----------
sampled_orders = sampled_orders.merge(
    customers_raw[["customer_id", "customer_unique_id", "customer_city", "customer_state"]],
    on="customer_id", how="left"
)

unique_customers = sampled_orders["customer_unique_id"].unique()
cust_id_map = {u: i + 1 for i, u in enumerate(unique_customers)}
sampled_orders["mapped_customer_id"] = sampled_orders["customer_unique_id"].map(cust_id_map)

# signup_date approximated as first purchase date for that customer within the sample
first_purchase = sampled_orders.groupby("mapped_customer_id").order_purchase_timestamp.min()

customers_out = (
    sampled_orders.drop_duplicates("mapped_customer_id")
    .assign(
        customer_id=lambda d: d.mapped_customer_id,
        customer_name=lambda d: "Customer #" + d.mapped_customer_id.astype(str),  # anonymized, no real names in source
        city=lambda d: d.customer_city.str.title(),
        state=lambda d: d.customer_state,
    )
    .set_index("mapped_customer_id")
)
customers_out["signup_date"] = first_purchase
customers_out = customers_out.reset_index(drop=True)[
    ["customer_id", "customer_name", "city", "state", "signup_date"]
].sort_values("customer_id")
customers_out["signup_date"] = customers_out["signup_date"].dt.date.astype(str)

# ---------- orders ----------
orders_out = sampled_orders[["order_id", "mapped_customer_id", "order_purchase_timestamp", "order_status"]].copy()
orders_out.columns = ["order_id", "customer_id", "order_date", "order_status"]
orders_out["order_date"] = orders_out["order_date"].dt.date.astype(str)
order_id_map = {oid: i + 1 for i, oid in enumerate(orders_out["order_id"].unique())}
orders_out["order_id"] = orders_out["order_id"].map(order_id_map)
orders_out = orders_out.sort_values("order_id")

# ---------- order_items ----------
items_sample = items_raw[items_raw.order_id.isin(order_id_map.keys())].copy()
items_sample["order_id"] = items_sample["order_id"].map(order_id_map)

products_used = products_raw[products_raw.product_id.isin(items_sample.product_id.unique())].copy()
products_used = products_used.merge(cat_translation, on="product_category_name", how="left")
products_used["product_category_name_english"] = products_used["product_category_name_english"].fillna(
    products_used["product_category_name"]
).fillna("uncategorized")
product_id_map = {pid: i + 1 for i, pid in enumerate(products_used["product_id"].unique())}
products_used["mapped_product_id"] = products_used["product_id"].map(product_id_map)

items_sample["mapped_product_id"] = items_sample["product_id"].map(product_id_map)
items_sample = items_sample.dropna(subset=["mapped_product_id"])
items_sample["mapped_product_id"] = items_sample["mapped_product_id"].astype(int)

order_items_out = items_sample[["order_id", "mapped_product_id", "price"]].reset_index(drop=True).copy()
order_items_out.insert(0, "order_item_id", range(1, len(order_items_out) + 1))
order_items_out["quantity"] = 1  # Olist stores one row per unit; qty is implicitly 1 per line
order_items_out.columns = ["order_item_id", "order_id", "product_id", "unit_price", "quantity"]
order_items_out = order_items_out[["order_item_id", "order_id", "product_id", "quantity", "unit_price"]]

# ---------- products ----------
def clean_cat(c):
    return str(c).replace("_", " ").title()

products_out = products_used.copy()
products_out["category"] = products_out["product_category_name_english"].apply(clean_cat)
products_out["product_name"] = products_out.apply(
    lambda r: f"{clean_cat(r['product_category_name_english'])} Item #{r['product_id'][:6]}", axis=1
)
# price = average selling price observed for that product in the sample
avg_price = items_sample.groupby("mapped_product_id").price.mean()
products_out["mapped_product_id"] = products_out["product_id"].map(product_id_map)
products_out["price"] = products_out["mapped_product_id"].map(avg_price).round(2)
products_out = products_out.dropna(subset=["price"])
products_out = products_out[["mapped_product_id", "product_name", "category", "price"]].copy()
products_out.columns = ["product_id", "product_name", "category", "price"]
products_out = products_out.sort_values("product_id")

# ---------- payments (aggregate multi-row splits into one row per order) ----------
payments_sample = payments_raw[payments_raw.order_id.isin(order_id_map.keys())].copy()
payments_sample["order_id"] = payments_sample["order_id"].map(order_id_map)
# dominant payment_type = the one with the highest value on that order
idx = payments_sample.groupby("order_id")["payment_value"].idxmax()
dominant_type = payments_sample.loc[idx, ["order_id", "payment_type"]]
agg = payments_sample.groupby("order_id").agg(
    payment_value=("payment_value", "sum"),
    installments=("payment_installments", "max"),
).reset_index()
payments_out = agg.merge(dominant_type, on="order_id")
payments_out["payment_id"] = payments_out["order_id"]
payments_out["payment_type"] = payments_out["payment_type"].str.replace("_", " ").str.title()
payments_out = payments_out[["payment_id", "order_id", "payment_type", "payment_value", "installments"]]
payments_out["payment_value"] = payments_out["payment_value"].round(2)

# ---------- reviews ----------
reviews_sample = reviews_raw[reviews_raw.order_id.isin(order_id_map.keys())].copy()
reviews_sample["order_id"] = reviews_sample["order_id"].map(order_id_map)
reviews_sample = reviews_sample.dropna(subset=["order_id"])
reviews_sample["order_id"] = reviews_sample["order_id"].astype(int)
reviews_sample = reviews_sample.drop_duplicates(subset=["order_id"])  # 1 review per order for our schema
reviews_out = reviews_sample[["order_id", "review_score", "review_creation_date"]].reset_index(drop=True).copy()
reviews_out.insert(0, "review_id", range(1, len(reviews_out) + 1))
reviews_out["review_date"] = pd.to_datetime(reviews_out["review_creation_date"]).dt.date.astype(str)
reviews_out = reviews_out[["review_id", "order_id", "review_score", "review_date"]]

# also fix order_status casing to match a clean readable ENUM set, keep real values
orders_out["order_status"] = orders_out["order_status"].str.title()

# ---------- write ----------
customers_out.to_csv(OUT / "customers.csv", index=False)
products_out.to_csv(OUT / "products.csv", index=False)
orders_out.to_csv(OUT / "orders.csv", index=False)
order_items_out.to_csv(OUT / "order_items.csv", index=False)
payments_out.to_csv(OUT / "payments.csv", index=False)
reviews_out.to_csv(OUT / "reviews.csv", index=False)

print("customers   :", len(customers_out))
print("products    :", len(products_out))
print("orders      :", len(orders_out))
print("order_items :", len(order_items_out))
print("payments    :", len(payments_out))
print("reviews     :", len(reviews_out))
print("\norder_status values:", orders_out.order_status.unique())
print("payment_type values:", payments_out.payment_type.unique())
print("category count:", products_out.category.nunique())
