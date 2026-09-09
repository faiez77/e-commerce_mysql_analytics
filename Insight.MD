# Key Insights

*Computed directly from this project's dataset: a ~10,000-order sample
(Jan 2017 – Aug 2018) mapped from the real, public **Olist Brazilian
E-Commerce dataset** into this project's schema — see
[`map_olist_data.py`](map_olist_data.py). Currency is BRL (Brazilian
Real), matching the source data.*

1. **Revenue grew substantially over the sample window**, from
   ~R$9,100 (Jan 2017 — a partial ramp-up month) to a later peak
   around R$101K, with an average month-over-month growth rate of
   ~19% — consistent with Olist's real, well-documented growth phase
   as a marketplace during this period. Growth is not smooth
   month-to-month (some months show double-digit declines), which is
   realistic for real transactional data.

2. **Watches & Gifts, Health & Beauty, and Bed/Bath/Table are the top
   3 categories**, together contributing ~26% of revenue — a fairly
   flat distribution with no single category dominating, typical of a
   real multi-category marketplace.

3. **The corrected repeat-purchase rate is ~2.9%** (280 of 9,625
   customers with a non-canceled order placed more than one). This
   matches the known true population rate (~3.1%) closely, confirming
   the sampling fix worked. It's still a genuinely low repeat rate —
   Olist really is acquisition-heavy, low-repeat marketplace data —
   just not as extreme as the original (buggy) 0.34% figure suggested.

4. **The top 10% of customers by spend account for ~41.6% of
   revenue**, despite the low repeat rate — driven by order value
   variance (some customers place large or multi-item orders in a
   single visit), not repeat frequency. A good example of "value
   concentration without loyalty."

5. **97.1% of orders were delivered successfully**; canceled orders
   were under 1% — a healthy fulfillment pipeline.

6. **Credit Card dominates payments (75.5% of orders)**, followed by
   Boleto (Brazil's bank-slip payment method, ~20.0%) — a
   market-specific pattern worth noting if asked about the data's
   geographic origin.

7. **Average review score is 4.08/5**, with a bimodal distribution —
   58.0% give 5 stars while 11.7% give 1 star, with comparatively few
   lukewarm 2–3 star reviews. **Office Furniture** and **Home Confort**
   rate notably lower (~3.4–3.6) than the platform average.



The "90-day churn" query in `analysis_queries.sql` measures inactivity
relative to the *most recent order in this historical sample*, not
real-world "today." Because the genuine repeat-purchase rate is low
(~3%), roughly 80% of customers still appear "churned" by that
definition — but that's largely a byproduct of one-time-buyer
behavior, not customers actively lapsing after being retained.
