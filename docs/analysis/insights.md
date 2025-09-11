# Olist (SQL) — Data Quality, Delivery & BI-Ready Views

## Data Quality — Can the data be trusted?
**Scope.** All figures come from published “quality-safe” views in SQL Server (e.g., `quality.valid_orders`, `quality.order_items_valid`) that exclude inconsistent records.

**What was checked**
- Split orders into **valid vs. invalid**.
- **Time-logic checks** (no event recorded before its prerequisite).
- Exposed **quality-safe views** so dashboards only read clean data.

**Technical validation (short)**
- Raw vs. clean counts match; **no orphans** (no items/payments/reviews without a parent order).
- Keys healthy: no duplicates on **PKs** (primary keys)/**composite keys** (multi-column keys) and no NULLs in key columns.
- **Domains** within range (allowed order statuses; review scores 1–5; non-negative payments).
- **FKs** (foreign keys) are enabled and **trusted**.
- **Economic consistency** (items vs. payments): differences tracked (shipping/discounts/rounding), monitored but not treated as a data-quality error.

**Key results**
- **Total orders:** 99,441  
- **Invalid orders:** 1,382 (≈ **1.39%**)  
- **Valid & delivered orders:** 95,105  
- **On-time deliveries:** 88,595 (**late rate** = 6.85% of delivered orders)  
- **Main time issue:** 1,359 cases where shipping was recorded **before** approval (plus 23 minor cases).

**Plain explanation**  
The data is broadly reliable. Only ~1.4% showed timestamp inconsistencies (mostly event mis-ordering). Dashboards now read from **quality-safe** views, so numbers are consistent.

---

## Delivery, Payments, and Customers — Operational view
**What was analyzed**
- **Delivery lead time** (average, **p50** = median, **p75** = 75th percentile, **p90** = 90th percentile) and **late rate by month**.  
- **Payment mix** (share by **amount**, not by count).  
- **Repeat customers** (unique customer ID; % of buyers with **2+ orders**).

**Key results**
- **Lead time:** average **12.56** days; **p50 (median)** = 10 days; **p90** = 23 days.  
- **Late rate spike:** **Feb–Mar 2018** reached **14–19%**; later stabilized near **~7%**.  
- **Payment mix (by amount):** **Card 78%**, **Boleto 18%** (bank slip); others small.  
- **Repeat:** ~**3%** of customers buy more than once; **avg orders/customer ≈ 1.03**.

**Plain explanation**  
Most orders arrive on time. A small but painful **tail** (very late orders beyond p90) hurts experience. People mostly pay by **card**; **boleto** confirms later and can delay dispatch. **Repeat** is low (~3%), so retention programs could lift revenue.

---

## BI Layer — Ready for dashboards
**What is provided**  
Pre-aggregated, clean views ready for **BI** (Business Intelligence) tools—no extra transforms needed. Examples:
- `bi.v_daily_sales`
- `bi.v_payment_mix`
- `bi.v_delivery_lead_time` and `bi.v_late_orders`
- `bi.v_repeat_customers`
- `bi.v_state_lead_time`
- `bi.v_category_sales_monthly`
- `bi.v_kpi_summary` (**KPI** = Key Performance Indicator)

**Plain explanation**  
The heavy lifting is already done. Dashboards can plug into these views and get **ready-to-use, trustworthy numbers** out of the box.

---

## What these numbers mean (business interpretation — plain-English)

- **Trust & process maturity.** Only ~1.4% of orders are filtered by time-logic rules. That points to **event sequencing** issues (systems posting “carrier” before “approval”), not missing transactions. **Quality-safe views** isolate this noise so **BI** works with clean inputs.

- **Delivery story = median vs. tail.** Typical experience is strong: **p50 (median)** ≈ 10 days. The pain sits in the **tail**: **p90 (90th percentile)** ≈ 23 days and a few extreme outliers. The tail drives complaints, support load, and **NPS** (Net Promoter Score) drag. Managing the tail matters more than shaving the average.

- **Temporal spike (Feb–Mar 2018).** The late-rate peak aligns with seasonality and capacity constraints. A higher share of **non-instant payments** (e.g., **boleto**) likely delayed confirmation/dispatch compared to instant methods.

- **Payments as friction.** **Card** accounts for ~78% of amount; **boleto** ~18% and slows confirmation. Shifting part of boleto to **instant methods** (card or **PIX**, Brazil’s instant payment system) during peak weeks reduces late-delivery risk **without changing logistics**.

- **Low repeat (~3%).** The marketplace behaves “one-and-done”: acquisition must pay back on the first order. Improving early retention lifts **GMV** (Gross Merchandise Value) and **CAC** (Customer Acquisition Cost) efficiency.

**Hypotheses to test next**  
H1) **Regional SLA** (Service Level Agreement = delivery promise shown to the customer) with proactive alerts lowers support tickets and perceived lateness.  
H2) **Payment nudges** to instant methods in peak periods reduce the late rate by ~1–2 **percentage points (pp)**.  
H3) **Post-delivery journeys** (nudges at D+7/14/30 days) can lift repeat from ~3% → ~6%.

---

## Business recommendations (90 days)

1) **Regional SLA & expectation setting**  
   - Show realistic **ETA** (Estimated Time of Arrival) by state (RR/AP/AM with wider windows) and trigger proactive alerts when risk of delay > X%.  
   - *Owner:* **CX** (Customer Experience)/Product · *KPIs:* late_rate, **NPS**, support tickets.

2) **Shift to instant payments in peak weeks**  
   - Promote card/instant methods (e.g., **PIX**/**BNPL**—Buy Now, Pay Later—depending on market) with small incentives; remind **boleto** before expiry.  
   - *Owner:* Payments/Product · *KPIs:* share of instant payments, approval time, late_rate.

3) **Post-delivery retention journeys**  
   - D+7/14/30 nudges with category-based cross-sell and “2nd-purchase” coupon tests to lift **repeat** from ~3% → ~6%.  
   - *Owner:* Growth/**CRM** (Customer Relationship Management) · *KPIs:* repeat_rate, **ARPU** (Average Revenue per User/Customer), journey conversion.

4) **Outlier “war-room”**  
   - Weekly review of top **p95+** late orders (95th percentile and above); tag root cause (carrier, seller, address, payment) and close loops with partners.  
   - *Owner:* Ops · *KPIs:* **p90/p95** lead time, late tickets closed.

5) **Ongoing data quality guardrail**  
   - Monitor `invalid_ratio` and alert if >2% weekly; BI uses only `quality.*` views as source of truth.  
   - *Owner:* Data/BI · *KPIs:* invalid_ratio, # of violated orders by code (T2/T3).

---

### Quick glossary (first-time readers)
- **PK/FK** = Primary/Foreign Key  
- **Composite key** = multi-column key  
- **Orphan** = child row without its parent (e.g., item without order)  
- **Domain** = allowed value set/range  
- **BI** = Business Intelligence  
- **KPI** = Key Performance Indicator  
- **p50/p75/p90/p95** = percentiles (median/75th/90th/95th)  
- **Late rate** = % of delivered orders that arrived after the promised date  
- **NPS** = Net Promoter Score  
- **ETA** = Estimated Time of Arrival  
- **SLA** = Service Level Agreement (delivery promise)  
- **PIX** = Brazil’s instant payment system  
- **BNPL** = Buy Now, Pay Later  
- **GMV** = Gross Merchandise Value  
- **CAC** = Customer Acquisition Cost  
- **ARPU** = Average Revenue per User (customer)  
- **CRM** = Customer Relationship Management  
- **pp** = percentage points

> **Run metadata:** SQL Server 16 · Olist (public) · Run date: 2025-09-10  
> Sources: `clean.*` → `quality.*` → `bi.*`





