# clothing_analytics — dbt + Snowflake on a clothing store

ThreadLine is a made-up Pakistani clothing brand: 39 shops in 15 cities plus a website, selling kurtas,
lawn suits, abayas, khussas, jeans and hoodies in PKR. Same layers as `../tpch_analytics`, on data you can picture.

All data is generated inside Snowflake by `setup/02_generate_data.sql` (no files to load):
500k customers, 2k products, 36k SKUs, ~4.8M orders, ~11M order lines, ~600k returns, Jan 2023 to Oct 2026.
Sales grow over time and spike before every Eid and 11.11. November 2026 is held back in `CLOTHING_RAW.INCOMING`.

## Layers

```
CLOTHING_RAW.STORE  ->  staging (views)   ->  intermediate (view)       ->  marts (tables)
customers, products,    stg_store__*          int_order_items__priced      dim_customers, dim_products, dim_stores,
skus, stores, orders,                         (promo seed, net, profit)    fct_order_items (incremental),
order_items, returns                                                       fct_orders, fct_returns, rpt_monthly_sales
```

Also: a seed (`promo_codes`), an SCD-2 snapshot (`products_snapshot`), a macro (`discounted_amount`),
dev/prod schema naming, ~50 data tests, and two business tests (refunds never exceed what was paid; the report adds up).

## Run it

1. Run `../tpch_analytics/setup/01_snowflake_setup.sql` first if you have not (warehouse + TRANSFORMER role).
2. In Snowsight, **Run All** of `setup/01_admin_setup.sql` (ACCOUNTADMIN), then `setup/02_generate_data.sql`.
3. `~/.dbt/profiles.yml` needs the `clothing_analytics` profile from `../profiles.yml.example`.
4. `dbt deps && dbt build`

## Demos

- **Incremental:** run `setup/03_new_orders.sql` (November, with the 11.11 sale), then `dbt build -s fct_order_items+`.
- **Snapshot:** run `setup/04_price_changes.sql` (lawn suits +Rs 500), then `dbt snapshot`, then the query in that file.

## Questions to ask the data

- Which city sells the most lawn suits in the month before Eid?
- Is cash on delivery more common online than card? Do COD orders get returned more?
- What share of customers are Gold or Platinum, and how much of revenue do they bring?
- Which category has the best margin after returns?
