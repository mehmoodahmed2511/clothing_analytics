-- ThreadLine: a made-up Pakistani clothing retailer (stores + website), 2023-01-01 to 2026-11-21.
-- Generates ~17M rows with Snowflake's GENERATOR. No files to load. Takes a few minutes on XSMALL.
-- Run with "Run All" (Ctrl+Shift+Enter) after 01_admin_setup.sql. Safe to re-run: it rebuilds everything.
--
--   STORE.STORES          40  (store 1 is the website)
--   STORE.CUSTOMERS      500k
--   STORE.PRODUCTS        2k
--   STORE.SKUS            36k (product x colour x size)
--   STORE.ORDERS         ~4.85M  orders up to 2026-10-31
--   STORE.ORDER_ITEMS    ~11M
--   STORE.RETURNS        ~600k
--   INCOMING.*           November 2026 orders, held back for the incremental demo (03_new_orders.sql)

USE ROLE TRANSFORMER;
USE WAREHOUSE TRANSFORM_WH;
CREATE SCHEMA IF NOT EXISTS CLOTHING_RAW.STORE;
CREATE SCHEMA IF NOT EXISTS CLOTHING_RAW.INCOMING;
USE SCHEMA CLOTHING_RAW.STORE;

-- Cities appear more than once so Karachi and Lahore get more customers, like real life.
CREATE OR REPLACE TABLE STORES AS
WITH l AS (
  SELECT ARRAY_CONSTRUCT('Karachi','Karachi','Karachi','Lahore','Lahore','Lahore','Islamabad','Islamabad',
                         'Rawalpindi','Faisalabad','Multan','Peshawar','Quetta','Hyderabad','Sialkot','Gujranwala') AS cities,
         ARRAY_CONSTRUCT('Main Boulevard','Saddar','Mall Road','DHA','Gulberg','Bahria Town','University Road','Cantt') AS areas
),
ids AS (SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) AS id FROM TABLE(GENERATOR(ROWCOUNT => 40)))
SELECT
  id                                                         AS STORE_ID,
  'ST-' || LPAD(id::STRING, 3, '0')                          AS STORE_CODE,
  IFF(id = 1, 'Online', GET(cities, MOD(id, 16))::STRING)    AS CITY,
  IFF(id = 1, 'threadline.pk', CITY || ' ' || GET(areas, MOD(id * 7, 8))::STRING) AS STORE_NAME,
  CASE WHEN id = 1 THEN 'ONLINE' WHEN MOD(id, 3) = 0 THEN 'MALL' ELSE 'HIGH_STREET' END AS STORE_TYPE,
  DATEADD(day, MOD(id * 137, 2900), '2015-01-01'::DATE)      AS OPENED_DATE
FROM ids, l;

CREATE OR REPLACE TABLE CUSTOMERS AS
WITH l AS (
  SELECT ARRAY_CONSTRUCT('Ahmed','Ali','Hamza','Bilal','Usman','Hassan','Fahad','Saad','Zain','Omar',
                         'Faisal','Imran','Asad','Danish','Talha','Haris','Shoaib','Waqas','Junaid','Abdullah') AS male,
         ARRAY_CONSTRUCT('Ayesha','Fatima','Zainab','Maryam','Hira','Sana','Mahnoor','Iqra','Amna','Sadia',
                         'Noor','Laiba','Areeba','Kinza','Mehwish','Rabia','Anum','Hafsa','Eman','Alishba') AS female,
         ARRAY_CONSTRUCT('Khan','Ahmed','Ali','Hussain','Shah','Malik','Butt','Qureshi','Siddiqui','Sheikh',
                         'Chaudhry','Raza','Iqbal','Mirza','Abbasi','Baig','Rana','Javed','Aslam','Memon') AS last,
         ARRAY_CONSTRUCT('Karachi','Karachi','Karachi','Lahore','Lahore','Lahore','Islamabad','Islamabad',
                         'Rawalpindi','Faisalabad','Multan','Peshawar','Quetta','Hyderabad','Sialkot','Gujranwala') AS cities
),
base AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) AS id,
         IFF(UNIFORM(1, 100, RANDOM()) <= 55, 'F', 'M') AS g,
         UNIFORM(0, 19, RANDOM()) AS fn, UNIFORM(0, 19, RANDOM()) AS ln, UNIFORM(0, 15, RANDOM()) AS ct
  FROM TABLE(GENERATOR(ROWCOUNT => 500000))
)
SELECT
  id                                                         AS CUSTOMER_ID,
  IFF(g = 'F', GET(female, fn), GET(male, fn))::STRING       AS FIRST_NAME,
  GET(last, ln)::STRING                                      AS LAST_NAME,
  LOWER(FIRST_NAME || '.' || LAST_NAME || id) || '@example.com' AS EMAIL,
  '03' || LPAD(UNIFORM(0, 499999999, RANDOM())::STRING, 9, '0') AS PHONE,
  GET(cities, ct)::STRING                                    AS CITY,
  g                                                          AS GENDER,
  DATEADD(day, -UNIFORM(16 * 365, 60 * 365, RANDOM()), '2026-11-01'::DATE) AS DATE_OF_BIRTH,
  DATEADD(day, UNIFORM(0, 1460, RANDOM()), '2019-01-01'::DATE)             AS SIGNUP_DATE,
  UNIFORM(1, 100, RANDOM()) <= 60                            AS MARKETING_OPT_IN
FROM base, l;

-- The four arrays line up by position: category i belongs to department i and costs lo[i]..hi[i] PKR.
CREATE OR REPLACE TABLE PRODUCTS AS
WITH l AS (
  SELECT ARRAY_CONSTRUCT('Kurta','Shalwar Kameez','Waistcoat','Jeans','T-Shirt','Polo Shirt','Hoodie','Jacket',
                         'Lawn Suit','Kurti','Dupatta','Abaya','Sneakers','Khussa','Kids Kurta') AS cat,
         ARRAY_CONSTRUCT('Men','Men','Men','Unisex','Unisex','Men','Unisex','Unisex',
                         'Women','Women','Women','Women','Footwear','Footwear','Kids') AS dept,
         ARRAY_CONSTRUCT(2500, 3500, 4000, 3000, 1200, 2000, 3500, 6000, 3000, 2000, 1000, 4500, 5000, 1800, 1200) AS lo,
         ARRAY_CONSTRUCT(7000,12000, 9000, 8000, 3500, 4500, 7500,18000, 9000, 5500, 4000,12000,15000, 4500, 3500) AS hi,
         ARRAY_CONSTRUCT('Cotton','Linen','Cotton Blend','Khaddar','Cambric','Polyester') AS fabric,
         ARRAY_CONSTRUCT('Classic','Slim Fit','Embroidered','Printed','Basic','Premium','Festive','Casual','Oversized','Everyday') AS adj,
         ARRAY_CONSTRUCT('ThreadLine','Urban Desi','Kapra Co','Rang Studio','North Peak') AS brand
),
base AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) AS id,
         UNIFORM(0, 14, RANDOM()) AS c, UNIFORM(0, 5, RANDOM()) AS f, UNIFORM(0, 9, RANDOM()) AS a,
         UNIFORM(0, 4, RANDOM()) AS b, UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) AS p
  FROM TABLE(GENERATOR(ROWCOUNT => 2000))
)
SELECT
  id                                                         AS PRODUCT_ID,
  'TL-' || LPAD(id::STRING, 5, '0')                          AS PRODUCT_CODE,
  GET(adj, a)::STRING || ' ' || GET(cat, c)::STRING          AS PRODUCT_NAME,
  GET(cat, c)::STRING                                        AS CATEGORY,
  GET(dept, c)::STRING                                       AS DEPARTMENT,
  IFF(GET(dept, c)::STRING = 'Footwear', 'Leather', GET(fabric, f)::STRING) AS FABRIC,
  GET(brand, b)::STRING                                      AS BRAND,
  (ROUND(GET(lo, c)::NUMBER + p * (GET(hi, c)::NUMBER - GET(lo, c)::NUMBER), -2) - 1)::NUMBER(10, 0) AS PRICE,  -- 3499 style
  ROUND(PRICE * UNIFORM(35, 55, RANDOM()) / 100, 0)::NUMBER(10, 0) AS COST,
  DATEADD(day, UNIFORM(0, 1095, RANDOM()), '2020-01-01'::DATE) AS LAUNCH_DATE,
  IFF(UNIFORM(1, 100, RANDOM()) <= 8, 'DISCONTINUED', 'ACTIVE') AS STATUS
FROM base, l;

-- Every product comes in 3 colours x 6 sizes = 18 SKUs.
CREATE OR REPLACE TABLE SKUS AS
WITH sizes AS (
  SELECT column1 AS slot, column2 AS apparel, column3 AS shoe
  FROM VALUES (1,'XS','39'),(2,'S','40'),(3,'M','41'),(4,'L','42'),(5,'XL','43'),(6,'XXL','44')
),
colours AS (SELECT column1 AS c FROM VALUES (0),(1),(2)),
l AS (SELECT ARRAY_CONSTRUCT('Black','White','Navy','Maroon','Olive','Beige','Grey','Mustard',
                             'Sky Blue','Bottle Green','Pink','Off White') AS col)
SELECT
  ROW_NUMBER() OVER (ORDER BY p.PRODUCT_ID, c.c, s.slot)     AS SKU_ID,
  p.PRODUCT_ID,
  GET(l.col, MOD(p.PRODUCT_ID + c.c * 4, 12))::STRING        AS COLOUR,
  IFF(p.DEPARTMENT = 'Footwear', s.shoe, s.apparel)          AS SIZE,
  p.PRODUCT_CODE || '-' || UPPER(LEFT(COLOUR, 3)) || '-' || SIZE AS SKU_CODE
FROM PRODUCTS p CROSS JOIN colours c CROSS JOIN sizes s CROSS JOIN l;

-- Orders: the business grows (sqrt skews dates toward recent), and 12% of orders pile up
-- in the 10 days before each Eid and 11.11 sale.
CREATE OR REPLACE TABLE ORDERS AS
WITH l AS (
  SELECT ARRAY_CONSTRUCT('2023-04-21','2023-06-28','2023-11-11','2024-04-10','2024-06-16','2024-11-11',
                         '2025-03-31','2025-06-06','2025-11-11','2026-03-20','2026-05-27','2026-11-11') AS peaks,
         ARRAY_CONSTRUCT('WELCOME10','EID25','SUMMER15','WINTER20','SALE1111','FLASH40') AS promos
),
g AS (
  SELECT
    IFF(UNIFORM(1, 100, RANDOM()) <= 12,
        DATEADD(day, -UNIFORM(0, 9, RANDOM()), GET(peaks, UNIFORM(0, 11, RANDOM()))::DATE),
        DATEADD(day, FLOOR(1421 * SQRT(UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()))), '2023-01-01'::DATE)) AS order_day,
    UNIFORM(32400, 82799, RANDOM())                                AS secs,      -- 9am to 11pm
    IFF(UNIFORM(1, 100, RANDOM()) <= 40, 1, UNIFORM(2, 40, RANDOM())) AS store_id,  -- 40% online
    UNIFORM(1, 100, RANDOM()) AS r_pay,
    UNIFORM(1, 100, RANDOM()) AS r_promo,
    UNIFORM(1, 100, RANDOM()) AS r_status,
    UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) AS r_items,
    promos
  FROM TABLE(GENERATOR(ROWCOUNT => 5000000)) CROSS JOIN l
)
SELECT
  1000000 + ROW_NUMBER() OVER (ORDER BY order_day, secs)     AS ORDER_ID,
  UNIFORM(1, 500000, RANDOM())                               AS CUSTOMER_ID,
  store_id                                                   AS STORE_ID,
  DATEADD(second, secs, order_day::TIMESTAMP_NTZ)            AS ORDERED_AT,
  CASE WHEN store_id = 1 THEN
         CASE WHEN r_pay <= 50 THEN 'CASH_ON_DELIVERY' WHEN r_pay <= 75 THEN 'CARD'
              WHEN r_pay <= 90 THEN 'JAZZCASH' ELSE 'EASYPAISA' END
       ELSE CASE WHEN r_pay <= 55 THEN 'CASH' WHEN r_pay <= 90 THEN 'CARD' ELSE 'JAZZCASH' END
  END                                                        AS PAYMENT_METHOD,
  IFF(r_promo <= 82, NULL, GET(promos, MOD(r_promo, 6))::STRING) AS PROMO_CODE,
  CASE WHEN r_status <= 3 THEN 'CANCELLED'
       WHEN store_id = 1 AND order_day >= '2026-11-18' THEN 'SHIPPED'
       ELSE 'COMPLETED' END                                  AS ORDER_STATUS,
  IFF(store_id = 1, 250, 0)                                  AS SHIPPING_FEE,
  1 + FLOOR(5 * r_items * r_items)                           AS ITEM_COUNT   -- 1 to 5, mostly 1; dropped below
FROM g;

-- Low SKU ids sell more (power 2), so there are clear best-sellers. 36000 = number of SKUs.
CREATE OR REPLACE TABLE ORDER_ITEMS AS
WITH n AS (SELECT column1 AS line_number FROM VALUES (1),(2),(3),(4),(5)),
picked AS (
  SELECT o.ORDER_ID, n.line_number,
         1 + FLOOR(35999 * POWER(UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()), 2)) AS sku_id,
         IFF(UNIFORM(1, 10, RANDOM()) = 1, 2, 1) AS quantity
  FROM ORDERS o JOIN n ON n.line_number <= o.ITEM_COUNT
)
SELECT
  p.ORDER_ID * 10 + p.line_number AS ORDER_ITEM_ID,
  p.ORDER_ID,
  p.line_number                   AS LINE_NUMBER,
  p.sku_id                        AS SKU_ID,
  p.quantity                      AS QUANTITY,
  pr.PRICE                        AS UNIT_PRICE
FROM picked p
JOIN SKUS s      ON s.SKU_ID = p.sku_id
JOIN PRODUCTS pr ON pr.PRODUCT_ID = s.PRODUCT_ID;

ALTER TABLE ORDERS DROP COLUMN ITEM_COUNT;

-- About 6% of completed items come back within 30 days.
CREATE OR REPLACE TABLE RETURNS AS
WITH l AS (SELECT ARRAY_CONSTRUCT('Wrong size','Defective or damaged','Changed my mind',
                                  'Colour not as pictured','Arrived late','Received wrong item') AS reasons),
r AS (
  SELECT oi.ORDER_ITEM_ID, oi.QUANTITY,
         DATEADD(day, UNIFORM(2, 30, RANDOM()), o.ORDERED_AT)::DATE AS returned_at,
         GET(l.reasons, UNIFORM(0, 5, RANDOM()))::STRING AS reason
  FROM ORDER_ITEMS oi JOIN ORDERS o ON o.ORDER_ID = oi.ORDER_ID CROSS JOIN l
  WHERE o.ORDER_STATUS = 'COMPLETED' AND UNIFORM(1, 100, RANDOM()) <= 6
)
SELECT ROW_NUMBER() OVER (ORDER BY returned_at, ORDER_ITEM_ID) AS RETURN_ID,
       ORDER_ITEM_ID, returned_at AS RETURNED_AT, reason AS REASON, QUANTITY AS RETURNED_QUANTITY
FROM r
WHERE returned_at < '2026-11-01';

-- Hold back November 2026: it "arrives" later in 03_new_orders.sql.
CREATE OR REPLACE TABLE CLOTHING_RAW.INCOMING.ORDERS AS
  SELECT * FROM ORDERS WHERE ORDERED_AT >= '2026-11-01';
CREATE OR REPLACE TABLE CLOTHING_RAW.INCOMING.ORDER_ITEMS AS
  SELECT oi.* FROM ORDER_ITEMS oi JOIN CLOTHING_RAW.INCOMING.ORDERS o ON o.ORDER_ID = oi.ORDER_ID;
DELETE FROM ORDER_ITEMS WHERE ORDER_ID IN (SELECT ORDER_ID FROM CLOTHING_RAW.INCOMING.ORDERS);
DELETE FROM ORDERS WHERE ORDERED_AT >= '2026-11-01';

-- Sanity check
SELECT 'stores' AS t, COUNT(*) AS n FROM STORES
UNION ALL SELECT 'customers', COUNT(*) FROM CUSTOMERS
UNION ALL SELECT 'products', COUNT(*) FROM PRODUCTS
UNION ALL SELECT 'skus', COUNT(*) FROM SKUS
UNION ALL SELECT 'orders', COUNT(*) FROM ORDERS
UNION ALL SELECT 'order_items', COUNT(*) FROM ORDER_ITEMS
UNION ALL SELECT 'returns', COUNT(*) FROM RETURNS
UNION ALL SELECT 'incoming orders', COUNT(*) FROM CLOTHING_RAW.INCOMING.ORDERS
UNION ALL SELECT 'incoming items', COUNT(*) FROM CLOTHING_RAW.INCOMING.ORDER_ITEMS;
