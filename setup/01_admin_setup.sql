-- Run once in Snowsight as ACCOUNTADMIN, with "Run All" (Ctrl+Shift+Enter).
-- Needs ../tpch_analytics/setup/01_snowflake_setup.sql to have run first (it creates TRANSFORM_WH and TRANSFORMER).
USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS CLOTHING_RAW;        -- what the shop's systems produced
CREATE DATABASE IF NOT EXISTS CLOTHING_ANALYTICS;  -- everything dbt builds

-- TRANSFORMER owns both, so it can load the generated data and dbt can build.
GRANT OWNERSHIP ON DATABASE CLOTHING_RAW       TO ROLE TRANSFORMER COPY CURRENT GRANTS;
GRANT OWNERSHIP ON DATABASE CLOTHING_ANALYTICS TO ROLE TRANSFORMER COPY CURRENT GRANTS;

-- So ACCOUNTADMIN/SYSADMIN can see everything TRANSFORMER builds.
GRANT ROLE TRANSFORMER TO ROLE SYSADMIN;
